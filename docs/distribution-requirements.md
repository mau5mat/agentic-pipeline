# Distribution Requirements

What would need to change to make this pipeline a self-contained, shareable package for other people and teams.

---

## What was previously hardcoded

### 1. ~~Hardcoded output paths~~ (resolved 2026-05-15)
WorkItems, handover docs, and pipeline state now live at `<repo-root>/.workitems/`, `<repo-root>/.handovers/`, and `<repo-root>/.pipeline-state/`, all derived from `git rev-parse --show-toplevel`. No personal paths, no config needed. All three directories are gitignored locally and never pushed.

---

### 2. ~~Shortcut as the issue tracker~~ (resolved 2026-05-18)
Ticket prefix, regex, URL template, and label are now read from `~/.claude/pipeline.conf`. Shortcut users answer one question (org slug); other tracker users configure prefix, URL template, and label. The WorkItem tracker field is omitted if no URL is configured.

---

### 3. ~~Hardcoded org-level memory path~~ (resolved 2026-05-18)
`PIPELINE_ORG_MEMORY` is now read from `~/.claude/pipeline.conf`. Optional: empty string if not set. Both `pipeline-plan` and `pipeline-run` use `$ORG_MEMORY` instead of a hardcoded path.

---

### 4. ~~Global `~/.claude/CLAUDE.md`~~ (resolved 2026-05-18)
`pipeline-install.sh` writes a generic pipeline block (between comment markers) to `~/.claude/CLAUDE.md`. Idempotent: re-running the install updates the block without touching surrounding content.

---

### 5. ~~Hardcoded org slug in the Shortcut URL~~ (resolved 2026-05-18)
Covered by #2: tracker URL is fully configurable via `pipeline-install.sh`.

---

### 6. `gh` CLI assumed for PR creation
`pipeline-ship.md` uses `gh pr create` and `gh pr view`. Teams on GitLab, Bitbucket, or Azure DevOps can't use this.

**Fix:** The ship stage command for PR creation and the orchestrator's PR URL verification need to be configurable. Realistically: `gh` covers the vast majority of teams using Claude Code today (GitHub dominant). Could document this as a prerequisite and provide a clear extension point for others. Lowest-friction fix: make the PR creation command a config entry.

---

## `pipeline-install.sh` (shipped 2026-05-18)

Run once at install time. Copies all pipeline skill files to `~/.claude/commands/`, writes `~/.claude/pipeline.conf`, installs the status line script at `~/.claude/statusline.sh`, and adds the pipeline block to `~/.claude/CLAUDE.md`.

Shortcut users answer one question (org slug); other tracker users configure prefix, URL template, and label. Org memory path is optional for both.

WorkItems (`<repo-root>/.workitems/`), handover docs (`<repo-root>/.handovers/`), and pipeline state (`<repo-root>/.pipeline-state/`) are all repo-local by default: no path config needed for those.

`pipeline-uninstall.sh` removes everything the install added: skill files, config, status line script, and the pipeline block from `~/.claude/CLAUDE.md`. Does not touch repo-local artifacts.

`/pipeline-demo` provides a simulated pipeline run useful for demos and new-user setup verification. A successful demo run confirms git, config, status bar, and artifact paths are all working correctly.

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
- All the "why": the design rationale is universal

---

## Prerequisites for any user (document these)

- Claude Code CLI installed
- `git` (obviously)
- `gh` CLI authenticated (for GitHub PR creation: see #6 above)
- `jq` installed (required for `statusline.sh` to parse per-ticket `pipeline-state.json` files)
- A Makefile with lint and test targets, or equivalent (the planner discovers these; it just needs them to exist)
- A repo with CLAUDE.md and/or AGENTS.md for best results (not required, but the pipeline is less useful without repo-specific constraints)

---

## Effort estimate (historical, now complete)

All items below have been resolved. Table retained for reference.

| Item | Effort | Status |
|---|---|---|
| Config file + path parameterisation | Low | Done |
| Generic ticket format (drop Shortcut assumption) | Low-Medium | Done |
| `pipeline-install.sh` setup script | Medium | Done |
| Org-level memory path derivation | Low | Done |
| Global CLAUDE.md snippet approach | Low | Done |
| `gh` abstraction for non-GitHub teams | Medium | Out of scope for v1 |
