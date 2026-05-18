# Pipeline Trial Run Findings: SC-668234

First live run of the agentic pipeline on a real (test) ticket. These are observations, issues, and improvement suggestions from the session.

---

## Issues to Fix

### 1. Implement agent must not write tests
The implement agent wrote test files alongside implementation code. The test agent then had nothing to do except verify work already done. This is a pipeline contract violation: tests are exclusively the test agent's responsibility.

**Fix:** Add an explicit prohibition to `pipeline-implement.md`: do not create any files under `tests/`. If the agent produces test files, gate should be FAIL.

---

### 2. Full test suite run too many times
`make test.unit` was run by the implement agent, then again by the orchestrator for post-stage verification. For a growing codebase this is a significant time sink and won't scale.

**Fix:** Once the orchestrator has run a full `make test.unit` as the post-implement gate and it passes, subsequent stages (test, ship) should only run `make unit test=<changed paths>`. Full suite = correctness gate once per implement stage. Targeted runs = iteration loop for test and ship stages.

---

### 3. make lint run twice
The implement agent ran `make lint` as part of its own verification, then the orchestrator ran it again independently. Redundant.

**Fix:** One owner. Either the agent runs it and records the result in the WorkItem (orchestrator trusts that), or the orchestrator runs it and the agent doesn't. Prefer: agent runs it, records pass/fail in Issues, orchestrator reads the result rather than re-running.

---

### 4. Base branch assumption should not be a question
`pipeline-plan` asks "is this targeting main?" as a freeform question. This is unnecessary friction.

**Fix:** Assume `main` by default. State it as a derived fact ("Base branch: main") and only prompt for override if the branch name or context suggests otherwise.

---

### 5. Orchestrator output too verbose
The orchestrator cat-ed the full WorkItem to the terminal and narrated each tool call. Noisy and requires constant attention from the user.

**Fix:** Orchestrator should read the WorkItem silently and report only a single summary line of derived state (branch, SC number, current stage, next action). No full file dumps to terminal.

---

### 6. WorkItem directory should be separate from pr-descriptions
WorkItems are living documents that exist throughout the pipeline. `pr-descriptions/` implies PR-ready content and is conceptually wrong for this purpose.

**Fix:** Move WorkItem storage to a dedicated `workitems/` directory outside of `pr-descriptions/`. Update all pipeline stage commands to use the new path.

---

## Improvements / Questions

### 7. Implement agent is slow: biggest time sink
The implement agent re-explored the codebase independently despite the WorkItem containing a detailed Repo Style section. The planning stage is supposed to front-load this discovery so downstream agents can skip it.

**Investigation needed:** Was the implement agent ignoring the Repo Style section, or is the section not detailed enough for it to trust? If agents are re-doing codebase exploration regardless, the Repo Style section needs to be made more explicit as a "read this, skip exploration" directive in `pipeline-implement.md`.

---

### 8. Plan mode not used in pipeline-plan
The pipeline-plan skill runs as a normal conversational flow rather than using EnterPlanMode. The current "draft → review → approve → write" loop works, but plan mode would give a more structured approval gate.

**Consider:** Whether EnterPlanMode adds enough value over the current conversational approval to be worth the change. Low priority.

---

### 9. QA step ownership
The ship stage doesn't clearly state that post-deploy QA (deploy feature branch, manual verification) is the human's responsibility. The handover doc gestures at this but isn't explicit.

**Fix:** Add a standard QA checklist section to the handover doc format that makes clear what the human needs to do manually after the PR is merged.

---

### 10. Token efficiency
Each agent starts cold and re-reads the same files (AGENTS.md, existing domain files for style). There is duplicated discovery work across almost every stage.

**Longer term:** If the planner front-loads more complete codebase sampling into the WorkItem Repo Style section, downstream agents can trust it and skip their own exploration entirely. This would significantly reduce per-stage token cost and wall time.

---

## Additional Findings (post-run review)

### 11. Test agent gets weak handoff signal
Even with the implement-writes-tests fix in place, the test agent only receives the WorkItem and the implementation files. The "Notes for tester" section in the Implementation output is the only handoff signal, and it describes what was built rather than prescribing what edge cases to focus on.

**Fix:** Add a "Test focus" field to the Implementation section output: a short list of the trickiest behaviours, edge cases, and failure paths the implementer identified. This gives the test agent a starting point rather than requiring it to reverse-engineer test intent from the code.

---

### 12. No rollback / undo path documented
If the review gate fails or the pipeline is halted mid-run, there is no documented procedure for cleaning up: uncommitted changes, a pushed branch, a half-written WorkItem. Fine for a test run, but a problem for real work.

**Fix:** Add a "How to abort cleanly" section to the pipeline design docs covering: how to reset a half-written WorkItem, whether to delete the branch or leave it, and what state is safe to resume from vs. what needs manual cleanup.

---

### 13. ADR status never updated after merge
The pipeline files ADRs as `Proposed`. The handover doc says "move to Accepted after merge" but nothing enforces this and it is easy to forget.

**Fix:** Either have the ship stage automatically update ADR status to `Accepted` before creating the PR, or add it as an explicit checklist item in the handover QA section (#9). The former is cleaner.

---

### 14. Review agent reads WorkItem claims, not the diff
The review agent verifies the WorkItem's self-reported gate rather than independently reading the actual code diff. If an implement agent writes `Gate: PASS` but produced subtly bad code, the review agent may not catch it unless it explicitly reads the changed files.

**Investigation needed:** Confirm whether `pipeline-review.md` instructs the agent to read the actual changed files or just the WorkItem. If the latter, update it to require a diff read as the primary review surface, with the WorkItem used only for context.

---

### 15. Final orchestrator output buries the PR URL
The handover doc was printed inline at the end of a long session, making the PR URL hard to find. The most important output got lost in the noise.

**Fix:** The final orchestrator message should be exactly two lines: the PR URL and the path to the handover doc. Nothing else. All detail lives in the handover doc.

---

## What Worked Well

- WorkItem as shared state between agents: each agent had full context without re-derivation
- Gate/section structure gave a clean audit trail throughout the run
- Pre-commit hooks caught a real issue (codespell) that would have blocked a human committer too
- Review agent was thorough, fast, and raised a non-blocking code quality observation
- An abstraction boundary (stub behind an external service call) was correctly preserved end-to-end without agent drift

---

## Summary Priority

| Priority | Item |
|---|---|
| High | #1: implement must not write tests |
| High | #2: targeted test runs after first full pass |
| High | #3: lint run once, not twice |
| Medium | #5: orchestrator verbosity |
| Medium | #6: WorkItem directory |
| Medium | #7: implement agent speed / Repo Style trust |
| Low | #4: base branch assumption |
| Low | #8: plan mode |
| Low | #9: QA checklist in handover |
| Ongoing | #10: token efficiency |
| High | #11: test agent handoff signal (Notes for tester) |
| Medium | #12: rollback / abort path documented |
| Medium | #13: ADR status update after merge |
| High | #14: review agent reads diff, not just WorkItem |
| High | #15: final orchestrator output: PR URL + handover path only |
