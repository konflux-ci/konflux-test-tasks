#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s globstar

git_root=$(git rev-parse --show-toplevel)
policy_file="${git_root}/policies/all-tasks.yaml"

tmp_files=()
trap 'rm "${tmp_files[@]}" > /dev/null 2>&1' EXIT

emit() {
  kind="$1"
  file="$2"
  msg="$3"
  if [ "${GITHUB_ACTIONS:-false}" == "true" ]; then
    printf "::${kind} file=%s,line=1,col=0::%s\n" "${file}" "${msg}"
  else
    printf "${kind@U}: \033[1m%s\033[0m %s\n" "${file}" "${msg}"
  fi
}

{
  cd "${git_root}"
  missing=0
  for task in task/**/*.yaml; do
      task_file="${task}"
      case "${task}" in
          */kustomization.yaml)
              tmp=$(mktemp)
              tmp_files+=("${tmp}")
              kustomize build "${task%/kustomization.yaml}" > "${tmp}"
              task_file="${tmp}"
              ;;
          */recipe.yaml | */patch.yaml)
              continue
              ;;
      esac

      # we are looking at a Task
      yq -e '.kind != "Task"' "${task_file}" > /dev/null 2>&1 && continue

      # path elements of the task file path
      readarray -d / paths <<< "${task}"
      # PVC non-optional workspaces used
      readarray -t workspaces <<< "$(yq ea '[select(fileIndex == 0).spec.workspaces[] | .name] - [select(fileIndex == 1).sources[].ruleData.allowed_trusted_artifacts_workspaces[] | .] | .[] | {"x": .} | "\(.x)"' "${task_file}" "${policy_file}")"

      # is the task using a workspace(s) to share files?
      [[ "${#workspaces}" -eq 0 ]] && continue

      # is there a newer version of the task
      base_task_path=("${paths[@]}")
      unset 'base_task_path[-1]'
      version="${base_task_path[-1]/\/}"
      unset 'base_task_path[-1]'
      for dir in $(IFS=''; echo "${base_task_path[*]}*"); do
          [[ ! -d "${dir}" ]] && continue
          [[ "${version}" < "${dir/*\/}" ]] && continue 2
      done

      # there is no Trusted Artifacts variant of the task
      unset 'paths[-1]'
      paths[-2]="${paths[-2]%/}-oci-ta/"
      ta_dir="$(IFS=''; echo "${paths[*]}")"
      if [[ ! -d "${ta_dir}" ]]; then
          emit error "${task}" "Task is using a workspace(s): ${workspaces[*]}, to share data and needs a corresponding Trusted Artifacts Task variant in ${ta_dir}"
          missing=$((missing + 1))
      fi
  done

  if [[ ${missing} -gt 0 ]]; then
    if [ "${GITHUB_ACTIONS:-false}" == "true" ]; then
      echo '::notice title=Missing Trusted Artifact Task Variant::Found Tasks that share data via PersistantVolumeClaim volumes without a corresponding Trusted Artifacts Variant. Please create the Trusted Artifacts Variant of the Task as well'
      exit 1
    fi
  fi
}
