# Pipeline Design

## The mental model

The pipeline is a sequence of four specialist stages, each reading the full WorkItem and contributing its work before handing off to the next:

- **Plan** — scoping conversation first (user-led, no code reads), then targeted codebase discovery informed by that conversation; produces a spec and writes the WorkItem document
- **Implement** — reads the spec, writes the code, runs lint, appends implementation notes
- **Test** — reads the spec and implementation notes, writes tests, appends coverage notes
- **Review** — fresh-eyes pass: verifies every acceptance criterion is met, tests are meaningful, no scope creep, no security concerns
- **Ship** — runs final checks, pushes the branch, creates the PR

Each stage runs as an isolated subagent with no memory of prior stages. The formal composition model — how stages chain and what happens on failure — is in the Either gates section below.

## Why a single accumulating document rather than separate artifacts

Each stage needs context from all previous stages — the tester needs the spec AND the implementation decisions, the reviewer needs everything. A single document that grows through the pipeline is simpler than coordinating multiple files and ensures each agent always has full context.

## Either gates — the pipeline as a monad

Each stage receives the WorkItem path, reads the full accumulated file, does its work, appends its section, and returns the same path — or a failure reason. The WorkItem path is the value threaded through the chain; the growing file content is the side effect of each stage.

```haskell
type WorkItem = FilePath  -- constant address; content at that path grows as a side effect

implement :: WorkItem -> IO (Either FailReason WorkItem)
test      :: WorkItem -> IO (Either FailReason WorkItem)
review    :: WorkItem -> IO (Either FailReason WorkItem)
ship      :: WorkItem -> IO (Either FailReason WorkItem)

pipeline :: WorkItem -> IO (Either FailReason WorkItem)
pipeline = implement >=> test >=> review >=> ship
```

`Either e` is a Monad in Haskell, so `>=>` composes left-biased: the first `Left reason` short-circuits the rest of the chain. The orchestrator reads each gate before spawning the next agent. A missing gate is treated as `Left "gate not written"`.

Each stage writes its gate as its final action — a `### Gate` field appended to its WorkItem section. This is the only thing the orchestrator inspects to decide whether to proceed.

**The three-way escalation is the orchestrator's interpretation of `Left`, not part of the stage type.** Stages are cleanly binary. When the orchestrator receives `Left reason`, it presents three options to the user:

- **Retry** — user fixes the issue and re-runs the pipeline from the failed stage
- **Override** — user acknowledges and proceeds; the override is recorded in Flags (auditable, never silent)
- **Halt** — pipeline stops entirely

This keeps the pipeline from dying on recoverable failures (e.g. a known flaky test) while ensuring failures are never silently bypassed.

This mechanism handles all failure modes in a single principled design rather than one-off fixes:
- Pre-existing test failures → the orchestrator runs `make test.unit` once after implement and surfaces any failures to the user via the retry/override/halt gate; the implement agent does not run tests
- Infeasible spec → implement gate fires before any code is written, not after
- Test gaps → test gate checks all criteria have coverage
- Push failures → ship gate checks `git push` succeeded

## Why sequential, not parallel

Within a single feature, stages have strict ordering dependencies: you can't test code that hasn't been written, can't ship untested code. Parallelism applies across independent features (separate worktree sessions), not within a single pipeline run.

The orchestrator does scan for parallel sub-tasks within the implementation stage and flags them before proceeding.

## Why the hard stop at ship

Review, QA, and deploy require human judgment — whether the implementation actually solves the problem, whether QA passes in a real environment, whether it's safe to deploy now given what else is in flight. Automating past those checkpoints is where autonomous agents cause real harm. The pipeline produces a PR; humans decide what happens to it.

## Why subagents rather than one long session

Context isolation. An agent that implemented the code will rationalise its own decisions. A fresh test agent hasn't been "contaminated" by the reasoning that produced the implementation — it reads the spec and the code cold and finds things the implementer missed. Same logic applies to review.

## Post-stage verification

The orchestrator does not trust stage agents' self-reported gate values alone. After each stage completes, before reading the gate, it independently verifies the most critical claims:

- **After implement:** checks `### Issues` for unresolved lint failures (trusts the agent's recorded result — does not re-run lint); runs the full test suite command from `### Repo style` as the correctness gate (output captured once, not re-run for multiple greps); checks that no files under test directories (`tests/`, `spec/`, `test/`, `__tests__/`) appear in `### Files changed` (implement owns source, not tests). If any check fails, the gate is overridden to FAIL.
- **After test:** reads `### Run with` and runs that exact targeted command; checks that no file in Tests `### Files changed` overlaps with Implementation `### Files changed` (test agent must not modify source files).
- **After review:** checks that `### Outcome` and the gate are consistent — an outcome of `changes requested` or `blocked` with a `Gate: PASS` is a contradiction and is overridden to FAIL.
- **After ship:** runs `gh pr view <url>` to verify the PR actually exists.
- **All stages:** checks that all required WorkItem fields for that stage are present. An agent that wrote `Gate: PASS` without populating the required sections failed.

This is the difference between trusting a summary and verifying a result. Shell commands don't hallucinate. Any override is logged in Flags as `[orchestrator] Post-stage verification failed at [stage]: <what failed>` and surfaces to the user as a Gate: FAIL.

## The orchestrator's job

The orchestrator (`/pipeline`) is not a stage — it's the `(.)` operator. Its only job is:
1. Load context: feedback rules from repo and project memory, CLAUDE.md and AGENTS.md from the repo root, and the `### Repo style` section from the WorkItem
2. Read WorkItem state to determine next incomplete stage
3. Spawn the appropriate stage agent with all loaded context injected as hard constraints
4. Run post-stage verification independently
5. Read the gate result, then repeat — or escalate to the user on `Left reason`

It doesn't implement, test, or review anything itself.

## Context injection

This is the critical correctness mechanism. When subagents are spawned by the orchestrator via the Agent tool, they start with no loaded context — no CLAUDE.md, no memory files, no knowledge of the codebase they're about to change. Without intervention they'd ignore repo conventions, write stylistically foreign code, and be unaware of rules like "no Co-Authored-By in commits" or "both `__bind_key__` and `__db_route__` required."

The orchestrator loads three categories of context before spawning anything, then injects all of it into every Agent tool prompt as hard constraints:

1. **Repo rules** — `CLAUDE.md`, `AGENTS.md`, and `.claude/CLAUDE.md` from the repo root. Explicit conventions, required patterns, things not to do.

2. **Feedback rules** — all `feedback_*.md` files from both the repo-specific memory directory and the Slice-level memory directory. Accumulated corrections and validated decisions from prior sessions.

3. **Repo style** — the `### Repo style` section written by the planner into the WorkItem. Observed de-facto conventions sampled from the actual codebase: code style, test style, paradigms, naming. Ensures agents write code that fits, not just code that works.

The orchestrator reports what it loaded (counts and found/not-found for each source) so silent misses are visible.

Memory path encoding: Claude Code encodes project paths by replacing `/` and `.` with `-`.
```bash
ENCODED="${REPO//[\/.]/-}"
MEMORY_DIR="$HOME/.claude/projects/$ENCODED/memory"
```

## The "handoff notes" concept

The WorkItem has a "Notes for X" subsection within each stage section. This is targeted communication from one agent to the next — not a log of everything done, but specifically what the next stage needs to know: edge cases already handled, assumptions made, things that definitely need coverage, approaches that were tried and rejected.

The distinction between a log and handoff notes matters for token efficiency and signal quality. A log is noise. Handoff notes are signal written with the reader's concerns in mind.

## The Flags section

A top-level section where any agent at any stage can record something notable without blocking progress. Used for: adjacent bugs noticed, thin coverage that's acceptable for now, security observations, anything that doesn't belong in stage-specific notes but shouldn't be lost. Reviewed by human before ship.

## Triage — self-resolve vs raise

> **Note:** The triage loop — run checks, classify, self-resolve up to 2 retries, raise on exhaustion, log everything — is structurally identical across all three stage files (`pipeline-implement.md`, `pipeline-test.md`, `pipeline-ship.md`). The checks and classification tables differ per stage, but the framework is shared. If you change the retry limit, logging format, or gate format, update all three files. In code this would be a shared function; in prompt files centralising it adds more risk than it removes.

Before writing a gate result, each stage classifies every failure it encounters:

**Self-resolve** — the correct fix is deterministic, within scope, requires no decision:
- Lint errors → fix them
- Test failures the agent introduced → fix the code or the test
- Missing test coverage → write it
- Out-of-scope code accidentally included → remove it

Max 2 retry attempts per issue. If self-resolve fails after 2 attempts, reclassify as raise.

**Raise** — fixing requires judgment, pre-existing state, or a decision the agent shouldn't make unilaterally:
- Unexpected test regressions — failures not introduced by this change that are surfaced by the orchestrator's post-implement suite run
- Acceptance criterion infeasible without a design decision
- Spec is wrong as written
- Security concern
- Self-resolve exhausted

Every issue — resolved or raised — is logged in a `### Issues` subsection within the stage's WorkItem section:
```
### Issues
- [self-resolved] Lint: unused import in app/foo.py — removed
- [raised] Unexpected regression: tests/test_bar.py::test_baz — not in baseline, not introduced by this change
```

This keeps the audit trail complete regardless of outcome.

The raise path feeds into the `Either` gate mechanism: a raised issue that can't be self-resolved becomes `Gate: FAIL: <reason>`, which the orchestrator surfaces to the user with retry/override/halt options.

## Handover document

When ship completes, the orchestrator synthesises the full WorkItem into a handover document written to `<repo-root>/.handovers/handover-sc-XXXXXX.md`. The terminal output is two lines only — `PR: <url>` and `Handover: <path>` — not the full document.

The handover is written for the human reviewer — it distils what happened during the pipeline run into what they actually need to know:

- **What was built** — goal and acceptance criteria checklist
- **Issues self-resolved** — collated from all stage `### Issues` sections, labelled `[self-resolved]`
- **Issues raised** — collated from all stage `### Issues` sections, labelled `[raised]`, with the decision made
- **Gate overrides** — any gates that were overridden and why
- **Flags** — anything logged in the top-level Flags section
- **Review focus areas** — 3-5 specific things derived from the above: file names, function names, edge cases that deserve attention. Not generic advice.
- **QA checklist** — one human-executable step per acceptance criterion: what to call, send, and observe in a running environment (not by reading code or tests)

The review focus areas are the most valuable part — rather than "please review the code," the reviewer gets "pay attention to `services/delivery/app/celery.py:45` because the implementer tried approach A and there's an edge case in the queue suffix logic."

## Opt-in design

The pipeline is opt-in by nature of the skills system — skills exist in `~/.claude/commands/` and activate only when explicitly invoked. Nothing in any CLAUDE.md or AGENTS.md triggers them automatically. Any agent in any session knows the pipeline exists (via `~/.claude/CLAUDE.md`) but will only suggest it, not activate it.
