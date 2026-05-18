# Agentic Development Pipeline

A chain of specialist AI agents that takes a feature from spec to PR without manual intervention between stages.

## The problem it solves

Without the pipeline, work is conversational and sequential — you prompt each step individually, context bleeds between stages, and the agent that implemented the code also reviews it. The pipeline formalises this into isolated stages with clean handoffs.

## Usage

```
/pipeline-plan <branch-name>   — interactive: create branch, scope the work, write WorkItem
/pipeline-run                   — automated: implement → test → review → ship, hands you a PR URL when done
```

Copy the branch name from your issue tracker and pass it to `/pipeline-plan`. The pipeline creates the branch and runs the planning conversation interactively. Once you approve the spec, `/pipeline-run` chains all remaining stages automatically.

```
/pipeline-plan username/sc-660363/-preparation-add-smoke-test-script
```

If the pipeline fails at any stage, fix the issue and run `/pipeline-run` again — it resumes from the first incomplete stage.

Individual stages can be run standalone: `/pipeline-implement`, `/pipeline-test`, `/pipeline-review`, `/pipeline-ship`

## What flows between stages

A single WorkItem document at `<repo-root>/.workitems/workitem-<ticket-id>.md`. Each stage reads the full document and appends its section:

```
Spec → Implementation + handoff notes → Tests + handoff notes → Review (gate) → Ship (PR URL)
```

## Installation

```bash
# 1. Copy skill files to Claude's commands directory
cp commands/*.md ~/.claude/commands/

# 2. Configure your tracker and preferences (one-time, per machine)
/pipeline-setup
```

`/pipeline-setup` asks for your issue tracker details and writes `~/.claude/pipeline.conf`. Run it once — all repos on this machine share the same config. Re-run at any time to update.

**Add pipeline artifact directories to your global gitignore** so they're never accidentally staged:

```bash
echo '.workitems/' >> ~/.gitignore_global
echo '.handovers/' >> ~/.gitignore_global
echo '.pipeline-state/' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

## Status line (optional but recommended)

The pipeline writes its current stage to `<repo-root>/.pipeline-state/<ticket-id>/pipeline-state.json`. A status line script reads this and displays it in the Claude Code UI — useful during the 10–30 minute gaps between stages.

```bash
cp setup/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "refreshInterval": 3
  }
}
```

## Runtime artifacts (local only, never pushed)

| Artifact | Location |
|----------|----------|
| WorkItems | `<repo-root>/.workitems/workitem-<ticket>.md` |
| Handover docs | `<repo-root>/.handovers/handover-<ticket>.md` |
| Pipeline state | `<repo-root>/.pipeline-state/<ticket>/pipeline-state.json` |
| PR descriptions | `~/.claude/pr-descriptions/<service>/<service>-<ticket>.md` |

## Repository structure

```
commands/          ← skill files (copy to ~/.claude/commands/)
setup/             ← statusline.sh
docs/              ← design docs, WorkItem schema, gaps, examples, abort/recovery
findings/          ← post-run findings from real pipeline sessions
getting-started.md ← new user guide
```
