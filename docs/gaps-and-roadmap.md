# Gaps and Roadmap

## Known gaps (not yet fixed)

### Pipeline directories have strict scope — no foreign files (fixed 2026-05-15)

`.workitems/` contains **only** `workitem-sc-XXXXXX.md` files. `.handovers/` contains **only** `handover-sc-XXXXXX.md` files. No PR descriptions, notes, or other pipeline artifacts go in either directory. Fixed by adding explicit scope notes to `pipeline-plan.md` and `pipeline-run.md`. PR descriptions go to `~/.claude/pr-descriptions/<service-name>/<service-name>-<ticket-id>.md` — fixed in `pr-description.md` which previously wrote to `<repo-root>/.handovers/` by mistake.

---

### Orchestrator must never stage WorkItem or handover files in git commits

The orchestrator's stage commits (`git add lib/... .workitems/workitem-*.md`) have explicitly staged the WorkItem file, bypassing the global gitignore. Global gitignore entries only suppress *untracked* files from `git add -A` — an explicit `git add <path>` always stages, regardless of gitignore. The WorkItem and handover docs are pipeline-internal artifacts that must never leave the developer's local machine.

**Rule:** When staging implement and test commits, the orchestrator must only `git add` files listed in `### Files changed` from the relevant stage section of the WorkItem. Never pass `.workitems/` or `.handovers/` paths to `git add` under any circumstances. If a WorkItem was accidentally committed, `git rm --cached` it immediately and force-push to clean the branch before creating the PR.

## Fixed

### Commit message format (fixed 2026-05-14)
The implement stage previously said "commit the changes" without specifying format. Fixed: the orchestrator now owns all commits (not the stage agents), and commit messages use conventional commits format — type derived from the WorkItem `**Type:**` field (feature → feat, bug → fix, migration → chore), no scope brackets, description from the WorkItem title. Retry commits use `fix: address <stage> issues — <summary>`. PR titles follow the same convention. AGENTS.md still controls repo-specific conventions layered on top.

### Triage logic + handover document (fixed 2026-05-13)
Each stage now classifies failures as self-resolve or raise. Self-resolve attempts a fix (max 2 retries) before escalating. Every issue — resolved or raised — is logged in a `### Issues` subsection in the WorkItem. At the end of ship, the orchestrator synthesises the full WorkItem into a handover document (`handover-sc-XXXXXX.md`) covering: what was built, all issues and how they were handled, review focus areas, and next steps.

### Either gates — pre-existing failures + spec drift (fixed 2026-05-13)
Each stage now writes a `Gate: PASS/FAIL` field as its final action. The orchestrator short-circuits on any FAIL rather than proceeding. This resolved both original gaps in one principled mechanism modelled on Haskell's `Either` monad / Kleisli composition (`>=>`). Stages produce `Either FailReason Output`; the orchestrator interprets `Left reason` as a three-way user decision: Retry, Override, or Halt.

### No path back from implement to plan (fixed 2026-05-14)
If the implementer discovered the spec was wrong or infeasible mid-implementation, there was no escalation path — the agent would improvise and the deviation only surfaced at review. Fixed in `pipeline-implement.md`: a pre-implementation spec feasibility check now runs before any code is written. If the spec cannot be satisfied, the agent stops immediately, writes a `[implementer] Spec blocker` to Flags, and writes `Gate: FAIL` — no code is ever written against a bad spec.

### Review integrated as pipeline stage (fixed 2026-05-14)
`/pipeline-review` was previously optional and separate. It is now stage 3 of the automated pipeline: `implement → test → review → ship`. The review agent writes a gate result (`approved` → PASS, `changes requested` or `blocked` → FAIL) so the orchestrator can gate on it. The PR is only created after a passing review.

### Orchestrator stage commits + conventional commits (fixed 2026-05-14)
The orchestrator now commits after each verified stage (implement and test). Commit messages use conventional commits format — type derived from the WorkItem type (feature → feat, bug → fix, migration → chore), no scope brackets, description from the WorkItem title. Retry detection via git log: if a pipeline commit already exists for this SC on the branch, the next commit is `fix: address <stage> issues — <summary>`. PR titles follow the same convention. Gives a clean breadcrumb trail of verified states with rollback points at each stage boundary.

### Post-stage orchestrator verification (fixed 2026-05-14)
The orchestrator now independently verifies each stage's critical claims before accepting a gate PASS. After implement: checks `### Issues` for unresolved lint failures (trusts agent's result, does not re-run lint); runs `make test.unit` as correctness gate; checks no test files were created by the implement agent. After test: reads `### Run with` and runs that exact targeted command. After review: checks outcome and gate are consistent. After ship: verifies the PR URL with `gh pr view`. All stages: checks required WorkItem fields are present. A failed verification overrides the agent's gate to FAIL and surfaces to the user.

### Pre-existing test baseline (fixed 2026-05-14, revised 2026-05-15)
The orchestrator runs `make test.unit` once before spawning the implement agent and writes the result to `### Baseline` in the WorkItem. If the suite cannot run at all, the pipeline stops before the implement agent is spawned. If some tests are already failing, their IDs are saved — the orchestrator's post-implement suite run excludes those IDs from its gate decision. The implement agent itself does not run any tests; it only runs lint.

### PR base branch (fixed 2026-05-14)
`pipeline-ship.md` was always targeting the repo default branch. Fixed by capturing the base branch explicitly during planning — the planner asks, the user confirms or specifies, and it's written to the WorkItem header. Ship reads `**Base branch:**` from the WorkItem and passes it as `--base <branch>` to `gh pr create`. Right 90% of the time with no friction; the 10% case is explicitly handled rather than guessed.

### Context injection (fixed 2026-05-13, extended 2026-05-14)
Subagents spawned by the orchestrator start blank — no CLAUDE.md, no memory files. Fixed in `pipeline-run.md` in two passes: (1) the orchestrator reads all `feedback_*.md` files from both repo-specific and org-level memory directories and injects them as hard constraints into every subagent prompt; (2) extended to also read and inject `CLAUDE.md`/`AGENTS.md` from the repo root, and the `### Repo style` section from the WorkItem. The orchestrator now reports what was loaded after Step 1 — missing or empty sources are surfaced, not silently skipped.

### Test agent ownership boundary (fixed 2026-05-15)
The test agent had no prohibition against modifying source files, and the orchestrator had no post-test check for it — the symmetric gap to the implement/test boundary that was already enforced. Fixed: `pipeline-test.md` now explicitly prohibits creating or modifying files outside test directories, adds the ownership check to triage, and adds "test cannot pass without modifying a source file → raise it as an implementation bug" to the Raise immediately section. The orchestrator now cross-checks Tests `### Files changed` against Implementation `### Files changed` post-test — any overlap means the test agent touched source code and the gate is overridden to FAIL.

### Makefile targets no longer hardcoded (fixed 2026-05-15)
`make test.unit` and `make lint` were hardcoded in `pipeline-implement.md` and `pipeline-run.md`. Different repos (Ruby services, etc.) use different targets. Fixed: the planner now reads the Makefile during Pass 2 of the style survey and documents the exact lint, full suite, and targeted test commands in a `Make targets` subsection of `### Repo style`. All downstream stages and the orchestrator post-implement verification read from there rather than assuming defaults.

### Trial run fixes (fixed 2026-05-14, post SC-668234)
Full findings in `findings/trial-run-sc-668234-findings.md`. Items resolved:

- **#1 — Implement agent must not write tests.** Added explicit prohibition to `pipeline-implement.md`: no files under `tests/` may be created or modified. Creating test files causes Gate: FAIL. Orchestrator also verifies this post-implement.
- **#2 — Full test suite run too many times.** Full suite runs exactly twice: once by the orchestrator before spawning the implement agent (baseline), and once by the orchestrator after implement (correctness gate). The implement agent runs lint only — no tests. All subsequent stages use targeted runs only (`make unit test=<paths>`), recorded in `### Run with`.
- **#3 — Lint run twice.** Implement agent now owns lint: runs it, records result in `### Issues`. Orchestrator reads Issues for unresolved failures rather than re-running `make lint`.
- **#4 — Base branch assumption.** Planner now assumes `main` by default and presents a menu (1. main / 2. other) rather than asking an open question.
- **#5/#15 — Orchestrator verbosity / buried PR URL.** Orchestrator reads WorkItem silently, reports a single summary line. Final output is exactly two lines: `PR: <url>` and `Handover: <path>`.
- **#6 — WorkItem directory.** WorkItems moved from `pr-descriptions/` to `workitems/` (post SC-668234), then moved again to `<repo-root>/.workitems/` (post SC-652177). Handover docs moved to `<repo-root>/.handovers/`. Both directories live inside the service repo, are gitignored, and are never pushed. Removes the hardcoded personal path assumption.
- **#7 — Implement agent re-explores despite Repo Style.** `pipeline-implement.md` now instructs the agent to treat `### Repo style` as authoritative and skip independent codebase exploration for style.
- **#9 — QA checklist in handover.** Handover document now includes a QA checklist section: one human-executable step per acceptance criterion.
- **#11 — Test agent gets weak handoff signal.** `### Test focus` field added to the Implementation section — an ordered list of the trickiest behaviours and failure paths the implementer identified. Test agent reads it as its primary starting point.
- **#12 — No abort/recovery path documented.** `abort-and-recovery.md` added.

Items not fixed (low priority or by design):
- **#8 — Plan mode.** Current conversational approval works; plan mode adds marginal value. Not changed.
- **#10 — Token efficiency.** Partially addressed by #7 (Repo Style trust). Full solution requires more complete codebase sampling at plan time. Ongoing.
- **#13 — ADR status update.** Added as a reminder in handover Next steps. Not automated.
- **#14 — Review agent reads diff.** Already implemented — `pipeline-review.md` step 1 runs `git diff <base-branch>...HEAD`. Not a gap.

---

## Future ideas

### Spec drift escalation
A formal "escalate to planning" path from the implement stage — if the spec is wrong, the agent writes a revised spec proposal to the WorkItem and pauses for human approval before proceeding.

### Parallel worktree orchestration
After the implement stage completes, if the WorkItem has independent sub-tasks identified during the parallelism check, offer to spawn parallel worktree sessions for them rather than continuing sequentially.

### Pipeline for Track A work
The current pipeline assumes one person working one story. The on-call-agent project has a Track A (infrastructure) and Track B (agent logic) running in parallel across different people. A future version could orchestrate multi-track work with explicit dependency gates between tracks.

### Post-ship monitoring
After deploy, a lightweight monitoring agent that checks Datadog for error spikes or anomalies related to the change and posts a summary. Closes the loop between "PR merged" and "change is healthy in production."
