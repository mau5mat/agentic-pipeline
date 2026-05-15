# Agentic Development Pipeline

A chain of specialist AI agents that takes a feature from spec to PR without manual intervention between stages.

## The problem it solves

Without the pipeline, work is conversational and sequential — you prompt each step individually, context bleeds between stages, and the agent that implemented the code also reviews it. The pipeline formalises this into isolated stages with clean handoffs.

## The two commands

```
/pipeline-start <branch-name>   — interactive: create branch, work out spec, write WorkItem
/pipeline                       — automated: implement → test → review → ship, hands you a PR URL when done
```

Expected flow: copy the branch name from Shortcut, then run `/pipeline-start` with it. The pipeline creates the branch, runs planning interactively, then `/pipeline` chains all remaining stages automatically.

```
/pipeline-start mattroberts/sc-660363/-preparation-add-smoke-test-script
```

If the pipeline fails at any stage, fix the issue and run `/pipeline` again — it resumes from the first incomplete stage.

Individual stages can be run standalone if needed:
`/pipeline-implement`, `/pipeline-test`, `/pipeline-review`, `/pipeline-ship`

All skills live in `~/.claude/commands/`.

## What flows between stages

A single WorkItem document at:
`<repo-root>/.workitems/workitem-<sc-number>.md`

Each stage reads the full document and appends its section. The document accumulates:
Spec → Implementation + handoff notes → Tests + handoff notes → Review (gate) → Ship (PR URL)

## Installation

Copy the skill files to your Claude commands directory:

```bash
cp commands/*.md ~/.claude/commands/
```

That's it. Invoke `/pipeline-start <branch-name>` from any service repo to start.

## Repository structure

```
commands/                        ← skill files (copy these to ~/.claude/commands/)
  pipeline.md                    ← orchestrator
  pipeline-start.md
  pipeline-implement.md
  pipeline-test.md
  pipeline-ship.md
  pipeline-review.md
  pr-description.md              ← dependency of pipeline-ship
setup/                           ← optional setup files
  statusline.sh                  ← status line script (see Status line setup below)
getting-started.md               ← new user guide
design.md                        ← architectural decisions and rationale
workitem-schema.md               ← full WorkItem template with field explanations
gaps-and-roadmap.md              ← known limitations and future improvements
abort-and-recovery.md            ← how to stop, undo, or resume a pipeline run
example-happy-path.md            ← annotated happy-path example (WorkItem + narrative + handover)
example-unhappy-path.md          ← annotated unhappy-path example
findings/                        ← post-run findings from real pipeline sessions
  trial-run-sc-668234-findings.md
```

## Status line setup (optional but recommended)

The pipeline writes its current stage to `~/.claude/pipeline-state.json` while running. A status line script reads this and displays it persistently in the Claude Code UI — useful during the 10-30 minute quiet gaps between stage turns.

```bash
cp setup/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add to `~/.claude/settings.json` (create the file if it doesn't exist):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "refreshInterval": 3
  }
}
```

The status line will show: `▶ Pipeline sc-XXXXXX → implement` while a stage is active, and disappear once the pipeline completes.

## Runtime output (stays local, never pushed)

Most pipeline artifacts live inside each service repo in hidden directories:

| Artifact | Location |
|----------|----------|
| WorkItems | `<repo-root>/.workitems/workitem-<sc>.md` |
| Handover docs | `<repo-root>/.handovers/handover-<sc>.md` |
| PR descriptions | `~/Development/Slice/pr-descriptions/<service>/<service>-sc-<number>.md` |

These directories are created automatically. **Add `.workitems/` and `.handovers/` to your global gitignore** (`~/.gitignore_global`) to prevent accidental staging — the pipeline does not touch any `.gitignore` file itself.

```bash
echo '.workitems/' >> ~/.gitignore_global
echo '.handovers/' >> ~/.gitignore_global
# Make sure your global gitignore is configured:
git config --global core.excludesfile ~/.gitignore_global
```
