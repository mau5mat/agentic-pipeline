# Pipeline Trial Run Findings — SC-648809

Third live run (Ruby service). Reclassify a specific error type and adjust downstream logging behaviour. Fewer mechanical issues than prior runs. Gate failure at implement was a genuine code issue (a visibility modifier broke an existing test), self-resolved by orchestrator. Review and ship passed cleanly.

---

## Issues to Fix

### 1. Derivation block still printing bash output
Despite the "do not print bash variable assignments" instruction, the agent ran the derivation block with explicit `echo` statements and printed all variables to the terminal.

**Fix:** Instruction strengthened — run silently, no echo statements, print only the single summary line after. Applied to `pipeline-start.md`.

---

### 2. Base branch prompt skipped — agent assumed main
The agent did not present `Base branch [main]:` to the user. It checked git status and then silently assumed main and entered plan mode without waiting for input.

**Fix:** Instruction strengthened — agent must prompt and wait for user response before proceeding. Cannot assume main or skip the prompt. Applied to `pipeline-start.md`.

---

### 3. Orchestrator not visible in status line
When `/pipeline` is invoked, nothing appears in the status line until the first sub-agent is spawned. The orchestrator's baseline run (Step 4b) and post-stage verification periods are invisible — user sees a blank status bar and cannot tell if anything is happening.

**Fix:** Orchestrator writes `orchestrating` state to `pipeline-state.json` immediately at Step 2. Writes `verifying` state after each agent returns and before running post-stage checks. Two new labels added to `statusline.sh`: `Orchestrating` and `Verifying`. Applied to `pipeline.md` and `setup/statusline.sh`.

---

### 4. Post-implement verification looked like implement agent work
Because the status line still showed `[Implement]` while the orchestrator was running the full test suite for post-implement verification, the user could not tell whether it was the implement agent or the orchestrator doing the work.

**Root cause:** Same as finding #3 — orchestrator has no status line presence.

**Fix:** Resolved by finding #3. After implement agent returns, status line updates to `[Verifying]` before the orchestrator runs the suite.

---

### 5. Gear symbol not green
The `⚙` prefix in the status line was not coloured — appeared in the terminal's default colour while the rest of the line used green labels and bold white values.

**Fix:** Wrapped `⚙` in GREEN in `statusline.sh`.

---

### 6. Handover timing table missing wall-clock total
The handover timing table showed per-stage agent durations and a sum total, but did not distinguish between agent time and wall-clock time (which includes orchestrator overhead: baseline run, verification, commits).

**Fix:** Handover timing table now shows two rows: `Agent total` (sum of stage durations) and `Wall-clock total` (computed from `PIPELINE_START` recorded at Step 2). `PIPELINE_START` added to `pipeline.md` Step 2. Applied to `pipeline.md` handover format.

---

### 7. Ship stage WorkItem template missing `### Gate`
The WorkItem template in `pipeline-ship.md` (Step 5) did not include `### Gate`. The gate instructions appeared in the triage section but were not in the template the agent appends to the WorkItem, making it easy to omit.

**Fix:** Added `### Gate` to the Ship WorkItem template. Applied to `pipeline-ship.md`.

---

### 8. WorkItem committed to GitHub
The WorkItem file was committed and pushed to the remote branch. WorkItems are pipeline-internal artifacts that must never leave the developer's local machine.

**Root cause:** Orchestrator was using `git add -A` for stage commits, which staged `.workitems/workitem-*.md` despite the global gitignore. Global gitignore entries only suppress untracked files from `git add -A` — an explicit path always stages.

**Fix:** Orchestrator commits now use explicit `git add <files from ### Files changed>` only. `git add -A` and `git add .` prohibited. Applied to `pipeline.md`. Note: if a WorkItem was accidentally committed, use `git rm --cached` and force-push to clean the branch before creating the PR.

---

### 9. PR description written to `.handovers/` instead of personal dir
`pr-description.md` had been updated during the SC-652177 post-trial work to write to `<repo-root>/.handovers/`, but `.handovers/` should contain only handover docs. PR descriptions are a separate artifact.

**Fix:** `pr-description.md` path reverted to a personal directory outside the repo. Strict scope rule added: `.workitems/` contains only `workitem-sc-*.md`, `.handovers/` contains only `handover-sc-*.md`. Applied to `pr-description.md`, `pipeline-start.md`, `pipeline.md`.

---

## What Worked Well

- Gate failure at implement was a genuine issue, correctly surfaced with full context
- Orchestrator self-resolved the implement failure (removed `private_class_method` line, confirmed suite clean)
- Test agent self-resolved weak assertions (bare rescue block replaced with correct `raise_error` assertion pattern)
- Review was fast and accurate — all acceptance criteria verified against the diff
- Ship passed cleanly
- The failure surfacing flow (reason → options → user choice) was noted as great UX
- Handover doc was useful and complete
- Final two-line output (`PR: ... / Handover: ...`) was clean

---

## Summary Priority

| Priority | Item |
|----------|------|
| High | #3, #4 — orchestrator invisible in status line |
| High | #8 — WorkItem committed to GitHub |
| Medium | #1, #2 — bash output / base branch prompt |
| Medium | #6 — timing table wall-clock total |
| Medium | #7 — ship gate missing from template |
| Low | #5 — gear colour |
| Low | #9 — PR description path |

All items above were fixed in the post-trial session on 2026-05-15.
