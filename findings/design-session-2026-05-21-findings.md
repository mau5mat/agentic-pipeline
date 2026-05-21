# Pipeline Design Session Findings: 2026-05-21

Distribution polish session. Reviewed the install wizard for portability, then fixed two issues surfaced by a real user trial of the install flow. All items were fixed within the session.

---

## Issues Fixed

### 1. Installation section in getting-started.md was too sparse to be useful

**Gap:** The installation section contained two sentences: "run `./pipeline-install.sh`" and "this checks prerequisites, installs skill files, sets up the status line, and walks you through tracker configuration." A new user had no way to know what questions the wizard would ask, what to have ready (tracker URL, org slug), or what steps — if any — required manual action after the script finished.

**Fix:** Replaced the two-sentence description with a numbered walkthrough of all nine wizard steps, noting what each one does and what the user needs to provide. Explicitly calls out that `~/.gitignore_global` is the one remaining manual step, and what commands to run.

**Files:** `getting-started.md`

---

### 2. statusLine not auto-configured: user pasted full JSON block, got malformed settings.json

**Gap:** The install script printed a JSON snippet for the user to add to `~/.claude/settings.json`. The printed block included outer `{}` braces. A user with an existing `settings.json` pasted the full block, creating `{{...}...}` — invalid JSON they had to fix manually before Claude Code would start. Even after fixing it, the user ran the demo without having done the step at all and only noticed the status bar was absent mid-demo.

**Reasoning:** `jq` is already a required prerequisite for the status line at runtime. Using it during install to merge the entry removes the manual step entirely and eliminates the paste-error class of failure. Three cases: file doesn't exist (create it), file exists without the entry (merge with `jq '. + {statusLine: $sl}'`), entry already present (skip silently). The merge preserves all existing keys.

The uninstall script had the matching gap: it printed a manual instruction ("if you added a statusLine entry, remove it manually"). Updated to auto-remove with `jq 'del(.statusLine)'`, with a fallback warn if `jq` is absent.

**Fix:** `pipeline-install.sh` section 3 now uses `jq` to auto-merge; `pipeline-uninstall.sh` uses `jq del` to auto-remove. `getting-started.md` step 3 updated to say "automatically adds"; closing paragraph reduced from two manual steps to one (gitignore only). `docs/distribution-requirements.md` updated to reflect the settings.json changes in both install and uninstall descriptions.

**Files:** `pipeline-install.sh`, `pipeline-uninstall.sh`, `getting-started.md`, `docs/distribution-requirements.md`

---

### 3. Demo hard-stopped on restart after mid-run cancellation

**Gap:** A user noticed the status bar wasn't updating during the demo (because the statusLine step hadn't been done — see finding #2). They cancelled the demo mid-run to fix it, then tried to restart. The demo hard-stopped: "Demo WorkItem already exists at `$WORKITEM`. Remove it first: `rm $WORKITEM`". The EXIT trap only cleaned `pipeline-state`: the WorkItem, handover doc, and demo branch were left behind. The user had to manually identify and remove three artifacts before they could restart.

**Two fixes applied:**

**A. Wipe-and-restart prompt:** when a WorkItem is found at startup, instead of stopping with a manual instruction, offer: "A previous demo run was found (may be incomplete). Wipe it and start fresh? [Y/n]". Default Y. If confirmed: delete WorkItem, handover doc, and demo branch (branch deletion uses `|| true` so it's silent if the branch doesn't exist), then continue to the normal "Type 'go'" prompt.

**B. statusLine warning before start:** check whether `~/.claude/settings.json` has a `statusLine` entry before the "Type 'go'" prompt. If not, print a non-blocking warning: "statusLine is not configured — the stage indicator will not update during this demo. Re-run `./pipeline-install.sh` to add it." Doesn't block the demo: the user can still run it, but they know upfront rather than noticing mid-run.

**Files:** `commands/pipeline-demo.md`

---

## Summary

| Item | Source | Status |
|------|--------|--------|
| Installation wizard docs too sparse | Identified in session | Fixed |
| statusLine manual paste error + missing auto-config | Real user trial | Fixed |
| Demo hard-stop on restart after cancellation | Real user trial | Fixed |
| statusLine absent mid-demo with no warning | Real user trial | Fixed (B above) |
