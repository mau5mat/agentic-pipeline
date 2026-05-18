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
./pipeline-install.sh
```

The script checks prerequisites, copies skill files to `~/.claude/commands/`, installs the status line script, and walks you through tracker configuration. Safe to re-run — updates existing config without touching unrelated settings.

To remove the pipeline from a machine:

```bash
./pipeline-uninstall.sh
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
commands/              ← skill files (copied to ~/.claude/commands/ by install script)
setup/                 ← statusline.sh
docs/                  ← design docs, WorkItem schema, gaps, examples, abort/recovery
findings/              ← post-run findings from real pipeline sessions
pipeline-install.sh    ← one-time install: prerequisites, config, skills, status line
pipeline-uninstall.sh  ← remove everything the install script added
getting-started.md     ← new user guide
```
