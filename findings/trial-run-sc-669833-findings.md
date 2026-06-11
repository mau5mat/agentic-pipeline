# Pipeline Trial Run Findings: SC-669833

Multi-session feedback covering two real ticket runs and accumulated observations. Issues are classified as fixed (applied to skill files in this session) or open (requires further design work).

---

## Fixed Issues

### 1. Planning agent implemented instead of writing the WorkItem
The plan agent misread ExitPlanMode approval as permission to implement. In the normal Claude Code flow, "ExitPlanMode approved" means "proceed with code changes" — the planning skill uses the same approval gate for a different purpose (spec approval only), and the distinction was not salient enough to prevent the agent from transitioning into implementation mode.

**Fix applied:** Added a CRITICAL callout to `pipeline-plan.md` Step 4 making the approval semantics explicit: ExitPlanMode here approves spec content only. After approval, the only permitted action is writing the WorkItem file. No source file changes, no implementation.

---

### 2. Invalid agentType in orchestrator spawns
The orchestrator logged "Agent type 'pipeline-implement' not found" when spawning stage agents. The pipeline-run.md instruction "Use these stage names in order: pipeline-implement, ..." was being read as a subagent_type directive. The error was non-fatal (fell back to default agent) but is confusing.

**Fix applied:** Replaced the ambiguous "stage names" wording in `pipeline-run.md` with explicit instruction to use the default agent (no subagent_type) and pass the stage name only as a label.

---

### 3. Install wizard assumed macOS
Missing-prerequisite messages showed `brew install gh` and `brew install jq` unconditionally. Linux users see macOS-only instructions.

**Fix applied:** `pipeline-install.sh` now detects OS via `uname -s` and shows platform-appropriate install instructions for each missing tool.

---

### 4. Plan stage did not remind user to enable auto mode before pipeline-run
The plan stage completion message told users to run `/pipeline-run` but said nothing about needing auto mode active first. Without auto mode, each of the dozens of tool calls in a stage agent will interrupt with a permission prompt, stalling the run.

**Fix applied:** Plan stage completion message updated to prompt the user to run `/auto` before `/pipeline-run`. The pipeline-run.md Step 1 now also includes an explicit reminder.

---

### 5. Ship stage ran targeted tests only before pushing
Ship only ran `### Run with` (the targeted test command from the test stage) before pushing. The full suite was only verified post-implement, meaning regressions introduced between implement and ship (unlikely but possible) would be pushed without detection. The user's position: full suite before push, always.

**Fix applied:** `pipeline-ship.md` Step 1 now requires the full test suite command (from `### Repo style` Make targets) in addition to lint. The targeted run rationale has been removed.

---

### 6. Orchestrator did not stop cleanly after ship
After the ship gate passed, the orchestrator could continue with unnecessary narration or wait for input rather than stopping.

**Fix applied:** Added an explicit stop directive to the `pipeline-run.md` Final report section.

---

## Open Issues

### 7. Status bar visible across Claude sessions
The pipeline state file lives at `<repo>/.pipeline-state/<sc>/pipeline-state.json` and is not scoped to a Claude session. When two sessions are open in the same repo, both see the same status bar state. Sessions from different tickets do not conflict (different SC numbers), but two sessions on the same branch would.

**No fix possible without state design change.** One option: include a session-specific suffix (e.g. process ID or timestamp) in the state directory. Unclear if there is a stable session identifier accessible from within a skill.

---

### 8. Plan mode approval loop adds friction
When EnterPlanMode was called and ExitPlanMode approval was rejected or interrupted, the agent re-entered the approval loop. On one run this happened twice before the WorkItem was written. The root cause is that ExitPlanMode is a hard gate — any interruption resets the approval requirement.

**Suggestion:** Consider making plan mode optional when scope is already fully established from a ticket. The current design requires it unconditionally; a `--no-plan-mode` flag or a heuristic skip would reduce friction on well-scoped tickets.

---

### 9. Acceptance criteria did not cover environment-specific variables
During the sc-669833 run, a deploy YAML referenced `$(REMBG_CELERY_QUEUES)` but the variable was not defined in any overlay. This was caught at review, not during planning. The planner's acceptance criteria focused on code behaviour but did not cover deployment configuration.

**Suggestion:** Add a prompt to the planner's Step 2 investigation: when the WorkItem involves a new service or worker, explicitly check deploy YAMLs and overlays for required environment variable definitions and include them in acceptance criteria and `### Files likely touched`.

---

### 10. Files likely touched list incomplete
`lib/celery/singleton.py` and `worker.py` were both modified by the implement agent but were not listed in the WorkItem. The planner described them in prose but left them out of the structured list. Downstream agents (shipper, reviewer) had to infer.

**Suggestion:** The planner should treat the files list as a complete contract, not a summary. If a file is expected to change based on the investigation, it belongs in the list even if the change is small.

---

### 11. Spec drift not flagged as a conflict
The spec said `shops/{shop_id}/original/{shop_id}_modified.png` but the implementation used `shops/{shop_id}/modified/{shop_id}_modified.png`. The tester noted the actual path but did not flag it as a spec conflict. The path discrepancy was never surfaced to the user.

**Suggestion:** The test agent's instructions should include a step: compare key identifiers in the implementation (paths, field names, constants) against the spec's acceptance criteria. Any mismatch should be flagged as `[spec drift]` in `### Issues` rather than silently accepted.

---

### 12. Baseline flaky tests inflate noise
Two `test_menu_layout.py` failures listed in baseline actually passed post-implement. Flaky tests in the baseline cause one of two problems: if they pass post-implement, no harm done; if they fail post-implement, the orchestrator correctly excludes them — but if the baseline itself is wrong (a test listed as broken is actually just flaky), the orchestrator may not catch a real regression on that test.

**Suggestion:** Add guidance to the orchestrator's Step 4b: if a baseline failure is not consistently reproducible (run the failing subset a second time to confirm), mark it as `[suspected flaky]` rather than `[known broken]`. Do not add it to `### Known broken tests` automatically.

---

## What Worked Well

- WorkItem accumulated full context cleanly across all stages
- Gate/section structure gave a clear audit trail
- Review agent caught the REMBG_CELERY_QUEUES deployment issue before ship
- Pipeline resumed correctly from first incomplete stage after interruptions

---

## Summary

| # | Issue | Status |
|---|-------|--------|
| 1 | Plan agent implements on approval | Fixed |
| 2 | Invalid agentType in orchestrator | Fixed |
| 3 | Install wizard macOS assumption | Fixed |
| 4 | Auto mode not prompted before pipeline-run | Fixed |
| 5 | Ship stage targeted tests only | Fixed |
| 6 | Orchestrator no clean stop after ship | Fixed |
| 7 | Status bar across sessions | Open |
| 8 | Plan mode approval loop friction | Open |
| 9 | Acceptance criteria missing overlay vars | Open |
| 10 | Files likely touched incomplete | Open |
| 11 | Spec drift not flagged | Open |
| 12 | Baseline flaky tests | Open |
