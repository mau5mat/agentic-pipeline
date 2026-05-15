# Pipeline Trial Run Findings — SC-652177

Second live run (ros-service, delivery-service error handling). Key issue: implement agent churned for ~1 hour due to OOM on `make test.unit`. Most other pipeline stages worked well once past that.

---

## Issues to Fix

### 1. Plan stage outputs raw bash variables to terminal
The derivation block (`BRANCH=...`, `SC=...`, `Slug=...`) is printed verbatim. Ugly, noisy, not useful to the user.

**Fix:** Plan stage should print a single clean status line after derivation, not raw bash output. Same principle as the orchestrator's single summary line.

---

### 2. Base branch menu doesn't use key input
The "1. main / 2. other" prompt is presented as text but requires the user to type a full response. Should work as a 1/2 key press.

**Investigation needed:** Whether Claude Code's skill system supports a proper choice prompt. If not, the current text menu is the best available — but the plan stage should at least make clear "type 1 or 2".

---

### 3. Memory loading shows bash permission prompt
The shell syntax in the memory-loading block triggers a "cannot be statically analyzed / Do you want to proceed?" permission prompt. Interrupts flow unnecessarily.

**Fix:** Restructure the memory loading bash block to avoid dynamic path construction that triggers the static analysis warning. Use simpler, more predictable shell syntax.

---

### 4. Implement agent still ran make test.unit multiple times
Three `make test.unit` calls observed inside the implement agent's tool calls. This run likely happened while the installed files were stale (the orchestrator-owns-baseline redesign was in source but not yet synced to `~/.claude/commands/`). Should be resolved now that files are synced.

**Verify on next run.** If it recurs, the implement agent is ignoring the "do not run tests" instruction.

---

### 5. Implement agent read out-of-scope files (docs/bugs/)
The agent read `docs/bugs/TEMPLATE.md` and `docs/bugs/README.md`, then wrote a bug doc to `docs/bugs/sc-652177-...md`. This is scope creep — the WorkItem didn't specify bug doc creation, and docs/ is not in "Files likely touched."

**Fix:** Strengthen the "trust Repo Style, skip exploration" directive to explicitly say: only read files listed in "Files likely touched" plus files you need to understand in order to modify them. Do not explore the broader repo structure.

Also: the bug doc creation suggests the agent inferred from AGENTS.md that bug docs are required. If AGENTS.md says "create a bug doc for every bug fix," the agent was following the rules. This needs investigation — if AGENTS.md mandates it, the WorkItem should explicitly call it out in Files likely touched or Out of scope.

---

### 6. OOM killing make test.unit (exit code 137) — implement agent couldn't detect it
`make test.unit` was killed by the OS (SIGKILL, exit 137) due to Docker worker memory exhaustion. The agent read this as a test failure and kept retrying, not as an environment problem. It churned for ~1 hour.

Exit code 137 is not a test failure — it's the process being killed. The agent should distinguish between:
- Non-zero exit from test output (actual failures)
- Non-zero exit from the process being killed (environment problem → raise immediately, don't retry)

**Fix:** Add to implement stage (and orchestrator baseline): if the test command exits with code 137 (or produces output containing "Killed" / "OOM" / "signal: killed"), treat as environment failure, not test failure. Raise immediately with `Gate: FAIL: environment — test suite killed (OOM/SIGKILL)`. Do not self-resolve.

---

### 7. Docker ruff format command run directly
The agent ran:
```
docker run --rm -v "$(pwd)":/usr/src/app -w /usr/src/app ros-service-test:local ruff format <file>
```
This is fragile — it bypasses `make lint` and invokes the formatter directly via docker. Likely inferred from watching lint output, not from the Makefile. Should not happen.

**Fix:** Strengthen the lint instruction: use only the lint command from `### Repo style`. Do not invoke formatters, linters, or test runners directly — always go through the Makefile targets.

---

### 8. Commit message included scope brackets
Generated: `fix: [delivery-service] handle errors at one layer to avoid duplication in error logs`

The `[delivery-service]` scope bracket violates the "no scope brackets" convention (SC number already in branch name). The agent added the service name.

**Fix:** Make the no-scope-brackets rule more explicit in pipeline.md: "No scope brackets of any kind — not service names, not directory names, not ticket prefixes. The branch name already contextualises the commit."

---

### 9. Non-pipeline issues (OOM, environment) not visible enough to user
The root cause of the hour-long spin was a Docker OOM issue — not a pipeline design problem. But from the user's perspective it looked like the pipeline was stuck. The distinction between "pipeline issue" and "environment/infrastructure issue" wasn't surfaced.

**Fix:** When the orchestrator or an agent raises an environment-class failure (OOM, import error, environment broken), the gate FAIL message should clearly label it as an environment issue, not a code issue. The user should be able to tell immediately "this is not my code's fault."

---

### 10. No UI indicator that you're in a pipeline session
From the user's perspective, a pipeline session looks identical to a regular Claude Code session. There's no visible signal that the orchestrator is running, what stage is active, or that this session is "special."

**Investigation needed:** Whether Claude Code skills can set a status line or session label. If not, the orchestrator's single summary line (Branch: ... | SC: ... | Stage: ...) is the best available signal — but it only appears once at the start.

---

## Improvements / Questions

### 11. Plan mode for pipeline-plan
User believes EnterPlanMode for the WorkItem draft would feel more credible — plan mode signals "I'm proposing something for your approval" more clearly than a conversational draft.

**Consider:** Whether EnterPlanMode fits the interactive back-and-forth of planning. The current loop (draft → revise → approve → write) achieves the same gate but less formally. Low effort to try — medium risk of changing the flow in unexpected ways.

---

### 12. Handover should have its own directory
Like WorkItems moved from `pr-descriptions/` to `workitems/`, handover docs should move to `~/Development/Slice/handovers/<service>/`. `pr-descriptions/` is conceptually for PR-ready output; handover docs are pipeline-internal output.

**Fix:** Update pipeline.md handover write path, README runtime output table, and related docs. (Fixed in this session — see gaps-and-roadmap.md.)

---

### 13. Naming conventions review
`WorkItem`, `pipeline-implement`, `pipeline-test` etc. — naming could be reviewed for clarity, especially for distribution. Not blocking anything currently.

---

## What Worked Well

- Everything after the OOM issue resolved was smooth
- Review agent was fast and accurate
- Ship stage worked cleanly
- Gate mechanism correctly surfaced the implement FAIL
- Handover doc was useful

---

## Summary Priority

| Priority | Item |
|---|---|
| High | #6 — OOM/SIGKILL detection — do not retry an environment kill |
| High | #5 — Implement agent reading out-of-scope files |
| High | #7 — Direct docker/formatter invocation instead of make lint |
| Medium | #1 — Plan stage bash output verbosity |
| Medium | #8 — Commit message scope brackets |
| Medium | #3 — Memory loading permission prompt |
| Medium | #9 — Environment vs code failure visibility |
| Low | #2 — Base branch key input |
| Low | #11 — Plan mode consideration |
| Low | #13 — Naming conventions |
| Ongoing | #10 — UI pipeline indicator (Claude Code limitation) |
| Resolved | #4 — 3x make test.unit (stale installed files — now synced) |
| Resolved | #12 — Handover directory (fixed this session) |
