# Distribution Requirements

What would need to change to make this pipeline a self-contained, shareable package for other people and teams.

---

## What is currently Slice/Matt-specific

### 1. ~~Hardcoded output paths~~ — resolved 2026-05-15
WorkItems and handover docs now live at `<repo-root>/.workitems/` and `<repo-root>/.handovers/` — derived from `git rev-parse --show-toplevel`. No personal paths, no config needed. Both directories are gitignored locally and never pushed.

---

### 2. Shortcut as the issue tracker
Several things assume Shortcut:
- Ticket format: `sc-XXXXXX` — extracted by `grep -oiE 'sc-[0-9]+'`
- Branch convention: `<username>/sc-XXXXXX/-description`
- Shortcut URL: `https://app.shortcut.com/slicernd/story/${SC_ID}/${SLUG}`
- WorkItem header field: `**Shortcut:**`

Other teams use Jira (`PROJ-1234`), Linear (`ENG-456`), GitHub Issues (`#789`), etc. — each with different URL formats and ticket prefixes.

**Fix:** Config entries for ticket prefix pattern, branch extraction regex, and tracker URL template. The WorkItem header field becomes `**Ticket:**` generically. Planner derives the URL from the template. A reasonable default: if no tracker is configured, ticket field is omitted.

---

### 3. Hardcoded org-level memory path
`pipeline.md` and `pipeline-start.md` reference:
```bash
SLICE_MEMORY="$HOME/.claude/projects/-Users-matt-roberts-Development-Slice/memory"
```
This is doubly specific — it encodes both the username (`matt.roberts`) and the org (`Slice`). Anyone else running this gets an empty SLICE_MEMORY on every run.

**Fix:** Config entry for an optional `PIPELINE_ORG_MEMORY` path, or derive it automatically from the parent directory of the repo (the same encoding logic Claude Code uses). Or simply make org-level memory optional and document that it's a shared team memory dir if teams want one.

---

### 4. Global `~/.claude/CLAUDE.md`
Currently references Slice by name and the Slice-specific WorkItem path. Anyone installing the pipeline globally would need to edit this file manually, which is fragile.

**Fix:** The pipeline shouldn't require edits to the user's global CLAUDE.md. Instead, ship a snippet they can append, or have the setup skill write it. Better still: make the pipeline discoverable without needing CLAUDE.md at all — the `/pipeline-start` skill is self-contained once installed.

---

### 5. `slicernd` in the Shortcut URL
`SHORTCUT_URL="https://app.shortcut.com/slicernd/story/..."` — `slicernd` is the Slice org slug.

**Fix:** Covered by #2 above — tracker URL is configurable.

---

### 6. `gh` CLI assumed for PR creation
`pipeline-ship.md` uses `gh pr create` and `gh pr view`. Teams on GitLab, Bitbucket, or Azure DevOps can't use this.

**Fix:** The ship stage command for PR creation and the orchestrator's PR URL verification need to be configurable. Realistically: `gh` covers the vast majority of teams using Claude Code today (GitHub dominant). Could document this as a prerequisite and provide a clear extension point for others. Lowest-friction fix: make the PR creation command a config entry.

---

## What a setup skill would look like

A `/pipeline-setup` skill run once at install time that asks:

1. Where should WorkItems be stored? (default: `~/Development/workitems`)
2. Where should handover docs and PR descriptions go? (default: `~/Development/pr-descriptions`)
3. What issue tracker do you use? (Shortcut / Jira / Linear / GitHub Issues / none)
4. What is your ticket prefix? (e.g. `sc`, `ENG`, `PROJ`)
5. What is your tracker URL template? (e.g. `https://app.shortcut.com/myorg/story/{id}`)
6. Do you have an org-level memory directory? (optional — path to a shared `~/.claude/projects/.../memory` dir)

Then writes `~/.claude/pipeline.conf` and appends the pipeline summary to `~/.claude/CLAUDE.md`.

---

## What is already portable (no changes needed)

- The Either gate mechanism and triage logic
- The WorkItem schema (minus paths and tracker field)
- Context injection (CLAUDE.md/AGENTS.md/feedback rules/Repo Style)
- Makefile target discovery during planning
- Post-stage orchestrator verification logic
- Stage ownership boundaries (implement owns source, test owns tests)
- Handover document format
- Retry detection and conventional commits
- Abort and recovery docs
- All the "why" — the design rationale is universal

---

## Prerequisites for any user (document these)

- Claude Code CLI installed
- `git` (obviously)
- `gh` CLI authenticated (for GitHub PR creation — see #6 above)
- A Makefile with lint and test targets, or equivalent (the planner discovers these — it just needs them to exist)
- A repo with CLAUDE.md and/or AGENTS.md for best results (not required, but the pipeline is less useful without repo-specific constraints)

---

## Effort estimate

| Item | Effort |
|---|---|
| Config file + path parameterisation | Low — mechanical find/replace in skill files |
| Generic ticket format (drop Shortcut assumption) | Low-Medium — regex and URL template |
| `/pipeline-setup` skill | Medium — interactive, writes config |
| Org-level memory path derivation | Low |
| Global CLAUDE.md snippet approach | Low |
| `gh` abstraction for non-GitHub teams | Medium — probably out of scope for v1 |

A distributable v1 could reasonably be: config file + path parameterisation + generic ticket format + setup instructions. That covers ~90% of teams without building a setup skill. The setup skill is a nice-to-have for polish.
