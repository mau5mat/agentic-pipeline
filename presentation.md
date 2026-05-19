---
marp: true
theme: catppuccin
paginate: true
---

# Agentic Development Pipeline
### How I think about rigour™ in an LLM-assisted workflow

---

## My problem with ad-hoc prompting

Every session is different. You might remember to ask for tests this time, forget the acceptance criteria next time, skip the review entirely when you are in a hurry. Quality becomes a function of what you happened to think of that day.

No structure, no separation of concerns. The same agent that wrote the code reviews it. The model is judge and jury. With this pipeline, it still is... but now it also has to take the stand.

This is an attempt to encode good prompting decisions, reliably each time.

---

## This is opinionated software built for one person

Ad hoc prompting didn't suit my brain. I find it hard to keep track of things across a long unstructured session, and this became exponentially harder for parallel work too.

Different people have found ways of working with these tools that suit them, this is my humble attempt at creating something that suits me :)

I wanted structure I could pick back up from. Scoped work, clean handoffs, standardised artifacts at every stage, separation of concerns. This doesn't suit every kind of development work, but for the right kind of task I think it fits fairly well.

**If you thrive in chaos, this is probably not for you. That is fine.**

---

## The mental model

I kept coming back to a functional style framing:

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
Each stage returns `Right WorkItem` to continue, or `Left FailReason` to stop.

**This became a sort of heuristic for the whole design.**

---

## How it maps to practice

- **Plan:** scoping conversation, codebase investigation, writes the WorkItem spec
- **Orchestrator:** manages the run, injects context, runs baseline tests, independently verifies each gate, handles failures
- **Implement:** reads the WorkItem, writes code, runs lint
- **Test:** reads implementation notes, writes tests
- **Review:** fresh-eyes pass against every acceptance criterion
- **Ship:** pushes branch, opens the PR

Each stage agent starts completely fresh, with no memory of prior stages. The agent that wrote the code does not review it.

In practice: the review stage has caught regressions the implement agent introduced and stopped the pipeline before a bad PR was opened.

---

## The WorkItem: the `Right` value being threaded through

```
Scoping conversation
  → plan writes the WorkItem (spec, acceptance criteria, repo style)
    → Implement appends code decisions and handoff notes
      → Test appends test decisions and handoff notes
        → Review appends gate result
          → Ship appends PR URL
```

- Lives at `<repo-root>/.workitems/workitem-sc-123456.md`
- Each fresh agent reads the full document: the whole history of the run in one file
- Survives crashes and session restarts
- The pipeline always resumes from the first incomplete stage

---

## Gates: handling `Left FailReason`

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

On failure: **Retry**, **Override** (recorded permanently in the WorkItem), or **Halt**.

---

## Artifacts

**WorkItem** (`.workitems/workitem-sc-123456.md`)**:** the agent-facing audit trail. Every decision made, every issue raised or self-resolved, every handoff note, all in one file. Not really intended for human consumption, but it is there if you need to understand why something happened

**Handover doc** (`.handovers/handover-sc-123456.md`)**:** a human-readable summary written by the orchestrator at the end of the run: what was built, acceptance criteria checked off, issues encountered, timing across every stage, and a QA checklist for whoever reviews the PR

**Pipeline state** (`.pipeline-state/sc-123456/pipeline-state.json`)**:** a small JSON file written by the orchestrator at each stage transition. the agentic pipeline's status bar reads it in real time to show active stage, progress, and elapsed time inside the session

```
⚙  Agentic Pipeline: [SC-123456]  |  Agent: [implement]  |  Stage: [1/4]  8m
```

---

## The planner: where the leverage actually is

In an LLM-assisted workflow, skill shifts here. It's now less about writing code, more about domain knowledge: edge cases, hidden constraints, integration points, etc.

These are some simple questions baked into the planning phase:

1. **Goal:** what problem are we solving and why?
2. **Acceptance criteria:** specific, testable conditions
3. **Constraints / gotchas:** what would a fresh agent not know?
4. **Out of scope:** what are we explicitly not doing?

Then it reads the codebase: style conventions, test patterns, make targets. Presents a complete spec for approval before writing anything to disk.

> The quality ceiling is set here. Every downstream stage builds on this document.

---

## Where this sits and where it is going

Building this uncovered a few interesting design problems that are not tied to code generation at all, but in verification of output. How can anyone trust output that wasn't written by themselves?

This project is perhaps a feeble attempt to address that question. By trying to add some structure and rigour to the process (whatever that now means in this new age), I can at least feel that I am trending in a better direction than before.

Some things I am still thinking about:

- **Security:** the pipeline runs with the same permissions as the user. Most stages do not need GitHub access at all. Containerisation (Docker, sbx) per stage and explicit user confirmation before anything is pushed feels like the right direction.

Not sure if this resonates with anyone else, but it was worth thinking through the design either way :)
