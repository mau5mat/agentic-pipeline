# Pipeline Design Session Findings: 2026-05-17

Improvements identified through design conversation rather than trial run observation. Each item documents the gap, the reasoning that surfaced it, and the fix applied.

---

## Issues Fixed

### 1. Concurrent pipeline sessions clobber each other's state

**Gap:** `~/.claude/pipeline-state.json` is a global singleton. SC-648810 finding #6 addressed cross-session bleed (status bar showing in unrelated Claude instances) by adding a `repo_path` field and matching it against `git rev-parse --show-toplevel` in `statusline.sh`. But this only solved the "unrelated session sees wrong pipeline" problem: it did nothing for two concurrent pipeline sessions on *different repos*. The second one to write state overwrites the first. The status bar would show the wrong ticket, or nothing at all, for the first session.

**Reasoning:** The `repo_path` matching fix was a lookup table: "which session is allowed to display this state?" It worked for one active pipeline. As soon as two pipelines run concurrently (different tickets, different repos), the global file becomes a contended resource and whichever writes last wins. The fix was in the wrong layer: it filtered display but didn't address the contention.

The root problem is that the state file is global when it should be scoped to the thing it describes: the repo and the ticket.

**Design conversation:** Moving the state file into the repo itself (like `.workitems/` and `.handovers/`) eliminates the contention entirely. Adding a per-ticket subdirectory means two tickets running concurrently on the same repo also cannot interfere. The full structure:

```
<repo-root>/.pipeline-state/
  <sc-number>/
    pipeline-state.json
```

`statusline.sh` no longer reads a fixed global path: it runs `git rev-parse --show-toplevel`, iterates `$REPO/.pipeline-state/*/pipeline-state.json`, and uses the first one with `"status":"running"`. No `repo_path` field needed: the repo is implicit.

**Cleanup:** Completion and halt both `rm -rf "$REPO/.pipeline-state/$SC_NUM"`: the subdir is deleted, not written to "done". statusline.sh finds nothing running and displays nothing. Crash recovery: `/pipeline-run` creates the subdir with `mkdir -p` at Step 2 before writing orchestrating state: this is idempotent, so a crashed run's stale dir is simply overwritten on resume. No stale "running" ghost is possible after a resumed run.

**Leftover concern (not addressed):** If two concurrent pipeline sessions run on the *same repo, same ticket*, one would still overwrite the other's state. This is not a realistic scenario: two sessions implementing the same ticket simultaneously would produce conflicting code regardless.

**Fix applied:** `commands/pipeline-plan.md`, `commands/pipeline-run.md`, `setup/statusline.sh`, `README.md`, `getting-started.md`, `docs/distribution-requirements.md`.

---

### 2. Command naming: `/pipeline-start` implies fresh start, breaks resume semantics

**Gap:** The orchestrator was invoked as `/pipeline`. The planning skill was invoked as `/pipeline-start`. These names were chosen at a point when "start" meant starting the pipeline. But `/pipeline-run` doubles as the *resume* command: when a stage fails, the user fixes the issue and runs `/pipeline-run` again to resume from the first incomplete stage. The name `/pipeline-start` for the orchestrator would be actively misleading: running `/pipeline-start` after a failure sounds like starting over, not resuming.

**Reasoning:** The semantics of the two commands are:
- Planning: always interactive, always starts fresh for a new ticket. `/pipeline-plan` is unambiguous: it's the planning phase.
- Orchestrating: can be both a first run and a resume. The command needs a name that works for both. "Run" is neutral: you run a pipeline, whether for the first time or to resume. "Start" implies only initial invocation.

**Fix applied:** `/pipeline-start` → `/pipeline-plan`, `/pipeline` → `/pipeline-run`. All skill files, docs, README, getting-started, CLAUDE.md, and memory updated.

---

### 3. Scoping before investigation: agent was reading code before understanding what was being built

**Gap:** The planning stage went straight into codebase reads after parsing the branch name. The branch slug was used to infer what was being built, but it's often imprecise: ticket scope drifts, descriptions are thin, and the user may have information the branch name doesn't capture. An agent that reads code first arrives at the scoping conversation with preconceptions baked in.

**Reasoning:** The conversation raised what happens when a ticket has no description: just a title captured to preserve an idea. In that case, a back-and-forth with the user to establish scope is essential, and it needs to happen *before* the agent forms a mental model of the codebase. If code is read first:
- The agent's questions are shaped by what it found, not what the user needs
- Scope assumptions are harder to correct once the investigation has been framed
- The user loses the chance to redirect before work begins

The right order is: understand the goal → then investigate the code with intent. Investigation is most efficient when it's targeted at a known scope, not exploratory against an assumed one.

**Fix applied:** Planning stage restructured into two explicit phases in `commands/pipeline-plan.md`:
1. **Scoping**: user-led conversation, no code reads. Agent infers lightly from branch slug and asks "what are you building?" Works through goal, acceptance criteria, constraints, out of scope.
2. **Investigation**: targeted codebase reads, now informed by the conversation. Reads the specific files that came up, not a broad scan.

Status bar updated to show `Planner: Scoping` and `Planner: Investigating` at each phase transition, so the user can see which phase is active.

---

### 4. "Verifying" status label: not clear it's the orchestrator, not a new agent

**Gap:** When the orchestrator ran post-stage verification checks, the status bar showed `Verifying`. This was reported as confusing: it looks like a fifth agent is running, not like the orchestrator itself is doing a check.

**Reasoning:** The pipeline's mental model has four specialist sub-agents (Implementor, Tester, Reviewer, Shipper) and one orchestrator. Verification is explicitly an orchestrator responsibility: "post-stage orchestrator verification": not a stage. A bare "Verifying" label obscures this: it implies an agent named Verifier, which doesn't exist. The label should reflect who is doing the verification.

**Fix applied:** `verifying` → `Orchestrator: Verifying` in `setup/statusline.sh`. Follows the same pattern as the two-word labels `Planner: Scoping` and `Planner: Investigating`: prefix names the actor, suffix names the activity.

---

## Summary

| Item | Source | Status |
|------|--------|--------|
| Concurrent pipeline clobbering | Design: identified as known gap, solved through conversation | Fixed |
| Command naming (`/pipeline-run` semantics) | Design: naming semantics discussion | Fixed |
| Scoping-first planning | Design: discussion about ticket quality and user knowledge | Fixed |
| `Orchestrator: Verifying` label | Design: "what is Verifying? it's not an agent?" | Fixed |
