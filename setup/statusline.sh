#!/bin/bash
# Pipeline status line script for Claude Code
#
# Installation:
#   cp setup/statusline.sh ~/.claude/statusline.sh
#   chmod +x ~/.claude/statusline.sh
#
# Then add to ~/.claude/settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/statusline.sh",
#     "refreshInterval": 3
#   }

input=$(cat)  # Reads JSON session data from Claude Code on stdin

STATE_FILE="$HOME/.claude/pipeline-state.json"

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

SC=$(jq -r '.sc // empty' "$STATE_FILE" 2>/dev/null)
STAGE=$(jq -r '.stage // empty' "$STATE_FILE" 2>/dev/null)
STATUS=$(jq -r '.status // empty' "$STATE_FILE" 2>/dev/null)

if [ -z "$SC" ] || [ "$STATUS" = "done" ]; then
  exit 0
fi

CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'

echo -e "${CYAN}▶ Pipeline${RESET} ${SC} ${YELLOW}→ ${STAGE}${RESET}"
