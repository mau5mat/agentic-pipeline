# Pipeline Trial Run Findings: SC-648810

Fourth live run (Ruby service). Adjust HTTP error classification in a monitoring integration. Core pipeline logic: implement → test → review → ship with gates: worked without code-level issues. Findings are ergonomic and ownership issues.

---

## Issues to Fix

### 1. ExitPlanMode fails when Claude Code is in auto-mode
If a previous session left Claude Code in auto-mode, calling `ExitPlanMode` during `pipeline-start` errors: "You are not in plan mode. This tool is only for exiting plan mode after writing a plan." The skill has no way to enter plan mode first, so spec approval is skipped entirely.

**Fix:** Call `EnterPlanMode` before writing the spec draft. This ensures the agent is in plan mode regardless of prior session state. `ExitPlanMode` is then always valid.

---

### 2. Implement agent ran make test: not lint only
The implement agent ran `make test` during its stage, triggering a "Verifying" status bar update mid-implement. This is an ownership violation: the orchestrator owns all full suite runs; the implement agent runs lint only. The agent itself acknowledged the issue when prompted.

Also noted: the agent was running `make test` multiple times to grep different things from the output, rather than capturing output once to a temp variable. Each run was a full 6-minute test suite.

**Fix 1:** Strengthen the "lint only" instruction in `pipeline-implement.md`: explicit prohibition on `make test`, `make unit`, or any test suite command. Only the lint command from `### Repo style` may be run.

**Fix 2:** In `pipeline.md`, when running the baseline and post-stage test suites, capture output to a temp variable once (`TEST_OUTPUT=$(make test 2>&1)`) and grep from it as needed. Never run the suite a second time just to grep differently.

---

### 3. Implement agent touched spec/ files (Ruby ownership boundary)
The implement agent updated `spec/services/core_api_client_spec.rb` (an existing assertion). The ownership boundary rule checks for `tests/` but Ruby repos use `spec/`. The violation was not caught.

This left the test agent with no clean file to own and caused overlap at the test stage.

**Fix:** Extend the implement ownership prohibition and the orchestrator's post-stage cross-check to cover `spec/`, `test/`, and `__tests__/` in addition to `tests/`. The rule is: implement agents must not create or modify files in any test or spec directory, regardless of language or framework.

---

### 4. pipeline-start doesn't reset to main before creating branch
Starting a new ticket immediately after a previous one requires manually running `git checkout main && git pull` before `pipeline-start`. The skill should handle this.

**Fix:** At the start of `pipeline-start`, before creating the branch: run `git checkout main` (or the repo's default branch) and `git pull`. If there are uncommitted changes, stop and surface a clear message rather than proceeding.

---

### 5. Base branch prompt not visually distinct as waiting for input
The derivation summary line and base branch prompt appear in sequence with no visual separation, making the prompt look like continued output rather than a pause waiting for input.

```
Branch: username/sc-648810/... | SC: sc-648810 | Tracker: https://...
Base branch [main]: 
```

**Fix:** Add a blank line before the `Base branch [main]:` prompt and a clearer label, e.g.:
```
Branch: ... | SC: ... | Shortcut: ...

Base branch [main]: (press enter for main)
```

---

### 6. Status bar shown across all Claude Code instances
`~/.claude/pipeline-state.json` is a global file. Every open Claude Code instance reads it, so the pipeline status bleeds into unrelated sessions. Running two pipeline sessions concurrently would also overwrite each other's state.

**Fix:** Include `repo_path` in `pipeline-state.json`. In `statusline.sh`, run `git rev-parse --show-toplevel 2>/dev/null` and only display the status bar if the current repo path matches the one in state. Unrelated sessions suppress the display; the session running the pipeline shows it.

Multi-concurrent-pipeline support is a separate, harder problem: not addressed here.

---

### 7. Status bar agent labels imprecise
Current labels (`implement`, `test`, `review`, `ship`) describe the stage type but not the agent's role. The conceptual model is specialist agents, not pipeline stages.

**Fix:** Update `statusline.sh` case labels:
- `plan` → `Planner`
- `orchestrating` → `Orchestrating`
- `implement` → `Implementor`
- `verifying` → `Verifying`
- `test` → `Tester`
- `review` → `Reviewer`
- `ship` → `Shipper`

---

## Not Actionable Now

### 8. Token spend tracking per stage
Knowing the token cost of each agent invocation would be valuable for understanding pipeline cost and comparing stage efficiency. The timing table in the handover doc is the natural place for this.

**Blocker:** Skills run inside Claude Code's agent invocation: there is no mechanism to read per-turn token counts from within a skill. Requires either Claude Code API support or external tooling.

---

### 9. Baseline run overhead for targeted changes
The pre-implement baseline `make test` (6+ minutes) runs unconditionally, even for single-file changes with no plausible suite-wide impact. For very small changes this is mostly overhead.

**Consideration:** A lighter pre-flight (e.g. run only the spec file for the changed module) for single-file changes. Not implemented: the correctness guarantee of a full baseline is worth the cost in most cases; optimising for small changes is premature.

---

### 10. Ship agent re-ran tests
The ship agent ran the targeted test suite again during verification: a third run after baseline and the test-stage verify. This is by design (ship reads `### Run with`), but cumulative overhead is real. Not changed: the redundancy is a correctness guarantee at ship time.

---

### 11. Auto mode forced off after pipeline completes
After the pipeline finishes, auto mode (if enabled) remains on for the next session. A user returning to normal prompting might not notice they are still in auto mode.

**Consideration:** Forcing auto mode off on pipeline completion. Not actionable: no tool available to set Claude Code session mode from within a skill.

---

### 12. Issue tracker MCP for ticket description
Reading the ticket description automatically during planning could reduce manual copy-paste of acceptance criteria.

**Consideration:** Deferred: requires issue tracker MCP setup and user opt-in. Not a blocker.

---

## What Worked Well

- Core pipeline flow (implement → test → review → ship) had no code-level issues
- Gate mechanism correctly surfaced the lint failure; implement agent self-resolved
- Review and ship passed cleanly
- Status bar was useful for tracking stage transitions
- Per-stage timing in handover doc was valued

---

## Summary Priority

| Priority | Item |
|----------|------|
| High | #1: ExitPlanMode fails in auto-mode |
| High | #2: Implement agent running make test (ownership violation + redundant runs) |
| High | #3: spec/ ownership boundary missing (Ruby repos) |
| Medium | #4: pipeline-start: checkout main + pull before branch creation |
| Medium | #5: Base branch prompt not visually distinct |
| Medium | #6: Status bar bleeds across unrelated Claude Code instances |
| Low | #7: Status bar agent label names |
| Deferred | #8: Token spend tracking (no API support) |
| Deferred | #9: Baseline run overhead optimisation |
| By design | #10: Ship agent test re-run |
| Deferred | #11: Auto mode forced off after pipeline (no tool available) |
| Future | #12: Issue tracker MCP integration |
