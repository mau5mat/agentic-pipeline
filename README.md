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

## The WorkItem

Each stage agent starts fresh — no memory of prior stages. The WorkItem (`<repo-root>/.workitems/workitem-<ticket>.md`) is the shared state that gives each agent the full picture. Every agent reads the complete document, does its work, then appends its own section. By the time Ship runs, the entire history of the run is in one file.

## Prerequisites

- **Claude Code** (CLI or desktop app)
- **`git`** with branch names that include a ticket ID (e.g. `sc-123456`, `ENG-456`)
- **`gh` CLI** authenticated to GitHub — required for PR creation
- **`jq`** — required for the status line script (`brew install jq`)
- **Build tooling** — the pipeline discovers your lint and test commands during planning (Makefile, npm scripts, Rakefile, etc.). If it can't find them, it will ask. Empty test commands will stall the pipeline.
- **`CLAUDE.md` or `AGENTS.md` in your repo** — optional but recommended; the pipeline injects these as hard constraints into every stage agent

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
