#!/usr/bin/env bash
set -euo pipefail

# pipeline-uninstall.sh — remove the agentic development pipeline from this machine.
# Does not touch repo-local artifacts (.workitems, .handovers, .pipeline-state) —
# those belong to individual service repos and are your responsibility to clean up.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}!${RESET} $*"; }
bold() { echo -e "\n${BOLD}$*${RESET}"; }

COMMANDS_DIR="$HOME/.claude/commands"
CONF="$HOME/.claude/pipeline.conf"
STATUSLINE="$HOME/.claude/statusline.sh"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

bold "This will remove:"
echo "  - Pipeline skill files from $COMMANDS_DIR"
echo "  - $CONF"
echo "  - $STATUSLINE"
echo "  - Pipeline block from $CLAUDE_MD"
echo ""
echo "  Repo-local artifacts (.workitems/, .handovers/, .pipeline-state/) are NOT"
echo "  touched — clean those up manually in each service repo if needed."
echo ""
printf "Continue? [y/N]: "
read -r confirm
[[ ! "$confirm" =~ ^[Yy] ]] && { echo "Aborted."; exit 0; }

# ── Skill files ───────────────────────────────────────────────────────────────

bold "Removing skill files..."

skills=(
  pipeline-plan.md
  pipeline-run.md
  pipeline-implement.md
  pipeline-test.md
  pipeline-review.md
  pipeline-ship.md
  pipeline-setup.md
  pipeline-demo.md
  pr-description.md
  pr-review-feedback.md
)

for skill in "${skills[@]}"; do
  target="$COMMANDS_DIR/$skill"
  if [ -f "$target" ]; then
    rm "$target"
    ok "Removed $target"
  fi
done

# ── Config ────────────────────────────────────────────────────────────────────

bold "Removing config..."

if [ -f "$CONF" ]; then
  rm "$CONF"
  ok "Removed $CONF"
else
  warn "$CONF not found — skipping"
fi

# ── Status line ───────────────────────────────────────────────────────────────

bold "Removing status line..."

if [ -f "$STATUSLINE" ]; then
  rm "$STATUSLINE"
  ok "Removed $STATUSLINE"
else
  warn "$STATUSLINE not found — skipping"
fi

warn "If you added a statusLine entry to ~/.claude/settings.json, remove it manually."

# ── CLAUDE.md pipeline block ──────────────────────────────────────────────────

bold "Removing pipeline block from CLAUDE.md..."

if [ -f "$CLAUDE_MD" ] && grep -q "<!-- pipeline-block-start -->" "$CLAUDE_MD"; then
  python3 - "$CLAUDE_MD" << 'PYEOF'
import re, sys
path = sys.argv[1]
content = open(path).read()
content = re.sub(
    r'\n?<!-- pipeline-block-start -->.*?<!-- pipeline-block-end -->\n?',
    '', content, flags=re.DOTALL
)
open(path, 'w').write(content)
PYEOF
  ok "Pipeline block removed from $CLAUDE_MD"
else
  warn "$CLAUDE_MD has no pipeline block — skipping"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Uninstall complete.${RESET}"
echo ""
