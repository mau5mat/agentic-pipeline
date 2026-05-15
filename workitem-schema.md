# WorkItem Schema

The WorkItem is the pipe. It lives at:
`<repo-root>/.workitems/workitem-<sc-number>.md`

Created by `/pipeline-plan`. Read and appended by every subsequent stage.

---

## Full template

```markdown
# Work Item: SC-XXXXXX — [title]

**Service:** [service-name]
**Type:** feature | bug | migration
**Date:** [YYYY-MM-DD]
**Branch:** [branch-name]
**Base branch:** [main | or user-specified branch]
**Shortcut:** https://app.shortcut.com/slicernd/story/XXXXXX/-<description>

## Flags
> Any stage may append here. Reviewed by human before ship.

---

## Spec
> Set during planning. Read-only for all downstream stages.

### Goal
[what and why]

### Acceptance criteria
- [ ] [specific, testable condition]

### Files likely touched
- `path/to/file.py` — reason

### Known constraints / gotchas
[anything a fresh agent would not know from reading the code]

### Repo style
[observed de-facto conventions — code style, test style, paradigms, naming. Written by the planner from sampling the codebase. Injected into every downstream agent as a hard constraint.]

### Out of scope
[explicitly excluded]

---

## Implementation
> Branch, Files changed, Key decisions, Notes for tester, Test focus, Issues, and Gate are filled by pipeline-implement. Baseline is written by the orchestrator before the implement agent is spawned.

### Branch
### Files changed
### Baseline
> Written by the orchestrator in Step 4b, before the implement agent runs. Do not overwrite.
### Key decisions
### Notes for tester
### Test focus
### Issues
> Each issue logged as `[self-resolved]` or `[raised]` with what it was and how it was handled.
### Gate
> PASS or FAIL: <reason>. Written last. Orchestrator will not proceed if FAIL.

---

## Tests
> To be filled by pipeline-test.

### Files changed
### What's covered
### Edge cases verified
### Run with
### Notes for shipper
### Issues
> Each issue logged as `[self-resolved]` or `[raised]` with what it was and how it was handled.
### Gate
> PASS or FAIL: <reason>. Written last. Orchestrator will not proceed if FAIL.

---

## Review
> To be filled by pipeline-review.

### Outcome
approved | changes requested | blocked
### Notes
### Gate
> PASS or FAIL: <reason>. approved → PASS. changes requested or blocked → FAIL.

---

## Ship
> To be filled by pipeline-ship.

### PR URL
### Commit SHA
### Issues
> Each issue logged as `[self-resolved]` or `[raised]` with what it was and how it was handled.
### Gate
> PASS or FAIL: <reason>. Written last.
```

---

## Field explanations

**Flags** — top-level safety valve. Any agent at any stage appends here with a `[stage]` prefix when they notice something that doesn't belong in their stage section but shouldn't be lost. Examples: adjacent bug spotted, thin coverage that's acceptable, security observation. Reviewed by human before ship. Not a blocker unless the agent explicitly marks it as one.

**Goal** — what this achieves AND why it is needed. Both matter. "What" tells the implementer what to build. "Why" tells the reviewer whether the approach makes sense and helps future readers understand the commit history.

**Acceptance criteria** — specific, testable conditions. "Works correctly" is not acceptable. "POST /v1/webhooks returns 200 and enqueues a job" is. The test agent uses these as its primary source of truth for what to cover.

**Files likely touched** — confirmed by reading the code during planning, not guessed. Helps the implement agent start in the right place and the review agent know where to focus.

**Repo style** — observed de-facto conventions sampled from the codebase during planning. Covers: code style (naming, error handling, patterns), test style (framework, fixtures, assertion style, what level tests operate at), paradigms (OOP vs functional, sync vs async, layering), general conventions (import ordering, file structure), and **Make targets** (the exact lint, full suite, and targeted test commands from the Makefile). Written from reading actual files, not inferred from repo name or language. This field exists because subagents start with no codebase context — without it they write technically correct but stylistically foreign code and use the wrong test commands. The planner is the right agent to capture this because it's already reading the codebase; the observation cost is paid once and benefits all downstream stages.

The Make targets subsection must be present and must use the exact commands from the Makefile (or equivalent), e.g.:
```
**Make targets:**
- Lint: `make lint`
- Full suite: `make test.unit`
- Targeted: `make unit test=<space-separated paths>`
```

**Known constraints / gotchas** — the most valuable field in the spec. Captures institutional knowledge that a fresh agent would not find by reading the code: "both `__bind_key__` and `__db_route__` must be set or the RoutingSession breaks," "worker memory needs scaling before cutover or it OOMKills," "this vhost needs a dedicated Celery instance." This is the field that prevents repeating known mistakes.

**Out of scope** — explicitly names what will NOT be done. Prevents implementers from expanding scope when they notice adjacent issues. Keeps each work item bounded and reviewable.

**Baseline** — failing test IDs recorded by the orchestrator before spawning the implement agent. "Clean" if the suite was green. Written by the orchestrator, not the implement agent. Used in the orchestrator's post-implement suite run to distinguish pre-existing failures from regressions introduced by the implementation — pre-existing failures are excluded from the gate, not raised as blockers.

**Notes for tester** — written by the implementer specifically for the test agent. Edge cases already handled (so tests don't duplicate), assumptions made (so tests can verify them), things that definitely need coverage, approaches tried and rejected (so tests can cover the boundary that made them fail). Not a log — targeted communication.

**Test focus** — an ordered list of the trickiest behaviours, failure paths, and edge cases the test agent should prioritise, derived from the implementer's experience writing the code. Different from `### Notes for tester`: Notes for tester is general context; Test focus is a ranked priority list of where tests are most likely to miss something important. The test agent starts here before reading anything else.

**Notes for shipper** — written by the tester for the ship agent. Flaky tests to watch, known coverage gaps that are acceptable for this PR, anything the shipper should be aware of before pushing.

---

## Stage completion detection

The orchestrator determines whether a stage is complete by checking whether the section contains a `### Gate` field explicitly set to `PASS`. A section with partial content, a missing gate, or `Gate: FAIL` is treated as incomplete. Stages must be completed in order.
