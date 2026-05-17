# Getting Started

A chain of AI agents that takes a feature from spec to PR without manual intervention between stages. Define and approve the spec, then the pipeline handles implementation, testing, review, and ship.

The pipeline produces three artifacts:

- **WorkItem** (`<repo-root>/.workitems/`) — the internal document that accumulates context across every stage (agent-facing, not intended for human consumption)
- **Handover** (`<repo-root>/.handovers/`) — a human-readable summary of the run: what was built, issues encountered, timing, and a QA checklist
- **PR** — the pull request created on GitHub, with a generated description written to `~/Development/Slice/pr-descriptions/` before creation

---

## How it works

When you run `/pipeline-run`, you are invoking the **Orchestrator** — a parent agent that manages the entire run. The Orchestrator does not do the implementation work itself. Instead, it spawns a dedicated **sub-agent** for each stage, waits for it to complete, verifies the result, then spawns the next one. Each sub-agent starts fresh with no memory of prior stages — the Orchestrator injects the context it needs.

The stages, in order:

| Stage | Sub-agent | What it does |
|-------|-----------|-------------|
| **Implement** | `pipeline-implement` | Reads your spec, writes the code, runs lint |
| **Test** | `pipeline-test` | Reads the implementation notes, writes tests |
| **Review** | `pipeline-review` | Fresh-eyes pass — checks every acceptance criterion is met, tests are meaningful, no scope creep |
| **Ship** | `pipeline-ship` | Pushes the branch, creates the PR |

### The WorkItem is the shared state

The WorkItem (`<repo-root>/.workitems/workitem-sc-XXXXXX.md`) is a markdown file on disk that accumulates across the entire run. Each sub-agent reads the full file at the start of its stage, does its work, then appends its own section — decisions made, files changed, issues encountered, notes for the next agent. By the time Ship runs, the complete history of the run is in one document:

```
Spec → Implementation → Tests → Review → Ship
```

Because the state is file-based, it survives crashes and session restarts. This is why `/pipeline-run` can always resume from the first incomplete stage — it reads the WorkItem to determine what has already passed.

No sub-agent has memory of prior conversations. The WorkItem is the mechanism that gives each fresh agent the full picture of what came before.

### Gates — how the pipeline decides to continue or stop

Every sub-agent ends by writing a **gate** — a single explicit result appended to the WorkItem:

```
### Gate
PASS
```

or

```
### Gate
FAIL [type]: <reason>
```

The Orchestrator independently verifies each stage before accepting a PASS — it does not rely solely on the agent's self-report. If the gate is missing, it is treated as a failure.

When a failure occurs, the type prefix tells you immediately where the problem lies:

| Type | Meaning | Action |
|------|---------|--------|
| `[env]` | Infrastructure problem — OOM, missing dependency, network | Fix the environment |
| `[code]` | Code problem — test failure, lint error, acceptance criterion not met | Fix the implementation or tests |
| `[spec]` | Spec is wrong or infeasible | Revise the spec and retry |
| `[pipeline]` | Stage ownership violation or tooling bug | Check the pipeline setup |

The Orchestrator surfaces the failure with three options: **Retry** (fix and re-run), **Override** (continue anyway, recorded permanently in the WorkItem), or **Halt** (stop the pipeline). Overrides are never silent — they are written into the WorkItem and appear in the handover doc.

---

## Auto mode (recommended)

The pipeline runs best with auto mode enabled. Each stage spawns a sub-agent that makes dozens of tool calls — permission prompts between them will interrupt the flow and can stall a stage mid-run.

Enable auto mode in Claude Code before running `/pipeline-run`:

```
/auto
```

This is a per-session setting and does not persist. It remains your decision whether to enable it.

---

## What you need

- Claude Code (CLI or desktop app)
- `gh` CLI authenticated to GitHub
- `jq` installed (`brew install jq`)
- A Shortcut account (tickets are named `sc-XXXXXX`)

---

## Installation

```bash
# Copy skill files to Claude's commands directory
cp commands/*.md ~/.claude/commands/

# Install the status line script (shows pipeline progress in the UI)
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

Add to your global gitignore so pipeline artifacts don't accidentally get committed:
```bash
echo '.workitems/' >> ~/.gitignore_global
echo '.handovers/' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

---

## Step 1 — Start a new ticket

Go to Shortcut, open your ticket, and click the button to generate a branch name. It gives you something like:

```
mattroberts/sc-660363/-preparation-add-smoke-test-script
```

Open Claude Code in your service repo, then run:

```
/pipeline-plan mattroberts/sc-660363/-preparation-add-smoke-test-script
```

The planning agent will:
- Ask for the base branch, check out to it, pull latest, then create the new branch
- **Scoping conversation first** — infer what the work involves from the branch name and ask you to describe what you're building. You lead this conversation: goal, acceptance criteria, constraints, what's out of scope. No code is read yet.
- **Targeted codebase discovery** — once scope is established, read the relevant files and observe the repo's de-facto style (test structure, naming conventions, Make targets). Discovery is aimed at what came out of the conversation, not a speculative broad scan.
- Present the full spec for approval before writing anything to disk

This is the only interactive part of the pipeline. Once you approve the spec, the WorkItem is written and you're ready to run.

---

## Step 2 — Run the pipeline

```
/pipeline-run
```

This invokes the Orchestrator, which spawns each sub-agent in sequence. You'll see the status line update as each stage runs:

```
⚙  Agentic Pipeline: [SC-660363]  |  Agent: [Implement]  |  Stage: [1/4]  8m
```

A full run typically takes 20-30 minutes. The status line will reflect the current stage throughout.

---

## Step 3 — Get your outputs

When everything passes, the Orchestrator prints two lines:

```
PR: https://github.com/org/repo/pull/123
Handover: /path/to/repo/.handovers/handover-sc-660363.md
```

Open the handover doc — that's your human-readable summary of the run.

---

## When something fails

The Orchestrator stops, explains the failure type (see Gates above), and presents three options: **Retry**, **Override**, or **Halt**.

Re-running `/pipeline-run` always resumes from the first incomplete stage — stages that already passed are not re-run.

---

## Running individual stages manually

If you want to run just one stage without the Orchestrator:

```
/pipeline-implement
/pipeline-test
/pipeline-review
/pipeline-ship
```

Useful for debugging a specific stage in isolation.
