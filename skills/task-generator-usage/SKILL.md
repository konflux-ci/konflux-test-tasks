---
name: task-generator-usage
description: Use when creating task variants (remote, trusted-artifacts), working with recipe.yaml files, or when the check-ta CI workflow fails. Covers both Go generators, the recipe format, and the generation pipeline.
---

# Task Generator Usage

## Overview

Two Go programs in `task-generator/` generate task variants: **remote** for multi-platform builds, and **trusted-artifacts** for OCI-based artifact sharing. Trusted-artifacts is enforced by CI; remote is optional.

## When to Use

- Creating a trusted-artifacts (-oci-ta) variant of a task
- Creating a remote variant of a task
- "Check Trusted Artifact variants" CI fails
- Modifying `recipe.yaml` configuration
- Understanding the generation pipeline and order

## Generators

| Generator | Path | Purpose | Use When |
|-----------|------|---------|----------|
| Trusted Artifacts | `task-generator/trusted-artifacts/` | Generates OCI-TA variants from `recipe.yaml` | Task uses workspaces to share data |
| Remote | `task-generator/remote/` | Generates multi-platform variants | Need multiple architectures (x86, arm64) |

## Trusted Artifacts Generator

### When a task needs a TA variant

Any task that uses workspaces to share data with other tasks needs a TA variant.

**The CI check** `hack/missing-ta-tasks.sh` in `.github/workflows/check-ta.yaml` enforces this automatically.

**Exception:** Workspace is listed in `.ta-ignore.yaml` (e.g., `netrc-auth` for read-only creds)

### Creating a TA variant

**Step 1:** Create directory mirroring base task structure

```
task/<task-name>-oci-ta/
```

**Step 2:** Create `recipe.yaml` (TA generator configuration)

```yaml
---
base: ../../<task-name>/<task-name>.yaml
add:
  - create-source
  - use-source
removeWorkspaces:
  - source  # Remove workspaces no longer needed in TA variant
replacements:
  - old: image: quay.io/external/image
    new: image: quay.io/internal/image
addParams:
  - name: ca-trust-config-map
    description: ConfigMap with CA certs
    type: string
addResult:
  - name: ta-report
    type: string
```

**Step 3:** Generate the TA variant YAML

```bash
hack/generate-ta-tasks.sh
```

Output: `task/<task-name>-oci-ta/<task-name>-oci-ta.yaml` (auto-generated)

**Step 4:** Commit both `recipe.yaml` and generated YAML

```bash
git add task/<task-name>-oci-ta/
git commit -m "feat: add trusted-artifacts variant of <task-name>"
```

### recipe.yaml Configuration

**Basic options:**

| Option | Purpose | Example |
|--------|---------|---------|
| `base` | Path to base task YAML (relative to recipe.yaml) | `../../clair-scan/clair-scan.yaml` |
| `add` | Transformations to apply | `create-source`, `use-source`, `copy-from-source` |
| `removeWorkspaces` | Workspace names to remove | `source`, `temp` |
| `removeSteps` | Step names to remove from task | `setup`, `cleanup` |
| `replacements` | String replacements in YAML | `old:` / `new:` pairs |
| `regexReplacements` | Regex-based replacements | `regex:` / `replacement:` pairs |
| `addParams` | Parameters to add | `name:`, `type:`, `description:` |
| `addResults` | Results to add | `name:`, `type:` |
| `addEnvironment` | Environment variables | `name:`, `value:` |

**Detailed format:**

```yaml
base: ../../task-name/task-name.yaml

add:
  - create-source    # Creates source archive from input workspace
  - use-source       # Uses source archive instead of workspace
  - copy-from-source # Copies specific files from archive

removeWorkspaces:
  - workspace-name

removeSteps:
  - step-name

replacements:
  - old: "old-string"
    new: "new-string"

regexReplacements:
  - regex: "pattern.*"
    replacement: "new-value"

addParams:
  - name: param-name
    type: string
    default: "default-value"
    description: "Description of parameter"

addResults:
  - name: result-name
    type: string

addEnvironment:
  - name: ENV_VAR
    value: "value"
```

### Kustomized TA Variants

For kustomized tasks (like `-min` variants), the TA variant can also be kustomized.

**Structure:**

```
task/<task-name>-oci-ta/
├── CHANGELOG.md
├── recipe.yaml
└── kustomization.yaml     # References base TA variant
```

**Example kustomization.yaml:**

```yaml
bases:
  - ../../<task-name>-oci-ta

patchesStrategicMerge:
  - patch.yaml
```

### Documentation

For complete `recipe.yaml` format and examples, see the upstream repository:

https://github.com/konflux-ci/build-definitions/tree/main/task-generator/trusted-artifacts

## Generation Pipeline Order

When regenerating multiple types of variants, run in this exact order:

```bash
hack/build-manifests.sh         # Step 1: Kustomize manifests
hack/generate-ta-tasks.sh       # Step 2: Trusted-artifacts variants
hack/generate-buildah-remote.sh # Step 3: Remote variants
```

Or run all at once:

```bash
hack/generate-everything.sh
```

**Why order matters:** Later generators depend on outputs of earlier ones.

## Testing Generators

Both generators have unit tests:

```bash
cd task-generator/trusted-artifacts
go test ./...

cd ../remote
go test ./...
```

**Golden tests:** Reference test outputs in `task-generator/trusted-artifacts/golden/`

These ensure generated YAML is reproducible and matches expected format.

## Ignore File for Missing TA Variants

If a workspace-using task should NOT have a TA variant, add it to `.ta-ignore.yaml`:

**Path:** `.github/.ta-ignore.yaml` or `.ta-ignore.yaml` (highest precedence first)

```yaml
# Task paths (glob patterns) to ignore
paths:
  - task/some-task/*
  - task/another-task/*/*

# Workspace names that don't require TA variants
# (local or read-only workspaces, not shared between tasks)
workspaces:
  - netrc-auth
  - git-auth
  - ca-trust
```

## CI Checks

**Workflow:** `.github/workflows/check-ta.yaml`

**Checks:**

1. **Generation:** `hack/generate-ta-tasks.sh` succeeds
2. **Completeness:** `hack/missing-ta-tasks.sh` finds no workspace-using tasks without TA variants
3. **Up-to-date:** Generated YAML matches recipe.yaml (no manual edits)

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Generated YAML file not committed | Run `hack/generate-ta-tasks.sh`, commit output alongside `recipe.yaml` |
| recipe.yaml path wrong | Use relative path from recipe.yaml to base task. Verify with `ls` from recipe.yaml location. |
| Missing `-oci-ta` CHANGELOG.md | Create `task/<name>-oci-ta/CHANGELOG.md` with same format as base task |
| Go mod tidy drift in generator | `cd task-generator/<dir> && go mod tidy && go mod vendor` |
| Generator binary not in PATH | Install: `go install ./cmd/...` from task-generator directory |
| Edited generated YAML by hand | Don't. Regenerate from recipe.yaml. Your edits will be lost on next run. |
| Wrong base task path in recipe.yaml | Check path exists: `ls $(dirname recipe.yaml)/<base-path>` |
