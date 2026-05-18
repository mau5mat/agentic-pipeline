# Pipeline Trial Run Findings: SC-655268

Fifth live run. Mid-pipeline policy conflict (AGENTS.md §10 mandating migration-as-separate-PR vs bundled plan) surfaced during implement stage, resolved by branching off a migration pipeline mid-session. Core pipeline logic worked cleanly. Findings split between actionable fixes and deferred/by-design items.

---

## Issues to Fix

### 1. Pre-baseline cache clear missing: stale .pyc caused spurious third suite run

The first baseline `make test.unit` hit a stale `.pyc` cache causing import file mismatches. The baseline had to be re-run after a cache clear, meaning the suite ran three times instead of the expected two (baseline + post-implement correctness gate). Each run costs ~3 minutes.

**Fix:** Add `find . -name "*.pyc" -delete && find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null` immediately before the baseline run in `pipeline-run.md` Step 4b. Eliminates this class of spurious extra run. Low risk: cache is always safe to clear before a baseline.

---

### 2. Test agent should run lint on new test files before committing

The test commit hit a pre-commit hook failure (Ruff TC001: import into TYPE_CHECKING block) that wasn't caught before the attempt. This caused a hook failure, an edit, and a second commit attempt. The test agent was relying on the pre-commit hook to catch lint errors rather than running lint itself.

**Fix:** Add an explicit lint step to `pipeline-test.md` before the commit: run the lint command from `### Repo style` on the newly created test files. Record result in `### Issues`. Self-resolve if possible (max 2 retries). Only proceed to commit after lint is clean.

---

### 3. AGENTS.md policy conflicts not surfaced during planning

The planner proposed bundling migration + code into one PR. AGENTS.md §10 explicitly prohibits this (migrations must deploy as independent PRs ahead of app code). The planner didn't read AGENTS.md during the scoping or investigation phase, so the policy conflict wasn't caught until the implement agent flagged it mid-pipeline. By that point, the spec had been approved, the WorkItem written, and the branch created: unwinding required a mid-pipeline conversation and a second pipeline session for the migration.

The fix is not simply "read AGENTS.md earlier": the planner already reads it in Step 2 (investigation). The gap is that policies found in AGENTS.md aren't being cross-checked against the proposed approach before the spec is presented for approval.

**Fix:** In `pipeline-plan.md` Step 2, add an explicit policy conflict check: after reading AGENTS.md, identify any policies that apply to the proposed work (branching rules, PR structure, required file types, deploy order). If a conflict exists with the current plan, surface it to the user *before* presenting the spec for approval: not as a flag, but as a blocking question: "AGENTS.md §10 requires migrations to deploy as separate PRs. The current plan bundles migration and code. How do you want to proceed?" The user decides; the decision is reflected in the spec before it's written to disk.

---

### 4. Known broken test infrastructure has no representation in the WorkItem

A migration test failure (a pre-existing `KeyError`) required investigation to confirm it was an environment issue (subprocess harness) rather than a new regression. This ate time and created uncertainty. The pipeline has no concept of known-broken test targets: every failure is investigated from scratch.

**Fix:** Add an optional `### Known broken tests` field to the WorkItem Spec section. During planning, the user can populate this with test targets known to be broken in the current environment (e.g. integration test harness issues, flaky infra-dependent tests). The orchestrator reads this before the baseline run and treats failures matching those targets as expected: they do not block the pipeline and are logged in Flags rather than raised as Gate: FAIL. This field is optional and empty by default.

---

### 5. Planning time not reflected in handover timing table

The handover timing table covers implement → test → review → ship, with a wall-clock total from `PIPELINE_START` (recorded at the start of `/pipeline-run`). Planning time is excluded entirely: the wall-clock total understates the true time investment in the feature, and the user has no record of how long planning took.

**Fix:** Write a `### Timing` field to the WorkItem during planning (wall-clock from branch creation to WorkItem write). In the handover doc, render two timing sections: **Planning** (from WorkItem header) and **Pipeline run** (existing table). The agent total remains the sum of automated stages; a new "Total including planning" row is added to the run table.

---

## Not Actionable Now

### 6. Base branch prompt: pressing enter doesn't register as input

The `Base branch [main]: (press enter for main)` prompt waits for user input, but pressing enter alone doesn't always register cleanly in the Claude Code UI. There's no picker or explicit confirm mechanism available.

**Blocker:** Claude Code skill prompts have no form input primitives: only free text. The current "empty input = main" design is the best available given the constraints. No fix possible without a Claude Code UI change.

---

### 7. Stage counter [N/4] inaccurate during orchestrator and planner sub-stages

The status bar shows `Stage: [1/4]` etc. This was designed for the four automated stages (implement, test, review, ship). During `orchestrating`, `verifying`, `plan-scoping`, and `plan-investigating`, there is no meaningful stage number: but the counter either shows a stale value or is absent. It's unclear what [1/4] means when the orchestrator is verifying.

**Consideration:** Could suppress the stage counter during non-numbered phases (orchestrating, verifying, all plan phases) and only show it during actual stage execution. Low priority: cosmetic. Deferred.

---

### 8. Context compaction mid-pipeline interrupts flow

Long pipeline runs trigger Claude Code's automatic context compaction, which can interrupt the orchestrator mid-stage. The user noted this is irritating.

**Blocker:** This is a Claude Code runtime behaviour, not something the pipeline can control. No fix available from within a skill.

---

### 9. Hidden pipeline dirs show as untracked in git status

`.workitems/`, `.handovers/`, and `.pipeline-state/` appear as untracked when `git status` is run, making the working tree look dirty. The user's global gitignore handles this, but it requires setup.

**Not a bug:** The README and getting-started docs both instruct users to add these to their global gitignore. This is a one-time setup step, not a pipeline issue. Could make the instruction more prominent in getting-started.

---

### 10. spec-vs-execution gap: in-scope fixture update not done

The Spec and Implementation sections both noted that a test fixture in `conftest.py` needed updating. Neither the implement nor test agent did it. The agent prioritised new tests over updating existing fixtures, and it was flagged in Flags as a non-blocking follow-up.

**Consideration:** Hard to enforce generically: "update existing fixtures" is a soft obligation that doesn't map cleanly to a gate check. The right mitigation is precise acceptance criteria: if a fixture update is genuinely in scope, it should appear as an explicit acceptance criterion so the review stage can catch it missing. Not a pipeline fix: a spec discipline issue.

---

### 11. SC ticket in status bar during migration sub-pipeline

User was unsure whether the status bar ticket number updated correctly when branching off to a migration pipeline mid-session. Per the design, each pipeline writes its own SC number to its own `.pipeline-state/<SC_NUM>/` subdir. A second `/pipeline-plan` for the migration ticket would create a new subdir and statusline.sh would pick up whichever is running. Should work correctly: not investigated further.

---

## What Worked Well

- Migration separation handled cleanly: stash-and-pop approach replaced with clean branch separation once the policy conflict was understood
- Flag mechanism worked as intended: the AGENTS.md policy conflict was recorded in the WorkItem and will surface to the reviewer
- Baseline caught a real environment problem (stale .pyc) before the implement agent ran: correct design
- Test agent found the correct fixture pattern (factory create vs build + explicit commit) on first attempt
- Scope was tight: implement agent didn't touch anything outside the stated files except mandatory AGENTS.md-required docs and a type-checker-required addition

---

## Summary Priority

| Priority | Item |
|----------|------|
| High | #3: AGENTS.md policy conflicts not surfaced during planning |
| High | #2: Test agent should lint before committing |
| Medium | #1: Pre-baseline cache clear (stale .pyc → spurious third run) |
| Medium | #5: Planning time missing from handover timing |
| Medium | #4: Known broken tests field in WorkItem |
| Deferred | #6: Base branch prompt UX (Claude Code limitation) |
| Deferred | #7: Stage counter accuracy during sub-stages |
| By design | #8: Context compaction (runtime behaviour) |
| By design | #9: Hidden dirs in git status (user gitignore setup) |
| Spec discipline | #10: Fixture update missed (acceptance criteria gap, not pipeline) |
| Likely fine | #11: SC ticket in status bar during sub-pipeline |
