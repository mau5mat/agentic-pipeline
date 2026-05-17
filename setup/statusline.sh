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

REPO=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO" ] && exit 0

# Find the running state file for this repo (iterate per-ticket subdirs)
STATE_FILE=""
for dir in "$REPO/.pipeline-state"/*/; do
  f="${dir}pipeline-state.json"
  [ -f "$f" ] || continue
  STATUS=$(jq -r '.status // empty' "$f" 2>/dev/null)
  [ "$STATUS" = "running" ] || continue
  STATE_FILE="$f"
  break
done

[ -z "$STATE_FILE" ] && exit 0

SC=$(jq -r '.sc // empty' "$STATE_FILE" 2>/dev/null)
STAGE=$(jq -r '.stage // empty' "$STATE_FILE" 2>/dev/null)
STAGE_NUM=$(jq -r '.stage_num // empty' "$STATE_FILE" 2>/dev/null)
START_TIME=$(jq -r '.start_time // empty' "$STATE_FILE" 2>/dev/null)

[ -z "$SC" ] && exit 0

# Uppercase ticket and map stage to friendly name
SC_UPPER=$(echo "$SC" | tr '[:lower:]' '[:upper:]')
case "$STAGE" in
  plan)               STAGE_LABEL="Planner" ;;
  plan-scoping)       STAGE_LABEL="Planner: Scoping" ;;
  plan-investigating) STAGE_LABEL="Planner: Investigating" ;;
  orchestrating)      STAGE_LABEL="Orchestrator" ;;
  verifying)          STAGE_LABEL="Orchestrator: Verifying" ;;
  implement)          STAGE_LABEL="Implementor" ;;
  test)               STAGE_LABEL="Tester" ;;
  review)             STAGE_LABEL="Reviewer" ;;
  ship)               STAGE_LABEL="Shipper" ;;
  *)                  STAGE_LABEL="$STAGE" ;;
esac

GREEN='\033[32m'
BOLD_WHITE='\033[1;97m'
DIM='\033[2m'
RESET='\033[0m'

# Stage progress
PROGRESS=""
if [ -n "$STAGE_NUM" ]; then
  PROGRESS="  ${GREEN}|  Stage:${RESET} ${BOLD_WHITE}[${STAGE_NUM}/4]${RESET}"
fi

# Time elapsed
ELAPSED_STR=""
if [ -n "$START_TIME" ]; then
  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [ $ELAPSED -lt 60 ]; then
    TIME_VAL="${ELAPSED}s"
  else
    MINS=$(( ELAPSED / 60 ))
    if [ $MINS -ge 60 ]; then
      TIME_VAL="$(( MINS / 60 ))h $(( MINS % 60 ))m"
    else
      TIME_VAL="${MINS}m"
    fi
  fi
  ELAPSED_STR="  ${DIM}${TIME_VAL}${RESET}"
fi

echo -e "${GREEN}⚙  Agentic Pipeline:${RESET} ${BOLD_WHITE}[${SC_UPPER}]${RESET}  ${GREEN}|  Agent:${RESET} ${BOLD_WHITE}[${STAGE_LABEL}]${RESET}${PROGRESS}${ELAPSED_STR}"
