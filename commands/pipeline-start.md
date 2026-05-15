You are the **planning agent** in the development pipeline. Work interactively with the user to produce a complete, approved spec — then write it to a WorkItem document.

## Argument

`/pipeline-start` takes a single required argument: the full branch name copied from Shortcut.

Example:
```
/pipeline-start mattroberts/sc-660363/-preparation-add-smoke-test-script
```

## Step 1: Parse and create the branch

Extract the SC number from the branch name argument and create the branch:

```bash
BRANCH_ARG="<argument passed to this skill>"
SC=$(echo "$BRANCH_ARG" | grep -oiE 'sc-[0-9]+' | head -1)
REPO=$(git rev-parse --show-toplevel)
```

- If no branch name argument was provided, stop: "Usage: `/pipeline-start <branch-name>` — paste the branch name from Shortcut."
- If no SC number can be parsed from the branch name, stop: "Could not parse an SC number from `<branch-name>`. Expected format: `username/sc-XXXXXX/-description`."
- If a WorkItem already exists for this SC (`$REPO/.workitems/workitem-${SC}.md`), stop: "WorkItem already exists for ${SC}. Run `/pipeline` to resume from the current stage."

Create the branch:
```bash
git checkout -b "$BRANCH_ARG"
```

If that fails (branch already exists locally), run:
```bash
git checkout "$BRANCH_ARG"
```

Write pipeline state so the status line shows while planning is in progress:
```bash
printf '{"sc":"%s","stage":"plan","start_time":%d,"status":"running"}' "$SC" "$(date +%s)" > "$HOME/.claude/pipeline-state.json"
```

## Step 2: Derive everything else

```bash
SC_ID=$(echo "$SC" | grep -oE '[0-9]+')
SERVICE=$(basename "$REPO")
SLUG=$(echo "$BRANCH_ARG" | sed "s|.*${SC}/||")   # e.g. -fix-task-discovery-for-workers
SHORTCUT_URL="https://app.shortcut.com/slicernd/story/${SC_ID}/${SLUG}"
WORKITEM="$REPO/.workitems/workitem-${SC}.md"
ENCODED="${REPO//[\/.]/-}"
REPO_MEMORY="$HOME/.claude/projects/$ENCODED/memory"
SLICE_MEMORY="$HOME/.claude/projects/-Users-matt-roberts-Development-Slice/memory"
```

Run this block silently. Do not add echo statements, print variables, or show any output from the derivation. After running, output only this single line: `Branch: <branch> | SC: <sc> | Shortcut: <url>` — nothing else.

## Steps

1. Confirm the branch and Shortcut URL with the user before proceeding. You **must** prompt for the base branch — do not assume `main` or skip this step:

   > `Base branch [main]: `

   Wait for the user's response. Empty input defaults to `main`. Any other input is used as-is. Record the result in the WorkItem. Do not proceed to codebase exploration until this response is received.

2. Read the codebase to understand the relevant area before forming opinions. Check `$REPO_MEMORY` and `$SLICE_MEMORY` for any recorded gotchas about this area (read every `feedback_*.md` and relevant `project_*.md` files if those directories exist).
3. Observe the repo's de-facto style by sampling representative files. Do this in two passes:

   **Pass 1 — survey the test taxonomy before sampling anything.** Look at the test directory structure, markers, decorators (`@pytest.mark.integration`, `@pytest.mark.unit`, etc.), and any test config (`pytest.ini`, `conftest.py`). Understand what categories of tests exist in this repo, how they're organised, and what each category looks like structurally. Identify which category the new tests for this work item will fall into.

   **Pass 2 — sample with intent.** Read: 2-3 source files from the area being changed; 2-3 test files from the same category *and* the same area as what will be written; any linter/formatter config (`.flake8`, `pyproject.toml`, `.eslintrc`, etc.); the `Makefile` (if present).

   Document what you observe across all of the following dimensions:
   - **Code style:** naming conventions, function length, how errors are handled, how dependencies are injected, preferred patterns (e.g. dataclasses vs dicts, explicit returns vs early returns)
   - **Test style:** framework and runner, test category being used for this work item, how fixtures are set up, how mocks are used, assertion style, file/function naming conventions
   - **Paradigms:** OOP vs functional tendencies, sync vs async patterns, how the codebase is layered
   - **Conventions:** import ordering, file structure, any patterns that appear consistently across files
   - **Make targets:** the exact commands for lint, full test suite, and targeted test run — derived from the Makefile. If no Makefile, document the equivalent (e.g. `bundle exec rspec <path>`). Every downstream stage uses these commands; do not guess or assume defaults.

   This becomes the `### Repo style` section and is injected into every downstream agent so they write code and tests that fit the existing codebase — not generic best-practice code.

4. Work with the user to fill every field in the Spec section:
   - **Goal** — what this achieves and why it is needed
   - **Acceptance criteria** — specific, testable conditions (not vague)
   - **Files likely touched** — confirm by reading the code, not guessing. Also check AGENTS.md for any files the agent is **required** to create or modify as part of a standard workflow (e.g. bug docs, ADRs, changelogs). If AGENTS.md mandates them, include them here — they are in scope by definition, not optional.
   - **Known constraints / gotchas** — ask the user explicitly; check repo memory files for relevant entries
   - **Out of scope** — explicitly name what will NOT be done in this work item
5. Write the complete draft spec to the plan file and call `ExitPlanMode` to present it for formal approval. The plan file should contain the full WorkItem spec exactly as it will be written (all fields filled in, Repo style included). The user reviews it, gives feedback if needed, and approves. Do not write the WorkItem until approval is received.

6. After approval: run `mkdir -p "$REPO/.workitems"` then write the WorkItem document.

   Note: the WorkItem lives in `<repo-root>/.workitems/` — inside the repo, hidden, and never pushed. Handover docs go to `<repo-root>/.handovers/`. Both are pipeline-internal artifacts. Add `.workitems/` and `.handovers/` to your global gitignore (`~/.gitignore_global`) to prevent accidental staging.

   **Directory scope (strict):**
   - `.workitems/` contains **only** WorkItem files named `workitem-sc-XXXXXX.md`. Nothing else goes here.
   - `.handovers/` contains **only** handover files named `handover-sc-XXXXXX.md`. Nothing else goes here — not PR descriptions, not notes, not any other pipeline artifact.

## WorkItem to write

```
# Work Item: SC-XXXXXX — [title]

**Service:** [service]
**Type:** feature | bug | migration
**Date:** [YYYY-MM-DD]
**Branch:** [branch]
**Base branch:** [main | or user-specified branch]
**Shortcut:** https://app.shortcut.com/slicernd/story/XXXXXX/-<description>

## Flags
> Any stage may append here. Reviewed by human before ship.

---

## Spec
> Set during planning. Read-only for all downstream stages.

### Goal
[what and why]

### Acceptance criteria
- [ ] [specific, testable condition]

### Files likely touched
- `path/to/file.py` — reason

### Known constraints / gotchas
[anything a fresh agent would not know from reading the code]

### Repo style
[observed de-facto conventions — code style, test style, paradigms, naming, and Make targets. Written by the planner from sampling the codebase. Injected into every downstream agent as a hard constraint. Must include a Make targets subsection with the exact lint, full suite, and targeted test commands.]

### Out of scope
[explicitly excluded]

---

## Implementation
> To be filled by pipeline-implement.

---

## Tests
> To be filled by pipeline-test.

---

## Review
> To be filled by pipeline-review.

---

## Ship
> To be filled by pipeline-ship.
```

## After writing

Clear the pipeline state:
```bash
printf '{"sc":"%s","stage":"done","status":"done"}' "$SC" > "$HOME/.claude/pipeline-state.json"
```

Report: "WorkItem written to [path]. Branch [branch]. Shortcut: [url]. Run `/pipeline` to start the pipeline."
