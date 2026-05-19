# Security Considerations

This document captures the security thinking behind the pipeline, the risks in the current design, near-term mitigations, and longer-term architectural directions including a potential redesign of the ship stage.

---

## The problem in plain terms

The pipeline is Claude Code running autonomously with the same permissions as the user who invoked it. That means it can read any file on the filesystem, run any make target, access any environment variable present in the shell, and push to any git remote the user's credentials can reach. For most development tasks in a contained local checkout, this is fine. The risk surface grows significantly when:

- Production credentials are present in the shell environment (a common pattern in day-to-day development)
- The target repo's make targets do something non-obvious (a `make seed` that runs a migration, for example)
- The `gh` CLI is authenticated with broad GitHub permissions
- A malicious or confused string in a file being read causes the agent to take an unintended action (prompt injection)

None of these are hypothetical. The Railway and Replit incidents (public, 2025-2026) involved agents with broad permissions doing exactly what they were allowed to do in ways the user did not intend.

---

## What each stage actually needs

The blast radius is not uniform across stages. Mapping what each stage genuinely requires is the foundation for any sensible security model.

| Stage | File writes | Make targets | git push | gh CLI | External credentials |
|-------|-------------|--------------|----------|--------|----------------------|
| Implement | Yes (source files) | Lint only | No | No | No |
| Test | Yes (test files) | Lint + targeted test run | No | No | No (test env mocked) |
| Review | No (WorkItem append only) | No | No | No | No |
| Ship | No | No | Yes | Yes (PR creation) | Yes (GitHub token) |

The stages that write code and run commands (implement, test) are the ones most likely to do something unexpected. They also happen to be the stages that need the least access: no git push, no GitHub credentials, no external services. The stage that needs real credentials (ship) only pushes already-reviewed, gate-verified output.

This asymmetry is the key insight for any containerization approach.

---

## Current risk surface

### High concern

**Shell environment exposure.** If `DATABASE_URL`, `STRIPE_SECRET_KEY`, or similar credentials are exported in the user's shell, they are visible to every make target the pipeline runs. A make target that starts a server, runs a migration, or calls an external API will carry those credentials.

**Broad GitHub credentials.** The `gh` CLI authenticated with `gh auth login` typically carries full repository access (or organisational access in some configurations). If the ship stage or any stage invokes gh commands against repos outside the intended target, there is no access control to stop it.

**Arbitrary make target execution.** The pipeline runs whatever `make lint` and `make test` expand to. In a repo like ros-service, this spins up a full docker-compose stack with 59 services. In a less well-maintained repo, `make test` might do something destructive.

### Lower concern (but worth noting)

**Prompt injection via source files.** An agent reading a source file containing carefully crafted strings could theoretically be directed to take actions outside its intended scope. The WorkItem schema and stage isolation provide some defence here: the implement agent is not supposed to run git commands, and the orchestrator's post-stage verification would catch obvious scope violations. But this is not a hard security boundary.

**WorkItem and handover files.** These are written to `.workitems/` and `.handovers/` inside the repo and are excluded from commits. If accidentally staged and pushed, they would expose internal pipeline metadata (file paths, key decisions, timing) to anyone with repo access. The global gitignore mitigates this but relies on user configuration.

---

## Near-term mitigations (no infrastructure changes required)

These two changes address the most significant risks immediately.

### 1. Fine-grained GitHub PAT

Replace `gh auth login` (broad credentials) with a fine-grained Personal Access Token scoped to specific repositories, with only `contents: write` and `pull_requests: write` permissions. Inject it as `GH_TOKEN` in the environment where the pipeline runs.

Effect: if the pipeline tries to interact with any repo outside the intended target, it gets a 403. The "wrong repo" scenario becomes impossible.

Setup is five minutes via GitHub Settings > Developer settings > Fine-grained personal access tokens.

### 2. Clean shell environment

Run the pipeline from a shell session that does not have production credentials exported. A wrapper script that launches Claude Code after unsetting or filtering sensitive variable names (`DATABASE_URL`, `*_SECRET_KEY`, `*_API_KEY`, `AWS_*`, etc.) eliminates the "agent reads a prod credential from the environment" scenario entirely.

This does not require containerisation. It is a shell script.

---

## Docker containerisation: the full analysis

Docker is the right longer-term answer for implement and test stage isolation. The analysis is more complex than it first appears, and ros-service is a useful baseline for understanding the worst case.

### What Docker buys

Running Claude Code inside a Docker container with a mounted project directory and nothing else gives:
- No access to env vars outside what is explicitly passed
- No git credentials (no push possible from inside the container)
- No gh CLI (no GitHub API access)
- Filesystem access limited to the mounted project directory
- Network access controllable (can block everything except what tests need)

For the implement and test stages, this is close to ideal. They do not need git push or GitHub access. The only legitimate credentials they need are whatever the test suite requires (for ros-service, `GEMFURY_DEPLOY_TOKEN` for package installation).

### The Docker-in-Docker problem

ros-service's test suite runs inside Docker. `make test` spins up a docker-compose stack. If the pipeline is already inside a Docker container, running docker-compose requires one of two approaches:

**Docker socket mounting:** mount `/var/run/docker.sock` from the host into the pipeline container. The container then talks to the host Docker daemon and spins up sibling containers. This works and is what most CI systems do. The security caveat: mounting the Docker socket is functionally equivalent to giving the container root access to the host, because a process that can talk to the Docker daemon can create privileged containers and escape any isolation. It solves the DinD operational problem but eliminates most of the security benefit.

**True Docker-in-Docker (DinD):** run a full Docker daemon inside the pipeline container in privileged mode. More isolated than socket mounting but requires `--privileged`, is significantly slower (image pulls happen inside the nested daemon), and is operationally complex.

For services where tests run natively (not via docker-compose), containerisation is clean and the DinD problem does not arise. For services like ros-service that already use Docker for testing, the tradeoff is real and there is no ideal answer.

### Recommended Docker approach

Given the above, the most practical Docker approach is per-stage rather than all-or-nothing:

- **Implement stage:** run in a container with the project directory mounted, language tooling installed, and no credentials except what lint needs. No Docker socket needed (implement runs lint only, not tests).
- **Test stage:** for services with native test suites, run in a container. For services with Docker-based test suites, use Docker socket mounting with the tradeoff accepted and documented.
- **Review stage:** has no make targets or credential needs; containerisation is trivial but adds overhead for minimal benefit.
- **Ship stage:** see the redesign discussion below. This is where the real decision lies.

### Non-Docker alternatives

**macOS sandbox-exec (SBPL profiles).** Native macOS sandboxing. Can restrict filesystem writes, network access, and process spawning via a profile. Zero overhead, no VM required. The downside: SBPL is largely undocumented, has not been officially maintained for years, and breaks unpredictably across macOS versions. Not worth investing in for production use.

**FreeBSD jails.** The conceptual ancestor of Linux containers: OS-level process isolation with restricted filesystem root and network namespace, no separate kernel required. Excellent security model, very lightweight. Requires FreeBSD. The same concept is available on Linux as `systemd-nspawn`, which is significantly lighter than Docker and does not require the Docker daemon. Not available natively on macOS without a VM layer.

**Linux namespaces directly (unshare, nsjail, firejail).** The primitives Docker is built on. More fine-grained control, less toolchain overhead. Linux-only; not relevant on macOS without a VM.

**OrbStack.** Not a different security model, but a lighter macOS runtime for Linux containers. Noticeably faster than Docker Desktop on Apple Silicon. Worth considering if Docker Desktop performance has been a friction point, regardless of the security question.

**Full VM isolation.** A dedicated VM (UTM, Lima, Parallels) for pipeline runs gives the strongest isolation boundary at the cost of startup overhead. Overkill for this use case, but worth knowing exists.

**Honest summary.** On macOS in 2026, Docker (or OrbStack as a compatible runtime) is the most practical option by a significant margin. The native macOS sandboxing options are either too fragile or not available. The Linux-native options require a VM layer anyway on macOS. Docker's advantage is a usable toolchain and broad ecosystem support, not any fundamental security superiority.

---

## Future redesign: user holds the keys to ship

A more fundamental question is whether the ship stage should ever run autonomously at all.

The current design chains all four stages and hands off a PR URL at the end. This is the right model for speed and convenience, but it means the pipeline can push code and create public GitHub artifacts without any user confirmation after `/pipeline-run` is invoked. In a containerised world, ship is the stage that breaks isolation: it is the only stage that must reach outside the container to interact with shared infrastructure.

### The "user holds keys" model

One redesign direction: everything through review runs inside a container. The container produces a handover package: a git bundle containing the commits, a draft PR description, the full WorkItem, and a summary of what the review agent found. The user inspects the package, then explicitly triggers the push.

This creates a clear security boundary. The container has no GitHub credentials at all. It cannot push. The human decides when (and whether) the work leaves the local environment and becomes visible to the rest of the team.

The tradeoff is obvious: it breaks the fully autonomous promise. For teams who trust the pipeline and want zero manual intervention, this is a regression. For teams where any push to the shared repository is a meaningful act (regulatory environments, large shared repos, cautious teams), it is the right default.

A middle ground is worth considering: keep ship autonomous by default, but add an explicit confirmation step that is distinct from the existing gate mechanism. Something like:

> "Ship is ready. This will push branch `username/sc-660363/-add-smoke-test` and create a PR against `main`.
>
> Commits to be pushed:
> - feat: add smoke test script
> - test: add smoke test script
>
> Review agent outcome: approved. No flags.
>
> Proceed? [Y/n]:"

This is a single confirmation prompt before any GitHub interaction. It adds one user touch to the otherwise autonomous flow and gives the user a concrete artifact to review before the work becomes public. It does not require containerisation. It can be implemented in the ship stage or as a pre-ship gate in the orchestrator.

### Per-stage permission model

Whether or not ship becomes interactive, the implement and test stages could be containerised independently without blocking the rest of the pipeline:

1. Orchestrator establishes baseline (host, with credentials, before any agent work)
2. Implement agent runs in container (no credentials, mounted project dir, lint only)
3. Orchestrator runs full test suite (host, with credentials) as post-implement verification gate
4. Test agent runs in container (no credentials, or scoped test credentials only)
5. Orchestrator runs targeted test suite (host) as post-test verification gate
6. Review agent runs with project read access only (could be containerised trivially)
7. Ship agent runs with explicit GitHub token injection (host or container with scoped PAT)

The orchestrator itself stays on the host throughout, which is where the credential decisions live. This is a natural fit with the current architecture where the orchestrator owns verification and commit operations.

---

## Summary and recommended path

| Action | Effort | Risk reduction | When |
|--------|--------|---------------|------|
| Fine-grained GitHub PAT | Low | High (GitHub scope) | Now |
| Clean shell wrapper | Low | High (env credential exposure) | Now |
| Pre-ship confirmation prompt | Medium | Medium (user visibility before push) | Next |
| Container for implement stage | High | Medium (code execution isolation) | Later |
| Container for test stage (native tests) | High | Medium | Later |
| Full per-stage container model | Very high | High overall | Future |

The immediate steps are not glamorous but address the scenarios most likely to cause real problems. The pre-ship confirmation prompt is a low-infrastructure way to give the user visibility before the irreversible part of the pipeline runs. Containerisation is the right long-term answer but should wait until the pipeline itself is stable and the DinD tradeoff is understood for the specific services it will run against.
