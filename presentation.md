---
marp: true
theme: catppuccin
paginate: true
---

# Agentic Development Pipeline
### Spec to PR, without manual steps between stages

---

## The problem with conversational AI coding

Working with an AI assistant today looks something like this (results may vary):

- Prompt it to implement something
- Prompt it to write tests
- Prompt it to review the code it just wrote
- One long tangled conversation doing everything

**No structure. No separation of concerns. The same agent that wrote the code reviews it.**

I would prefer a little more rigour, if possible.

---

## A few things to say upfront

- **HIGHLY opinionated.** Scoped work, clean handoffs, explicit failure handling, separation of concerns. You might weight those differently.
- **Slower than ad-hoc prompting.** Code generation is a solved problem: you can have working code in seconds. This trades speed for structure and a higher bar for what ships.
- **"Confidence" and LLM-generated code** is a stretch, and the irony is not lost on me.. But worth trying to make it less spooky.

---

## The mental model

I kept coming back to a functional style mental model for how it would look:

```haskell
plan :: Conversation -> IO WorkItem

type Stage = WorkItem -> IO (Either FailReason WorkItem)

implement :: Stage
test      :: Stage
review    :: Stage

ship :: WorkItem -> IO (Either FailReason PR)

pipeline :: WorkItem -> IO (Either FailReason PR)
pipeline =  implement >=> test >=> review >=> ship
```

`plan` produces the value that flows through everything else.
Each non-terminal stage returns `Right WorkItem` to continue, or `Left FailReason` to stop.

**That became the heuristic for the whole design.**

---

## Why I think this could raise the bar (???)

With a conversational approach, the model is judge and jury. With this pipeline, it still is. But now it also has to take the stand.

With a pipeline inspired by this model:

- Each stage has a **single job** and a **clear success condition**
- Failures are **typed** and surfaced at each stage, letting you know immediately what kind of problem you're dealing with
- The agent that implements the code does **not** review it
- A fresh agent at each stage means no context bleed from prior decisions
- The full history of the run is on disk, not in a conversation window

In practice: the review stage has caught regressions the implement agent introduced, surfaced them with the specific criterion they violated, and stopped the pipeline before a bad PR was opened.

---

## An orchestrator and five agents

- **Orchestrator:** manages the run, injects context into every agent, runs baseline tests, independently verifies each gate, handles failures, writes the handover doc
- **Plan:** scoping conversation with you, codebase investigation, writes the WorkItem
- **Implement:** reads the WorkItem, writes code, runs lint
- **Test:** reads implementation notes, writes tests
- **Review:** fresh-eyes pass, checks every acceptance criterion
- **Ship:** pushes branch, opens the PR

Each stage agent starts completely fresh, with no memory of prior stages.

---

## Two commands

```
/pipeline-plan username/sc-123456/-my-feature-branch
```
Scoping conversation, codebase investigation, spec written and presented for approval. Nothing written to disk until you say go.

```
/pipeline-run
```
Chains implement → test → review → ship. Verifies the gate after each stage. On failure: typed error, Retry/Override/Halt. PR URL when done. Run `/auto` first: without it Claude Code will prompt for permissions mid-run.

---

## The WorkItem: shared state across every stage

The `Right` value being threaded through the pipeline.

```
Scoping conversation
  → /pipeline-plan writes the WorkItem (spec, acceptance criteria, repo style)
    → Implement appends code decisions and handoff notes
      → Test appends test decisions and handoff notes
        → Review appends gate result
          → Ship appends PR URL
```

- Lives at `<repo-root>/.workitems/workitem-sc-123456.md`
- Survives crashes and session restarts
- `/pipeline-run` always resumes from the first incomplete stage

---

## Gates: the `Either` unwrap between stages

Every stage ends with an explicit result written to the WorkItem:

```
### Gate
FAIL [code]: payment_test.py line 44, AssertionError: expected 422, got 500
```

| Type | Meaning |
|------|---------|
| `[env]` | OOM, missing dependency, network |
| `[code]` | Test failure, lint error, criterion not met |
| `[spec]` | Spec is wrong or infeasible |
| `[pipeline]` | Tooling bug |

On failure: **Retry**, **Override** (recorded permanently), or **Halt**.

---

## The planner: where all the leverage is

In the LLM era, skill shifts here. Less about writing code, more about domain knowledge: edge cases, hidden constraints, integration points, gotchas a fresh agent would never find in the files. Precise criteria and clear scope are now the high-leverage work.

Some default planning stages:

1. **Goal:** what problem are we solving and why?
2. **Acceptance criteria:** specific, testable conditions
3. **Constraints / gotchas:** what would a fresh agent not know?
4. **Out of scope:** what are we explicitly not doing?

Then it reads the codebase: style conventions, test patterns, Make targets. Presents a complete spec for approval before writing anything.

> The quality ceiling is set here. Every downstream stage builds on this document.

---

## Artifacts produced as a side effect of the pipeline

**PR:** the branch is pushed and a pull request is opened, with a description generated from the WorkItem

**Handover doc** (`.handovers/handover-sc-123456.md`)**:** a human-readable summary of the run: what was built, issues encountered, timing, and a QA checklist for the reviewer

**WorkItem** (`.workitems/workitem-sc-123456.md`)**:** an agent-facing document that acts as an audit trail for every decision made across the run, by each agent. Not really intended for human consumption, but it's there if you need it

---

## Getting started

One-time setup:
```bash
git clone <repo>
./pipeline-install.sh
```

Per feature:
```bash
/pipeline-plan username/sc-123456/-my-feature-branch
# scope the work, approve the spec
/pipeline-run
# ~20-30 minutes later: PR URL
```

Requires: Claude Code, `gh` CLI authenticated to GitHub, `jq`, build tooling in your repo (Makefile, `package.json` scripts, etc.)

A `CLAUDE.md` or `AGENTS.md` in your service repo is strongly recommended.

---

## Try it first: `/pipeline-demo`

Before running a real feature through the pipeline, the demo simulates a complete run in any git repo:

```bash
/pipeline-demo
```

No source files are modified, no real tests run, no PR is created. It writes a WorkItem and handover doc to `.workitems/` and `.handovers/`, and updates the status line in real time so you can see each stage progress.

Use `--fail-at` to simulate a failure and see the Retry/Override/Halt flow before encountering it for real:

```bash
/pipeline-demo --fail-at implement   # lint failure in implement stage
/pipeline-demo --fail-at test        # test failure mid-suite
/pipeline-demo --fail-at review      # review catches an unmet acceptance criterion
```

A successful demo run confirms git, the pipeline config, the status bar, and artifact paths are all working. Clean up is prompted at the end (default yes).

---

## Status line

While the pipeline runs, Claude Code's status line shows you what's happening:

```
⚙  Agentic Pipeline: [SC-123456]  |  Agent: [implement]  |  Stage: [1/4]  8m
```

Updates every 3 seconds. Shows the active agent, stage progress, and time elapsed. Reads from a state file written by the pipeline to `<repo-root>/.pipeline-state/`.

Enabled during install. To set it up manually, add this to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "refreshInterval": 3
}
```

---

## Security: where things stand

The pipeline runs with the same permissions as the user who invoked it. That is the right default for now, but worth being explicit about.

**What it can do:**
- Read and write files in the repo
- Run any make target (and whatever that expands to)
- Access every environment variable in your shell
- Push to any git remote your credentials can reach

**The per-stage reality:** implement and test need almost none of this. They write code and run lint. Ship is the only stage that genuinely needs GitHub access.

**Near-term mitigations:**
- Fine-grained GitHub PAT scoped to specific repos (replace broad `gh auth`)
- Run the pipeline from a shell without production credentials exported

**Longer-term direction:**
- Implement and test stages run in a container: no credentials, no git push, filesystem limited to the project directory
- Ship becomes an explicit user-confirmed step, even in auto mode: the pipeline shows you exactly what will be pushed before touching GitHub

The design lends itself to this naturally. The orchestrator owns verification and commits; the stage agents just do their narrow job. Tightening permissions per stage does not require redesigning the architecture.

---

## Getting un-started

Changed your mind? The uninstall script removes everything the install added:

```bash
cd agentic-pipeline && ./pipeline-uninstall.sh
```

This removes all skill files from `~/.claude/commands/`, the status line script, the pipeline config, and the pipeline block from `~/.claude/CLAUDE.md`.

It does not touch any repo-local artifacts (`.workitems/`, `.handovers/`, `.pipeline-state/`). Those are yours to clean up if you want them gone.

---

# Questions?

**TLDR:**

```bash
git clone https://github.com/mau5mat/agentic-pipeline
cd agentic-pipeline && ./pipeline-install.sh
```

Open Claude Code in any service repo, then:

```bash
/pipeline-plan BRANCH
/pipeline-run
```
