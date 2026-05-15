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

# Uppercase ticket and map stage to friendly name
SC_UPPER=$(echo "$SC" | tr '[:lower:]' '[:upper:]')
case "$STAGE" in
  implement) STAGE_LABEL="Implement" ;;
  test)      STAGE_LABEL="Test" ;;
  review)    STAGE_LABEL="Review" ;;
  ship)      STAGE_LABEL="Ship" ;;
  plan)      STAGE_LABEL="Plan" ;;
  *)         STAGE_LABEL="$STAGE" ;;
esac

GREEN='\033[32m'
BOLD_WHITE='\033[1;97m'
RESET='\033[0m'

echo -e "──  ${GREEN}Agentic Pipeline:${RESET} ${BOLD_WHITE}[${SC_UPPER}]${RESET}  ${GREEN}|  Agent:${RESET} ${BOLD_WHITE}[${STAGE_LABEL}]${RESET}"
