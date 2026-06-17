# Agentic Development Pipeline

A chain of specialist AI agents that takes a feature from spec to PR with minimal intervention between stages.

---

## How it works

The pipeline has two commands:

1. **`/pipeline-plan <branch-name>`**: interactive planning session. You describe what you're building; the agent reads the codebase, agrees a spec with you, and writes a WorkItem to disk.
2. **`/pipeline-run`**: orchestrator. Reads the WorkItem and chains four sub-agents automatically: implement → test → review → ship. Hands off a PR URL when done.

Each sub-agent starts fresh with no memory of prior stages. The WorkItem (`<repo-root>/.workitems/workitem-sc-XXXXXX.md`) is the shared state: every stage reads it in full, does its work, and appends its section. Because it lives on disk, the pipeline survives crashes and can always resume from the first incomplete stage.

Every stage ends by writing a gate (`PASS` or `FAIL [type]: <reason>`). The orchestrator independently verifies each gate before continuing. Failures surface with three options: **Retry**, **Override** (recorded permanently in the WorkItem), or **Halt**.

| Gate type | Meaning |
|-----------|---------|
| `[env]` | Infrastructure problem: OOM, missing dependency, network |
| `[code]` | Test failure, lint error, acceptance criterion not met |
| `[spec]` | Spec is wrong or infeasible; return to planning |
| `[pipeline]` | Stage ownership violation or tooling bug |

---

## What you need

- **Claude Code** (CLI or desktop app)
- **`gh` CLI** authenticated to GitHub
- **`jq`**: used by the status line ([install](https://jqlang.github.io/jq/download/))
- **Branch names that include a ticket ID** (Shortcut, Jira, Linear, etc.)
- **Build tooling**: the planner reads your Makefile (or `package.json`, `Rakefile`, `pyproject.toml`, etc.) to find the lint and test commands. It will ask if nothing is found.
- **`CLAUDE.md` or `AGENTS.md` in your service repo**: optional but recommended. The orchestrator injects these as hard constraints into every stage agent.

---

## Installation

```bash
./pipeline-install.sh
```

The script is interactive and safe to re-run to update your config. It checks prerequisites, installs skill files to `~/.claude/commands/`, configures the status line, and writes `~/.claude/pipeline.conf`.

To remove:

```bash
./pipeline-uninstall.sh
```

---

## Try the demo first

Before running the real pipeline, use the demo to see a full run and confirm your setup:

```
/pipeline-demo
```

Simulates implement → test → review → ship on a realistic scenario. No source files are modified, no PR is created. Use `--fail-at` to see the failure flow:

```
/pipeline-demo --fail-at implement
/pipeline-demo --fail-at test
/pipeline-demo --fail-at review
```

---

## Usage

### Step 1: Plan

Copy the branch name from your issue tracker and run:

```
/pipeline-plan username/sc-660363/-add-request-id-logging
```

The planner will ask for the base branch, create it, then have a scoping conversation with you before reading any code. Once scope is agreed, it reads the codebase, presents a spec for approval, and writes the WorkItem.

Then enable auto mode:

```
/auto
```

### Step 2: Run

```
/pipeline-run
```

The orchestrator spawns each stage in sequence. The status line updates as it progresses:

```
⚙  Agentic Pipeline: [SC-660363]  |  Agent: [Implement]  |  Stage: [1/4]  8m
```

The ship stage will ask for explicit confirmation before pushing. A full run typically takes 20–30 minutes.

### Step 3: Review the outputs

When everything passes:

```
PR:       https://github.com/org/repo/pull/123
Handover: /path/to/repo/.handovers/handover-sc-660363.md
```

The orchestrator will ask if you want to view the handover doc in the conversation or open it manually. The handover doc is the human-readable summary: what was built, timing, issues encountered, review notes, a QA checklist.

---

## Resuming after a failure

Re-running `/pipeline-run` always resumes from the first incomplete stage. A stage is complete only when its gate is explicitly `PASS`.

---

## Running stages individually

```
/pipeline-implement
/pipeline-test
/pipeline-review
/pipeline-ship
```

Useful for debugging a specific stage. Note: running ship standalone does not generate a handover doc; that is produced by the orchestrator.

---

## Runtime artifacts (local only, never pushed)

| Artifact | Location |
|----------|----------|
| WorkItems | `<repo-root>/.workitems/workitem-<ticket>.md` |
| Handover docs | `<repo-root>/.handovers/handover-<ticket>.md` |
| Pipeline state | `<repo-root>/.pipeline-state/<ticket>/pipeline-state.json` |

---

## Repository structure

```
commands/              ← skill files (copied to ~/.claude/commands/ by install script)
setup/                 ← statusline.sh
docs/                  ← design docs, WorkItem schema, security, examples, abort/recovery
pipeline-install.sh    ← one-time install: prerequisites, config, skills, status line
pipeline-uninstall.sh  ← remove everything the install script added
```
