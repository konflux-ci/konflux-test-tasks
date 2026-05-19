---
name: ci-cd-quirks
description: Use when CI behaves unexpectedly, when you need to understand how Tekton bundles are built, or when understanding non-obvious behavior with templated workflows, Checkton, migration validation, kustomize checks, or trusted artifacts generation.
---

# CI/CD Quirks and Gotchas

## Overview

This repo's CI is heterogeneous: templated GitHub Actions workflows, task-specific Tekton build pipelines with CEL-based path triggers, Conforma policies, and shared CI update automation. Several behaviors are non-obvious.

## When to Use

- CI failed and you don't understand why
- Need to understand how task bundles are built and tagged
- Checkton or task-lint is blocking your PR
- Understanding what's templated vs what's local
- Migration validation mysteriously passes/fails

## Templated vs Local Files

Files with `<TEMPLATED FILE!>` header come from [task-repo-shared-ci](https://github.com/konflux-ci/task-repo-shared-ci).

**Templated (do NOT edit):**

- Most of `hack/` directory
- Most `.github/workflows/` (except task-specific ones)
- `.github/scripts/`

**Local (edit freely):**

- All `task/` YAML files and directories
- `.tekton/` build pipelines
- `.tekton/integration/` test definitions
- `policies/` Conforma policies
- `CODEOWNERS`, `renovate.json`, `README.md`

**Update template:**

```bash
cruft update --skip-apply-ask --allow-untracked-files
```

Automated weekly via `update-shared-ci.yaml` workflow.

## Tekton Bundle Build System

### How task bundles are built

Each task version gets its own Tekton PipelineRun definition: `.tekton/<task>-<ver>-pull-request.yaml` and `.tekton/<task>-<ver>-push.yaml`

These are templated via Pipelines-as-Code and triggered by CEL expressions matching path changes.

**Example:** `clair-scan-v03-pull-request.yaml` triggers on changes to `task/clair-scan/***`

**Build output:**

- Bundle image: `quay.io/redhat-user-workloads/rhtap-integration-tenant/<task>:<tag>`
- Tag on PR: `on-pr-<git-revision>`
- Tag on push: `<git-revision>`
- PR images expire after 5 days; max 3 kept

### Tag scheme (build-and-push.sh)

- **Floating tag:** `<major.minor>` — always points to latest bundle
- **Fixed tag:** `<task>-<identifier>` — immutable snapshot
  - Identifier for normal tasks: git commit hash
  - Identifier for kustomized tasks: content hash (reproducible)

Both tags point to same image; use fixed tag for stability.

## Checkton (ShellCheck on YAML)

Checkton lints shell scripts embedded in YAML files.

**Workflow:** `.github/workflows/checkton.yaml`

**What it checks:** ShellCheck rules on every `script:` block in Tekton files

**Behavior:**

- Differential mode: runs on full git history (commits you changed)
- Excludes: `task-generator/` directory
- Run locally: `hack/checkton-local.sh` (requires podman/docker)

**Inline directives work:**

```yaml
script: |
  # shellcheck disable=SC2016  # Single quotes with $ are fine
  echo "$(params.my-param)"
```

**Common failures:**

- SC2016: Single quotes with `$` (use double quotes for interpolation)
- SC1091: Can't follow source (ignore if source is injected)
- SC2086: Unquoted variable (quote: `"$var"` not `$var`)

## Task Lint (Security Rule)

**Workflow:** `.github/workflows/task-lint.yaml`

**What it checks:** `$(params.*)` used directly in `.spec.steps[].script` blocks

**Why it fails:** Raw parameter substitution = code injection risk. Tekton performs text replacement before script execution.

**Correct pattern:**

```yaml
spec:
  steps:
    - name: my-step
      env:
        - name: IMAGE_URL
          value: "$(params.image-url)"
      script: |
        echo "$IMAGE_URL"  # NOT $(params.image-url)
```

## Migration Validation Quirks

**Workflow:** `.github/workflows/check-task-migration.yaml`

**Requirements:**

- kind cluster running locally (if testing)
- Tekton Pipelines installed (`kubectl apply -f release.yaml`)
- `pmt` (pipeline-migration-tool) in PATH
- Konflux standard pipelines accessible (downloaded from ConfigMap)

**Validation steps:**

1. Finds all `migrations/*.sh` files
2. Downloads real Konflux standard pipelines from ConfigMap
3. Applies each migration to each pipeline
4. Diffs before/after
5. Fails if migration changes nothing (no-op)
6. Fails if `yq -i` used instead of `pmt modify`

**Local testing:**

```bash
# Prerequisites
kind create cluster
kubectl apply -f https://github.com/tektoncd/pipeline/releases/latest/download/release.yaml
go install github.com/konflux-ci/pipeline-migration-tool/cmd/pmt@latest

# Validate
IN_CLUSTER=1 bash ./hack/validate-migration.sh
```

**Gotchas:**

- Migration must change at least one pipeline (no-op = failure)
- Cannot delete or modify existing migration files (only add new ones)
- One migration per task per PR
- OCI-TA variants need separate migrations

## Kustomize Build Check

**Workflow:** `.github/workflows/check-kustomize-build.yaml`

**What it checks:** Generated manifest files are up to date

**Command:** `hack/build-manifests.sh` (uses `oc kustomize` binary)

**Requirement:** OpenShift CLI (`oc`) installed

**Scope:** Only rebuilds tasks with `kustomization.yaml` that reference external resources

**Gotcha:** Kustomize auto-adds comment `# <auto-generated>` at top of output — don't remove it

## Trusted Artifacts Check

**Workflow:** `.github/workflows/check-ta.yaml`

**Two checks:**

1. **Variant generation:** `hack/generate-ta-tasks.sh` — generates from `recipe.yaml`
2. **Missing variant detection:** `hack/missing-ta-tasks.sh` — flags workspace-using tasks without `-oci-ta` variant

**Ignore file (optional):** `.github/.ta-ignore.yaml` or `.ta-ignore.yaml`

This file does **not** exist in this repo by default. Create it only when you need to exclude specific tasks or workspace names from the TA check.

```yaml
paths:
  - task/some-task/*     # Don't require TA variant for this task
workspaces:
  - netrc-auth           # Workspace names that don't share data
  - git-auth
```

**Gotcha:** Only tasks with workspaces that share data between tasks need TA variants. Read-only or local workspaces don't.

## Conforma Policies

**Location:** `policies/`

**Files:**

- `all-tasks.yaml` — Policies applied to all task bundles
- `build-tasks.yaml` — Build-specific policies
- `step-actions.yaml` — Step action policies

**Policy enforcement:** During bundle image build via Enterprise Contract

## Generation Pipeline Order

When regenerating multiple types of variants, run in this order:

```bash
hack/build-manifests.sh         # Kustomize first
hack/generate-ta-tasks.sh       # TA variants second
hack/generate-buildah-remote.sh # Remote variants last (if exists)
```

Or just: `hack/generate-everything.sh`

**Why order matters:** Later generators may depend on outputs of earlier ones.

## Common Surprises

| Surprise | Explanation |
|----------|-------------|
| PR only triggers some Tekton pipelines | CEL expression scopes trigger to specific task paths. Check `.tekton/<task>-pull-request.yaml`. |
| "Stale manifests" even though I changed the right file | Kustomized task requires `hack/build-manifests.sh`. Re-run if you touched `kustomization.yaml` or `patch.yaml`. |
| Checkton flags inline script I didn't change | Differential mode uses full git history. Run locally: `hack/checkton-local.sh` to verify. |
| Migration check passes locally but fails in CI | Local version may not have Tekton installed. CI has it. Use `IN_CLUSTER=1 bash ./hack/validate-migration.sh` locally. |
| `generate-everything.sh` changed files I didn't modify | Generators are deterministic but may update manifests when templates change. Commit generated files. |
| Can't find `generate-buildah-remote.sh` | Verify it exists: `ls hack/generate-buildah-remote.sh`. May be added/removed by cruft updates. |

## Non-Obvious Gotchas

- **Bundle expiry:** PR images expire after 5 days. Don't rely on old PR bundles.
- **Migration idempotency:** `pmt` commands are idempotent, but your script might not be. Test running migration twice.
- **CODEOWNERS + renovate.json:** Must stay in sync. `hack/check-task-owners.sh` validates this.
- **Kustomize overlay paths:** Relative paths in kustomization.yaml must point to correct base. Check paths match directory structure.
