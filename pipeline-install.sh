#!/usr/bin/env bash
set -euo pipefail

# pipeline-install.sh: one-time setup for the agentic development pipeline.
# Safe to re-run: updates existing config without touching unrelated settings.

CONF="$HOME/.claude/pipeline.conf"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
COMMANDS_DIR="$HOME/.claude/commands"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}!${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*" >&2; }
bold() { echo -e "\n${BOLD}$*${RESET}"; }

# ── 1. Prerequisites ──────────────────────────────────────────────────────────

bold "Checking prerequisites..."

missing=()
command -v git >/dev/null 2>&1 || missing+=("git")
command -v gh  >/dev/null 2>&1 || missing+=("gh")
command -v jq  >/dev/null 2>&1 || missing+=("jq")

if [ ${#missing[@]} -gt 0 ]; then
  err "Missing required tools: ${missing[*]}"
  echo ""
  for tool in "${missing[@]}"; do
    case "$tool" in
      git) echo "  git: xcode-select --install  (or https://git-scm.com)" ;;
      gh)  echo "  gh : brew install gh  →  gh auth login" ;;
      jq)  echo "  jq : brew install jq" ;;
    esac
  done
  echo ""
  exit 1
fi
ok "git, gh, jq"

# ── 2. Install skill files ────────────────────────────────────────────────────

bold "Installing skill files..."

echo "  The following Claude Code skills will be added to $COMMANDS_DIR:"
echo ""
echo "    /pipeline-plan       : interactive planning: create branch, scope work, write WorkItem"
echo "    /pipeline-run        : orchestrator: chains implement → test → review → ship automatically"
echo "    /pipeline-implement  : implement stage (also runnable standalone)"
echo "    /pipeline-test       : test stage (also runnable standalone)"
echo "    /pipeline-review     : review stage (also runnable standalone)"
echo "    /pipeline-ship       : ship stage: push branch, open PR (also runnable standalone)"
echo "    /pr-description      : generate a PR description from a WorkItem"
echo "    /pr-review-feedback  : apply PR review feedback from a URL"
echo "    /pipeline-demo       : simulated pipeline run with realistic output (good for testing your setup)"
echo ""

mkdir -p "$COMMANDS_DIR"
cp "$SCRIPT_DIR"/commands/*.md "$COMMANDS_DIR/"
ok "Skills copied to $COMMANDS_DIR"

# ── 3. Install status line ────────────────────────────────────────────────────

bold "Installing status line..."

cp "$SCRIPT_DIR/setup/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"
ok "Status line script installed at ~/.claude/statusline.sh"

SETTINGS="$HOME/.claude/settings.json"
STATUSLINE_JSON='{"type":"command","command":"~/.claude/statusline.sh","refreshInterval":3}'
if [ -f "$SETTINGS" ] && grep -q "statusLine" "$SETTINGS" 2>/dev/null; then
  ok "statusLine already in settings.json"
elif [ -f "$SETTINGS" ]; then
  jq --argjson sl "$STATUSLINE_JSON" '. + {statusLine: $sl}' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
  ok "statusLine added to settings.json"
else
  printf '{"statusLine":%s}\n' "$STATUSLINE_JSON" > "$SETTINGS"
  ok "settings.json created with statusLine"
fi

# ── 4. Issue tracker config ───────────────────────────────────────────────────

bold "Issue tracker config"

# Load existing values as defaults
if [ -f "$CONF" ]; then
  # shellcheck source=/dev/null
  source "$CONF"
  echo "  (existing config found: current values shown as defaults)"
fi

echo ""
echo "  1. Shortcut"
echo "  2. Other (Jira, Linear, GitHub Issues, etc.)"
printf "  Choice [1]: "
read -r tracker_choice
tracker_choice="${tracker_choice:-1}"

if [ "$tracker_choice" = "1" ]; then
  current_slug=""
  if [ -n "${PIPELINE_TRACKER_URL_TEMPLATE:-}" ]; then
    current_slug=$(echo "${PIPELINE_TRACKER_URL_TEMPLATE}" | grep -oP '(?<=shortcut\.com/)[^/]+' 2>/dev/null || true)
  fi
  prompt="  Org slug (from app.shortcut.com/YOUR-SLUG)"
  [ -n "$current_slug" ] && prompt="$prompt [$current_slug]"
  printf "%s: " "$prompt"
  read -r slug
  slug="${slug:-$current_slug}"
  [ -z "$slug" ] && { err "Org slug required."; exit 1; }

  SETUP_TICKET_PREFIX="sc"
  SETUP_TICKET_REGEX="sc-[0-9]+"
  SETUP_TRACKER_LABEL="Shortcut"
  SETUP_TRACKER_URL_TEMPLATE="https://app.shortcut.com/${slug}/story/{id}/{slug}"

else
  default_prefix="${PIPELINE_TICKET_PREFIX:-}"
  prompt="  Ticket prefix (e.g. ENG, PROJ)"
  [ -n "$default_prefix" ] && prompt="$prompt [$default_prefix]"
  printf "%s: " "$prompt"
  read -r prefix
  prefix="${prefix:-$default_prefix}"
  [ -z "$prefix" ] && { err "Ticket prefix required."; exit 1; }

  default_url="${PIPELINE_TRACKER_URL_TEMPLATE:-}"
  prompt="  Tracker URL template: use {id} for ticket number (enter to skip)"
  [ -n "$default_url" ] && prompt="$prompt [$default_url]"
  printf "%s: " "$prompt"
  read -r url_template
  url_template="${url_template:-$default_url}"
  [ "$url_template" = "skip" ] && url_template=""

  default_label="${PIPELINE_TRACKER_LABEL:-Tracker}"
  printf "  Tracker label [%s]: " "$default_label"
  read -r label
  label="${label:-$default_label}"

  SETUP_TICKET_PREFIX="$prefix"
  SETUP_TICKET_REGEX="${prefix}-[0-9]+"
  SETUP_TRACKER_LABEL="$label"
  SETUP_TRACKER_URL_TEMPLATE="$url_template"
fi

# ── 5. Org memory (optional) ──────────────────────────────────────────────────

bold "Org memory (optional)"
echo "  A shared ~/.claude/projects/.../memory path with feedback rules that"
echo "  apply across all repos on this machine. Skip if you don't have one."
default_mem="${PIPELINE_ORG_MEMORY:-}"
prompt="  Path (enter to skip)"
[ -n "$default_mem" ] && prompt="$prompt [$default_mem]"
printf "%s: " "$prompt"
read -r org_memory
org_memory="${org_memory:-$default_mem}"
[ "$org_memory" = "skip" ] && org_memory=""

# ── 6. Confirm ────────────────────────────────────────────────────────────────

bold "Summary"
echo "  Tracker:     $SETUP_TRACKER_LABEL"
echo "  Prefix:      $SETUP_TICKET_PREFIX  (regex: $SETUP_TICKET_REGEX)"
echo "  Tracker URL: ${SETUP_TRACKER_URL_TEMPLATE:-none}"
echo "  Org memory:  ${org_memory:-none}"
echo ""
printf "Write config? [Y/n]: "
read -r confirm
confirm="${confirm:-Y}"
[[ ! "$confirm" =~ ^[Yy] ]] && { echo "Aborted."; exit 0; }

# ── 7. Write pipeline.conf ────────────────────────────────────────────────────

mkdir -p "$(dirname "$CONF")"
cat > "$CONF" << EOF
# Pipeline configuration: written by pipeline-install.sh
# Edit manually or re-run pipeline-install.sh to update.
PIPELINE_TICKET_PREFIX="${SETUP_TICKET_PREFIX}"
PIPELINE_TICKET_REGEX="${SETUP_TICKET_REGEX}"
PIPELINE_TRACKER_LABEL="${SETUP_TRACKER_LABEL}"
PIPELINE_TRACKER_URL_TEMPLATE="${SETUP_TRACKER_URL_TEMPLATE}"
PIPELINE_ORG_MEMORY="${org_memory}"
EOF

ok "Config written to $CONF"

# ── 8. Update ~/.claude/CLAUDE.md ─────────────────────────────────────────────

PIPELINE_BLOCK='<!-- pipeline-block-start -->
## Development Pipeline

A set of skills for running features through a structured agent pipeline. Use this for non-trivial work: a feature, bug fix, or migration with clear acceptance criteria.

**Flow:**
1. `/pipeline-plan <branch-name>`: interactive planning session; paste the full branch name from your issue tracker. Creates the branch, produces a WorkItem document (spec, acceptance criteria, files, gotchas, out-of-scope).
2. `/pipeline-run`: orchestrator; automatically chains implement → test → review → ship without further input; hands off a PR URL when done. Also used to resume after a failure: run with no args to continue from the first incomplete stage.

Individual stages can also be run standalone: `/pipeline-implement`, `/pipeline-test`, `/pipeline-review`, `/pipeline-ship`.

**When to suggest it:** Any time the user is about to start a new feature or bug fix. Ask whether they want to use the pipeline rather than diving straight into implementation.

**When it is less useful:** Quick one-off fixes, exploratory spikes, or work that has not been scoped yet.

**What flows between stages:** A WorkItem document at `<repo-root>/.workitems/workitem-<ticket-id>.md`: each stage reads the full document and appends its section. The document accumulates: Spec -> Implementation + handoff notes -> Tests + handoff notes -> Review (gate) -> Ship (PR URL).
<!-- pipeline-block-end -->'

if [ ! -f "$CLAUDE_MD" ]; then
  printf "# Global Agent Context\n\n%s\n" "$PIPELINE_BLOCK" > "$CLAUDE_MD"
elif grep -q "<!-- pipeline-block-start -->" "$CLAUDE_MD"; then
  python3 - "$CLAUDE_MD" << PYEOF
import re, sys
path = sys.argv[1]
block = """$PIPELINE_BLOCK"""
content = open(path).read()
content = re.sub(
    r'<!-- pipeline-block-start -->.*?<!-- pipeline-block-end -->',
    block, content, flags=re.DOTALL
)
open(path, 'w').write(content)
PYEOF
else
  printf "\n%s\n" "$PIPELINE_BLOCK" >> "$CLAUDE_MD"
fi

ok "Pipeline block updated in $CLAUDE_MD"

# ── 9. Global gitignore reminder ──────────────────────────────────────────────

bold "Global gitignore"
if grep -q "\.workitems" "${HOME}/.gitignore_global" 2>/dev/null; then
  ok "Pipeline dirs already in ~/.gitignore_global"
else
  echo "  Pipeline artifact directories should be excluded from git."
  echo "  Run the following to add them:"
  echo ""
  echo "    echo '.workitems/'      >> ~/.gitignore_global"
  echo "    echo '.handovers/'      >> ~/.gitignore_global"
  echo "    echo '.pipeline-state/' >> ~/.gitignore_global"
  echo "    git config --global core.excludesfile ~/.gitignore_global"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Setup complete.${RESET}"
echo ""
echo "  Config:    $CONF"
echo "  CLAUDE.md: $CLAUDE_MD"
echo "  Skills:    $COMMANDS_DIR"
echo ""
echo "Open Claude Code in any service repo and run:"
echo "  /pipeline-plan <branch-name>"
echo ""
