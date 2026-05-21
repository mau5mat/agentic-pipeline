# Getting Started

A chain of AI agents that takes a feature from spec to PR without manual intervention between stages. Define and approve the spec, then the pipeline handles implementation, testing, review, and ship.

The pipeline produces three artifacts:

- **WorkItem** (`<repo-root>/.workitems/`): the internal document that accumulates context across every stage (agent-facing, not intended for human consumption)
- **Handover** (`<repo-root>/.handovers/`): a human-readable summary of the run: what was built, issues encountered, timing, and a QA checklist
- **PR**: the pull request created on GitHub

---

## How it works

When you run `/pipeline-run`, you are invoking the **Orchestrator**: a parent agent that manages the entire run. The Orchestrator does not do the implementation work itself. Instead, it spawns a dedicated **sub-agent** for each stage, waits for it to complete, verifies the result, then spawns the next one. Each sub-agent starts fresh with no memory of prior stages: the Orchestrator injects the context it needs.

The stages, in order:

| Stage | Sub-agent | What it does |
|-------|-----------|-------------|
| **Implement** | `pipeline-implement` | Reads your spec, writes the code, runs lint |
| **Test** | `pipeline-test` | Reads the implementation notes, writes tests |
| **Review** | `pipeline-review` | Fresh-eyes pass: checks every acceptance criterion is met, tests are meaningful, no scope creep |
| **Ship** | `pipeline-ship` | Pushes the branch, creates the PR |

### The WorkItem is the shared state

The WorkItem (`<repo-root>/.workitems/workitem-sc-XXXXXX.md`) is a markdown file on disk that accumulates across the entire run. Each sub-agent reads the full file at the start of its stage, does its work, then appends its own section: decisions made, files changed, issues encountered, notes for the next agent. By the time Ship runs, the complete history of the run is in one document:

```
Spec → Implementation → Tests → Review → Ship
```

Because the state is file-based, it survives crashes and session restarts. This is why `/pipeline-run` can always resume from the first incomplete stage: it reads the WorkItem to determine what has already passed.

No sub-agent has memory of prior conversations. The WorkItem is the mechanism that gives each fresh agent the full picture of what came before.

### Gates: how the pipeline decides to continue or stop

Every sub-agent ends by writing a **gate**: a single explicit result appended to the WorkItem:

```
### Gate
PASS
```

or

```
### Gate
FAIL [type]: <reason>
```

The Orchestrator independently verifies each stage before accepting a PASS: it does not rely solely on the agent's self-report. If the gate is missing, it is treated as a failure.

When a failure occurs, the type prefix tells you immediately where the problem lies:

| Type | Meaning | Action |
|------|---------|--------|
| `[env]` | Infrastructure problem: OOM, missing dependency, network | Fix the environment |
| `[code]` | Code problem: test failure, lint error, acceptance criterion not met | Fix the implementation or tests |
| `[spec]` | Spec is wrong or infeasible | Revise the spec and retry |
| `[pipeline]` | Stage ownership violation or tooling bug | Check the pipeline setup |

The Orchestrator surfaces the failure with three options: **Retry** (fix and re-run), **Override** (continue anyway, recorded permanently in the WorkItem), or **Halt** (stop the pipeline). Overrides are never silent: they are written into the WorkItem and appear in the handover doc.

---

## Auto mode (recommended)

The pipeline runs best with auto mode enabled. Each stage spawns a sub-agent that makes dozens of tool calls: permission prompts between them will interrupt the flow and can stall a stage mid-run.

Enable auto mode in Claude Code before running `/pipeline-run`:

```
/auto
```

This is a per-session setting and does not persist. It remains your decision whether to enable it.

---

## What you need

- **Claude Code** (CLI or desktop app)
- **`gh` CLI** authenticated to GitHub: the Ship stage uses it to create the PR
- **`jq`** (`brew install jq`): used by the status line script to read pipeline state
- **An issue tracker** with ticket IDs in your branch names (Shortcut, Jira, Linear, etc.)
- **Build tooling**: the planner reads your Makefile (or equivalent: `package.json` scripts, `Rakefile`, `pyproject.toml`, etc.) to discover the exact lint and test commands. If nothing is found, it will ask you to provide them. The pipeline cannot run tests without them.
- **`CLAUDE.md` or `AGENTS.md` in your service repo**: optional but strongly recommended. The orchestrator reads these and injects them as hard constraints into every stage agent. Without them, agents have no repo-specific rules to follow and will fall back to generic conventions.

---

## Installation

Clone the repo and run the install script:

```bash
./pipeline-install.sh
```

The script is interactive — it walks you through each step and is safe to re-run if you need to update your config later.

**What it does:**

1. **Checks prerequisites** — verifies `git`, `gh`, and `jq` are installed. If anything is missing it stops and tells you exactly how to install it.

2. **Installs skill files** — copies all pipeline commands to `~/.claude/commands/` so they appear as slash commands in Claude Code.

3. **Installs the status line** — copies `statusline.sh` to `~/.claude/` and automatically adds the `statusLine` entry to `~/.claude/settings.json` (creating the file if it doesn't exist, skipping if the entry is already there).

4. **Tracker configuration** — asks two questions:
   - Which tracker? `1` for Shortcut (the default), `2` for anything else (Jira, Linear, GitHub Issues, etc.)
   - For Shortcut: your org slug from `app.shortcut.com/YOUR-SLUG`
   - For other trackers: your ticket prefix (e.g. `ENG`), an optional URL template, and a label
   
   Have your tracker URL open so you can copy the org slug or ticket prefix.

5. **Org memory** (optional) — a path to a shared memory directory with feedback rules that apply across all repos on this machine. Skip this if you don't know what it is.

6. **Writes `~/.claude/pipeline.conf`** — the config file that all pipeline skills source at startup. Shows a summary and asks you to confirm before writing.

7. **Updates `~/.claude/CLAUDE.md`** — injects a pipeline description block so Claude knows about the commands. Idempotent: re-running updates the block rather than duplicating it.

8. **Global gitignore reminder** — checks whether `.workitems/`, `.handovers/`, and `.pipeline-state/` are already excluded from git. If not, prints the commands to add them.

After the script finishes, there is one potential manual step — the script prints the exact commands if needed:

- **`~/.gitignore_global`**: add the pipeline artifact directories if they aren't already excluded

To remove the pipeline later:

```bash
./pipeline-uninstall.sh
```

---

## Trying it out: `/pipeline-demo`

Before running the real pipeline, use the demo to see what a full run looks like and to confirm your setup is working:

```
/pipeline-demo
```

Run this inside any git repo. The demo simulates a complete pipeline run (implement → test → review → ship) using a realistic scenario: adding request ID logging to a FastAPI service. No source files are modified, no real tests run, no PR is created. It writes a WorkItem and handover doc to `.workitems/` and `.handovers/` in the repo, and updates the status line live so you can see stage progression in real time.

The `--fail-at` flag simulates a failure at a specific stage so you can see the Retry/Override/Halt flow before encountering it on a real run:

```
/pipeline-demo --fail-at implement   ← lint failure in the implement stage
/pipeline-demo --fail-at test        ← test failure mid-suite
/pipeline-demo --fail-at review      ← review agent catches an unmet acceptance criterion
```

At the end it prompts to clean up (default yes), removing the demo branch, WorkItem, and handover doc. A successful demo run confirms that git, pipeline config, status bar, and artifact paths are all set up correctly.

---

## Step 1: Start a new ticket

Open your ticket in your issue tracker and copy the branch name. It will look something like:

```
username/sc-660363/-preparation-add-smoke-test-script
```

Open Claude Code in your service repo, then run:

```
/pipeline-plan username/sc-660363/-preparation-add-smoke-test-script
```

The planning agent will:
- Ask for the base branch, check out to it, pull latest, then create the new branch
- **Scoping conversation first**: infer what the work involves from the branch name and ask you to describe what you're building. You lead this conversation: goal, acceptance criteria, constraints, what's out of scope. No code is read yet.
- **Targeted codebase discovery**: once scope is established, read the relevant files and observe the repo's de-facto style (test structure, naming conventions, Make targets). Discovery is aimed at what came out of the conversation, not a speculative broad scan.
- Present the full spec for approval before writing anything to disk

This is the only interactive part of the pipeline. Once you approve the spec, the WorkItem is written and you're ready to run.

---

## Step 2: Run the pipeline

```
/pipeline-run
```

This invokes the Orchestrator, which spawns each sub-agent in sequence. You'll see the status line update as each stage runs:

```
⚙  Agentic Pipeline: [SC-660363]  |  Agent: [Implement]  |  Stage: [1/4]  8m
```

A full run typically takes 20-30 minutes. The status line will reflect the current stage throughout.

---

## Step 3: Get your outputs

When everything passes, the Orchestrator prints two lines:

```
PR: https://github.com/org/repo/pull/123
Handover: /path/to/repo/.handovers/handover-sc-660363.md
```

Open the handover doc: that's your human-readable summary of the run.

---

## When something fails

The Orchestrator stops, explains the failure type (see Gates above), and presents three options: **Retry**, **Override**, or **Halt**.

Re-running `/pipeline-run` always resumes from the first incomplete stage: stages that already passed are not re-run.

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
