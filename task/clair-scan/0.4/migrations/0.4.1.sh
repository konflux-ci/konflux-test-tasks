#!/usr/bin/env bash

set -euo pipefail

# Created for task: roxctl-scan@0.1
# Creation time: 2026-08-14T01:52:31+00:00
# This script will migrate users from clair-scan 0.3 to roxctl-scan 0.1
# It has to be placed in the clair-scan/0.4/ directory so that mintmaker knows
# that it should be used to migrate users FROM clair-scan 0.3
# Users with clair-scan-min will also need to be migrated, so this script is symlinked
# between the clair-scan and clair-scan-min task dirs

declare -r pipeline_file=${1:?missing pipeline file}
declare -r OLD_TASK_NAME="clair-scan"
declare -r NEW_TASK_NAME="roxctl-scan"
declare -r BUNDLE="quay.io/konflux-ci/tekton-catalog/task-roxctl-scan:0.1"

OLD_TASK_NAME_FOUND=""
OLD_TASK_PATH=".spec.pipelineSpec.tasks"

# check if new tasks exists - skip if it does
if yq -e '.spec.pipelineSpec.tasks[] | select(.name == "'"$NEW_TASK_NAME"'")' "$pipeline_file" >/dev/null 2>&1; then
  echo "Task '$NEW_TASK_NAME' already exists in the pipeline."
  exit 0
elif yq -e '.spec.tasks[] | select(.name == "'"$NEW_TASK_NAME"'")' "$pipeline_file" >/dev/null 2>&1; then
  echo "Task '$NEW_TASK_NAME' already exists in the pipeline."
  exit 0
fi

# check if old task exists
if yq -e "$OLD_TASK_PATH"'[] | select(.name == "'"$OLD_TASK_NAME"'")' "$pipeline_file" >/dev/null 2>&1; then
    OLD_TASK_NAME_FOUND="$OLD_TASK_NAME"
elif  yq -e "$OLD_TASK_PATH"'[] | select(.name == "'"$OLD_TASK_NAME"-min'")' "$pipeline_file" >/dev/null 2>&1; then
    OLD_TASK_NAME_FOUND="$OLD_TASK_NAME"-min
elif  yq -e '.spec.tasks[] | select(.name == "'"$OLD_TASK_NAME"'")' "$pipeline_file" >/dev/null 2>&1; then
    OLD_TASK_PATH=".spec.tasks"
    OLD_TASK_NAME_FOUND="$OLD_TASK_NAME"
elif  yq -e '.spec.tasks[] | select(.name == "'"$OLD_TASK_NAME"-min'")' "$pipeline_file" >/dev/null 2>&1; then
    OLD_TASK_PATH=".spec.tasks"
    OLD_TASK_NAME_FOUND="$OLD_TASK_NAME"-min
else
    echo "Neither task '$OLD_TASK_NAME' nor task '$OLD_TASK_NAME-min' exist in the pipeline."
    exit 0
fi

# update task name
pmt modify -f "$pipeline_file" task "$OLD_TASK_NAME_FOUND" rename "$NEW_TASK_NAME"

# update taskRef
pmt modify -f "$pipeline_file" task "$NEW_TASK_NAME" set-bundle "$BUNDLE" --task-ref-name "$NEW_TASK_NAME"

# remove unused params
pmt modify -f "$pipeline_file" task "$NEW_TASK_NAME" remove-param docker-auth
pmt modify -f "$pipeline_file" task "$NEW_TASK_NAME" remove-param image-platform
pmt modify -f "$pipeline_file" task "$NEW_TASK_NAME" remove-param ca-trust-config-map-name
pmt modify -f "$pipeline_file" task "$NEW_TASK_NAME" remove-param ca-trust-config-map-key
pmt modify -f "$pipeline_file" task "$NEW_TASK_NAME" remove-param skip-oci-attach-report

