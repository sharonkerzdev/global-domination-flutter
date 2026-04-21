#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: bash dev-loop.sh item1 item2 item3 ..."
  exit 1
fi

for item in "$@"; do
  echo "=========================================="
  echo "[$(date)] Starting cycle for: $item"
  echo "=========================================="

  echo "[$(date)] Step 1: Creating story ($item)..."
  claude -p "Create the story $item - follow the gds-create-story workflow" --dangerously-skip-permissions --verbose
  echo "[$(date)] Step 2: Developing story ($item)..."
  claude -p "Implement the story $item - follow the gds-dev-story workflow" --dangerously-skip-permissions --verbose
  echo "[$(date)] Step 3: Code review ($item)..."
  claude -p "Run a code review on the latest changes for story $item - follow the gds-code-review workflow" --dangerously-skip-permissions --verbose
  echo "[$(date)] Cycle complete for: $item"
done

echo "=========================================="
echo "[$(date)] All items processed."
