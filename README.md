# Agentic Development Pipeline

A chain of specialist AI agents that takes a feature from spec to PR without manual intervention between stages.

## The problem it solves

Without the pipeline, work is conversational and sequential — you prompt each step individually, context bleeds between stages, and the agent that implemented the code also reviews it. The pipeline formalises this into isolated stages with clean handoffs.

## The two commands

```
/pipeline-plan   — interactive: work out the spec together, write WorkItem (run while on the Shortcut branch)
/pipeline        — automated: implement → test → review → ship, hands you a PR URL when done
```

Expected flow: create the branch from Shortcut first (`git checkout -b mattroberts/sc-XXXXXX/-description`), then invoke `/pipeline-plan` while on that branch. The SC number is read from the branch automatically.

Individual stages can be run standalone if needed:
`/pipeline-implement`, `/pipeline-test`, `/pipeline-review`, `/pipeline-ship`

All skills live in `~/.claude/commands/`.

## What flows between stages

A single WorkItem document at:
`~/Development/Slice/workitems/<service>/workitem-<sc-number>.md`

Each stage reads the full document and appends its section. The document accumulates:
Spec → Implementation + handoff notes → Tests + handoff notes → Review (gate) → Ship (PR URL)

## Installation

Copy the skill files to your Claude commands directory:

```bash
cp commands/*.md ~/.claude/commands/
```

That's it. Invoke `/pipeline-plan` from any service repo to start.

## Repository structure

```
commands/                        ← skill files (copy these to ~/.claude/commands/)
  pipeline.md                    ← orchestrator
  pipeline-plan.md
  pipeline-implement.md
  pipeline-test.md
  pipeline-ship.md
  pipeline-review.md
  pr-description.md              ← dependency of pipeline-ship
design.md                        ← architectural decisions and rationale
workitem-schema.md               ← full WorkItem template with field explanations
gaps-and-roadmap.md              ← known limitations and future improvements
abort-and-recovery.md            ← how to stop, undo, or resume a pipeline run
example-happy-path.md            ← annotated happy-path example (WorkItem + narrative + handover)
example-unhappy-path.md          ← annotated unhappy-path example
findings/                        ← post-run findings from real pipeline sessions
  trial-run-sc-668234-findings.md
```

## Runtime output (stays local, not in this repo)

| Artifact | Location |
|----------|----------|
| WorkItems | `~/Development/Slice/workitems/<service>/workitem-<sc>.md` |
| PR descriptions | `~/Development/Slice/pr-descriptions/<service>/<service>-<sc>.md` |
| Handover docs | `~/Development/Slice/pr-descriptions/<service>/handover-<sc>.md` |
