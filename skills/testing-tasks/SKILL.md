---
name: testing-tasks
description: Use when writing tests for a Tekton task, running tests locally, debugging test failures in CI, or understanding the three testing layers (Kind cluster, Tekton integration, ShellSpec).
---

# Testing Tasks

## Overview

This repo has three distinct testing layers, each with different setup, triggers, and purposes. Kind cluster tests validate tasks in a local environment; Tekton integration tests verify behavior in the Konflux cluster; ShellSpec tests validate embedded bash scripts in isolation.

## When to Use

- Writing a test for a new or modified task
- Running tests locally before pushing
- "Run Task Tests" workflow fails in CI
- Tekton integration test in `.tekton/integration/` fails
- Debugging a task's step behavior
- Understanding test infrastructure and patterns

## Testing Layers Summary

| Layer | Location | Trigger | Runs Where | When to Use |
|-------|----------|---------|-----------|------------|
| Kind cluster tests | `task/<name>/tests/` | GH Actions on PR (task/ changes) | Kind cluster in GH runner | Quick validation, dry-run syntax check |
| Tekton integration tests | `.tekton/integration/test-*.yaml` | Konflux CI on PR (CEL-filtered) | Konflux cluster | Full pipeline integration, result validation |
| ShellSpec unit tests | `task/<name>/spec/*_spec.sh` | Manual via `hack/test-shellspec.sh` | Local shell | Individual step logic, edge cases |

## Kind Cluster Tests

**When tests run:** GitHub Actions triggers on any PR modifying files in `task/` directory.

**Workflow:** `.github/workflows/run-task-tests.yaml` (templated from task-repo-shared-ci)

**How it works:**

1. Detects changed task directories
2. For each task with a `tests/` directory: runs `test-*.yaml` pipelines
3. Test script: `.github/scripts/test_tekton_tasks.sh`
4. Validation script (dry-run): `.github/scripts/check_tekton_tasks.sh`

### Writing a Kind Test

**Step 1:** Create directory

```bash
mkdir -p task/<task-name>/tests
```

**Step 2:** Create test pipeline

`task/<task-name>/tests/test-<task-name>.yaml` must be a Tekton Pipeline:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: test-<task-name>
spec:
  workspaces:
    - name: tests-workspace  # REQUIRED - test framework provides this workspace
  tasks:
    - name: run-task
      taskRef:
        name: <task-name>
      workspaces:
        - name: workspace
          workspace: tests-workspace
      params:
        - name: image-url
          value: "registry/image:tag"
        # IMPORTANT: All task params must be declared here, even if using defaults.
        # Omitting a param with a default will cause the test pipeline to fail.
        # - name: my-other-param
        #   value: "default-or-override-value"
```

**Step 3 (optional):** Create pre-apply hook

`task/<task-name>/tests/pre-apply-task-hook.sh` (optional) runs before task apply:

```bash
#!/bin/bash

TASK_COPY="$1"      # Path to temp copy of task YAML
TEST_NS="$2"        # Test namespace name

# Example: remove computeResources for constrained environment
yq -i eval '.spec.steps[0].computeResources = {}' "$TASK_COPY"
yq -i eval '.spec.steps[1].computeResources = {}' "$TASK_COPY"

# Create secrets if needed
echo '{"auths":{}}' | kubectl create secret generic docker-secret \
  --from-file=.dockerconfigjson=/dev/stdin \
  --type=kubernetes.io/dockerconfigjson \
  -n "$TEST_NS" --dry-run=client -o yaml | kubectl apply -f - -n "$TEST_NS"
```

**Step 4:** Test discovers tests by glob `test-*.yaml` automatically.

### Running Kind Tests Locally

Prerequisites: kind, kubectl, tkn CLI, Tekton installed

```bash
# Create a Kind cluster
kind create cluster

# Deploy Tekton
kubectl apply -f https://github.com/tektoncd/pipeline/releases/latest/download/release.yaml

# Run tests
./.github/scripts/test_tekton_tasks.sh task/<task-name>
```

### Namespace Isolation

Each test runs in its own namespace: `<task-name>-<version-with-hyphens>`

Test workspace is provided automatically with a claim template.

## Tekton Integration Tests

**Location:** `.tekton/integration/test-*.yaml`

**Purpose:** Validate task results structure in Konflux pipelines. These are PipelineRun definitions triggered by Pipelines-as-Code CEL expressions.

**Example:** `.tekton/integration/test-clair-scan.yaml` validates:

- `TEST_OUTPUT` result (JSON with result, note, timestamp)
- `SCAN_OUTPUT` result (JSON with vulnerability counts)
- `IMAGES_PROCESSED` result
- `REPORTS` result (OCI artifact digests)

**Result validation pattern:**

```yaml
finally:
  - name: check-results
    taskSpec:
      steps:
        - name: validate
          image: alpine:latest
          script: |
            # Validate TEST_OUTPUT structure
            echo '$(tasks.run-scan.results.TEST_OUTPUT)' | jq '.result'
            # Validate SCAN_OUTPUT has vulnerabilities
            echo '$(tasks.run-scan.results.SCAN_OUTPUT)' | jq '.vulnerabilities'
```

## ShellSpec Unit Tests

**Location:** `task/<task-name>/spec/*_spec.sh`

**Framework:** ShellSpec (shell script testing framework)

**Run locally:**

```bash
hack/test-shellspec.sh
```

**How it works:** Extracts step scripts from task YAML, tests them in isolation.

**Example spec file:**

```bash
# task/my-task/spec/check_script_spec.sh

Describe "check-script function"
  setup() {
    # Source the script or define functions
    eval "$(yq eval '.spec.steps[0].script' task/my-task/my-task.yaml)"
  }

  It "validates image URL"
    setup
    When call check_image_url "quay.io/my/image:tag"
    The status should be success
  End

  It "fails on invalid URL"
    setup
    When call check_image_url "invalid"
    The status should be failure
  End
End
```

## Common Test Failures

| Symptom | Likely Cause | Debug |
|---------|-------------|-------|
| "tests dir does not exist" | No `tests/` directory in changed task | Create `tests/test-*.yaml` pipeline |
| Pipeline timeout | computeResources too high for runner | Add `pre-apply-task-hook.sh` to lower limits |
| "Task validation failed" (dry-run) | Invalid task YAML syntax | `kubectl apply -f task.yaml --dry-run=server` |
| Result validation fails | Task output format changed | Check jq assertions in `.tekton/integration/test-*.yaml` |
| ShellSpec test fails | Script uses undefined variables | Check for unset env vars in isolated context |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Test file not named `test-*.yaml` | Script discovers by glob only. Rename to `test-<name>.yaml`. |
| Missing `tests-workspace` workspace | Test framework provides storage for this name. Must be declared in Pipeline. |
| Resource limits too high | Use `pre-apply-task-hook.sh` to zero out `computeResources` for Kind. |
| Editing templated test scripts | `.github/scripts/test_tekton_tasks.sh` comes from task-repo-shared-ci. PR upstream instead. |
| Task params not declared in test | Test Pipeline must declare all params the task needs. |
| Ignoring test failures locally | Local tests must pass before pushing. CI will run same tests. |
