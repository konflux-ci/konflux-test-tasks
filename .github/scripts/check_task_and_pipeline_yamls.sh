#!/bin/bash

# copied from .github/workflows/check-task-and-pipeline-yamls.yaml of https://github.com/konflux-ci/build-definitions
shopt -s nullglob
set -euo pipefail

echo ">>> Apply tasks"
for task_folder in task/*/; do
  if [ -d "$task_folder" ]; then
    task="$(basename "$task_folder")"
    echo ">>> Task: $task"
    (
      cd "$task_folder"
      for version in */; do
        if [ -d "$version" ]; then
          kubectl apply -f "$version/$task.yaml" --dry-run=server
        fi
      done
    )
  fi
done
