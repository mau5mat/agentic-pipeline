You are the **pipeline setup agent**. Configure the agentic pipeline for this machine.

## What this does

Writes `~/.claude/pipeline.conf` with your issue tracker and team memory settings. All pipeline skills source this file at startup — run this once per machine and the pipeline works in any repo.

Running this again updates the existing config.

## Step 1: Check for existing config

```bash
CONF="$HOME/.claude/pipeline.conf"
if [ -f "$CONF" ]; then
  source "$CONF"
fi
```

If an existing config was found, note the current values — you will use them as defaults in the prompts below.

## Step 2: Gather configuration

Ask each question in turn. Wait for a response before moving to the next.

---

### 2a — Issue tracker

Ask:

> "Which issue tracker do you use?
>
> 1. Shortcut
> 2. Other (Jira, Linear, GitHub Issues, etc.)"

**If the user chooses Shortcut:**

Ask:

> "What's your Shortcut org slug? This is the part after `app.shortcut.com/` in your Shortcut URLs.
>
> For example: `https://app.shortcut.com/slicernd` → slug is `slicernd`
>
> Org slug${PIPELINE_TRACKER_URL_TEMPLATE:+ [current: $(echo "$PIPELINE_TRACKER_URL_TEMPLATE" | grep -oP '(?<=shortcut\.com/)[^/]+')]}:"

Wait for the slug. Then set:

```bash
SETUP_TICKET_PREFIX="sc"
SETUP_TICKET_REGEX="sc-[0-9]+"
SETUP_TRACKER_LABEL="Shortcut"
SETUP_TRACKER_URL_TEMPLATE="https://app.shortcut.com/${SLUG}/story/{id}/{slug}"
```

Where `${SLUG}` is the org slug the user provided.

---

**If the user chooses Other:**

Ask three questions:

> "What ticket prefix does your issue tracker use — the letters before the number in your ticket IDs.
>
> Examples: `ENG` (Jira/Linear → `ENG-1234`), `PROJ` (Jira → `PROJ-456`)
>
> Prefix${PIPELINE_TICKET_PREFIX:+ [$PIPELINE_TICKET_PREFIX]}:"

> "What's your tracker's URL format? Use `{id}` for the ticket number and `{slug}` for the branch description part. Press enter to skip — ticket links will be omitted from WorkItems.
>
> Examples:
> - Jira: `https://mycompany.atlassian.net/browse/{id}`
> - Linear: `https://linear.app/myteam/issue/{id}`
>
> URL template${PIPELINE_TRACKER_URL_TEMPLATE:+ [$PIPELINE_TRACKER_URL_TEMPLATE]}:"

> "What label should appear next to the tracker link in the WorkItem? Press enter for `Tracker`.
>
> Examples: `Jira`, `Linear`, `Tracker`
>
> Label${PIPELINE_TRACKER_LABEL:+ [$PIPELINE_TRACKER_LABEL]}:"

Then set:

```bash
SETUP_TICKET_PREFIX="<user's prefix>"
SETUP_TICKET_REGEX="${SETUP_TICKET_PREFIX}-[0-9]+"
SETUP_TRACKER_LABEL="<user's label or 'Tracker'>"
SETUP_TRACKER_URL_TEMPLATE="<user's URL or empty>"
```

---

### 2b — Org memory (optional, both paths)

Ask:

> "Do you have a shared team memory directory? This is a `~/.claude/projects/.../memory` path shared across your team with feedback rules that apply to all repos. Most users skip this — press enter to skip.
>
> Org memory path${PIPELINE_ORG_MEMORY:+ [$PIPELINE_ORG_MEMORY]}:"

Record the path, or empty string if skipped.

---

## Step 3: Confirm

Call `EnterPlanMode`. Write the following confirmation summary as the plan:

```
Pipeline configuration to write to ~/.claude/pipeline.conf:

  Tracker:      <Shortcut | Other>
  Prefix:       <value>  (branch ticket regex: <prefix>-[0-9]+)
  Tracker URL:  <url template or 'none — ticket links omitted'>
  Label:        <value or 'none'>
  Org memory:   <path or 'none'>
```

Call `ExitPlanMode` to present it for approval. Wait for the user to approve before continuing.

---

## Step 4: Write config

Write `~/.claude/pipeline.conf`:

```bash
cat > "$HOME/.claude/pipeline.conf" << 'EOF'
# Pipeline configuration — written by /pipeline-setup
# Edit manually or re-run /pipeline-setup to update.
PIPELINE_TICKET_PREFIX="<value>"
PIPELINE_TICKET_REGEX="<value>"
PIPELINE_TRACKER_LABEL="<value>"
PIPELINE_TRACKER_URL_TEMPLATE="<value>"
PIPELINE_ORG_MEMORY="<value>"
EOF
```

Fill in the values from Step 2. Use empty string (`""`) for any optional field the user skipped.

---

## Step 5: Update ~/.claude/CLAUDE.md

This file tells Claude Code about the pipeline. Update the pipeline block — or create the file if it doesn't exist.

**Read** `~/.claude/CLAUDE.md` if it exists.

- If it contains `<!-- pipeline-block-start -->`, **replace** everything between `<!-- pipeline-block-start -->` and `<!-- pipeline-block-end -->` (inclusive) with the block below.
- If it does not contain that marker, **append** the block below to the end of the file.
- If the file does not exist, **create** it containing only the block below.

Pipeline block to write:

```
<!-- pipeline-block-start -->
## Development Pipeline

A set of skills for running features through a structured agent pipeline. Use this for non-trivial work — a feature, bug fix, or migration with clear acceptance criteria.

**Flow:**
1. `/pipeline-plan <branch-name>` — interactive planning session; paste the full branch name from your issue tracker. Creates the branch, produces a WorkItem document (spec, acceptance criteria, files, gotchas, out-of-scope).
2. `/pipeline-run` — orchestrator; automatically chains implement → test → review → ship without further input; hands off a PR URL when done. Also used to resume after a failure — run with no args to continue from the first incomplete stage.

Individual stages can also be run standalone: `/pipeline-implement`, `/pipeline-test`, `/pipeline-review`, `/pipeline-ship`.

**When to suggest it:** Any time the user is about to start a new feature or bug fix. Ask whether they want to use the pipeline rather than diving straight into implementation.

**When it's less useful:** Quick one-off fixes, exploratory spikes, or work that hasn't been scoped yet.

**What flows between stages:** A WorkItem document at `<repo-root>/.workitems/workitem-<ticket-id>.md` — each stage reads the full document and appends its section. The document accumulates: Spec → Implementation + handoff notes → Tests + handoff notes → Review (gate) → Ship (PR URL).
<!-- pipeline-block-end -->
```

---

## Step 6: Report

Print:

```
Setup complete.

Config:    ~/.claude/pipeline.conf
CLAUDE.md: ~/.claude/CLAUDE.md (pipeline block updated)

Run /pipeline-plan <branch-name> in any service repo to start.
```
