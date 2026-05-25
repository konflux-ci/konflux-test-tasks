---
name: task-versioning-and-migration
description: Use when creating a new task version, bumping version labels, writing migration scripts, or when versioning/migration CI checks fail. Covers version labels, CHANGELOG.md, migration scripts with pmt modify, and kustomized variant updates.
---

# Task Versioning and Migration

## Overview

Versioning in this repo involves coordinating the `app.kubernetes.io/version` label, `CHANGELOG.md`, and optional migration scripts in the `migrations/` directory. When a task interface changes or a critical bug is fixed, you create a new version and optionally a migration script to help users update their pipelines automatically.

## When to Use

- Creating a new major.minor or patch version of a task
- Writing migration scripts for pipeline updates
- "Versioning" or "Check task migrations" CI checks fail
- Updating CHANGELOG.md for a task
- Understanding the version bump + migration workflow

## Quick Reference

| Action | Command/File | Notes |
|--------|--------------|-------|
| Bump version | Edit `task/<name>/<name>.yaml`, update label `app.kubernetes.io/version` | Format: `x.y` or `x.y.z` |
| Create migration | `mkdir -p task/<name>/migrations && touch task/<name>/migrations/<version>.sh` | Filename must match version label |
| Create migration helper | `./hack/create-task-migration.sh -t <task-name>` | Generates template script |
| Validate locally | `./hack/versioning.py check` | Checks version label + CHANGELOG |
| Check migration | `bash ./hack/validate-migration.sh` | Requires kind + pmt installed |
| Add CHANGELOG | `./hack/versioning.py new-changelog task/<name>/` | Creates or updates CHANGELOG.md |

## Version Label Rules

The `app.kubernetes.io/version` label in task YAML metadata controls versioning:

```yaml
metadata:
  labels:
    app.kubernetes.io/version: "0.2"
    # or
    app.kubernetes.io/version: "0.2.1"
```

- Format: `x.y` or `x.y.z` (integers only, no strings like "v0.2")
- Migration filename must match exactly: `migrations/0.2.sh` for version `0.2`
- CI checks: versioning.yaml validates label format and CHANGELOG presence

## Creating a Migration Script

Migrations use `pmt modify` (NOT `yq -i`) to update Konflux standard pipelines.

**File structure:**

```
task/<task-name>/
├── <task-name>.yaml           # with updated app.kubernetes.io/version label
└── migrations/
    └── <version>.sh           # e.g., 0.2.sh
```

**Script template:**

```bash
#!/usr/bin/env bash
set -euo pipefail
pipeline_file="$1"

# pmt modify is idempotent - safe to run multiple times
pmt modify -f "$pipeline_file" task <task-name> add-param my-new-param "default-value"
```

**Requirements:**

- Single argument: `$1` = pipeline file path (Pipeline or PipelineRun)
- Use `pmt modify` commands (NEVER `yq -i`)
- Idempotent (safe to run multiple times)
- Pass shellcheck without custom rules
- Keep simple and focused

**Testing the script locally:**

```bash
pmt modify -f /path/to/.tekton/component-a-pull.yaml task clair-scan add-param my-param "value"
```

## CHANGELOG.md Requirements

Each task MUST have a `CHANGELOG.md` at `task/<name>/CHANGELOG.md`.

**Format:** Follow [keepachangelog.com](https://keepachangelog.com) format

**Example:**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.2] - 2025-05-20

### Added
- New parameter: `my-new-param`

### Changed
- Updated base image from ubi8 to ubi9

## [0.1] - 2025-04-15

### Added
- Initial release
```

**Rules:**

- Required for all tasks (CI warns if missing)
- Use "Unreleased" section for changes before release
- Update when bumping version
- CI requires both CHANGELOG update AND version bump together (warning only, not blocker)

## Steps Required from User

When bumping a task version and adding a migration, the user must do all of these steps — in order:

1. Edit the task YAML: update `app.kubernetes.io/version` label to the new version (e.g. `0.2` → `0.3`)
2. Create the migration script: `task/<name>/migrations/<version>.sh` using `pmt modify` commands
3. If the task has an `-oci-ta` variant: create a matching migration in `task/<name>-oci-ta/migrations/<version>.sh`
4. Update `task/<name>/CHANGELOG.md`: add an entry for the new version under the appropriate section
5. If the task is kustomized (e.g. `-min` variant): run `hack/build-manifests.sh` to regenerate the variant YAML
6. Verify the migration locally: `bash ./hack/validate-migration.sh` (requires kind + Tekton + pmt)
7. Run shellcheck on the migration script: `shellcheck task/<name>/migrations/<version>.sh`

Nothing is optional — CI enforces all of steps 1–4. Steps 5–7 prevent CI failures before push.

## When to Create a New Version Directory

**Note:** The repo supports both flat (`task/<name>/<name>.yaml`) and legacy versioned (`task/<name>/<ver>/<name>.yaml`) structures. The version is determined by the `app.kubernetes.io/version` label, NOT the directory.

Create a new version when:

1. Task interface changes (params renamed/added/removed, workspaces changed, results changed)
2. Non-backward-compatible functionality changes
3. Critical bug fix requiring updated implementation
4. Adding new features users should opt into

Include a migration script and updated CHANGELOG.md.

## Kustomized Task Variants (-min tasks)

Kustomized variants (like `clair-scan-min`) reference their base task via `kustomization.yaml`:

```yaml
# task/clair-scan-min/kustomization.yaml
bases:
  - ../../clair-scan

patchesStrategicMerge:
  - patch.yaml
```

**When base task bumps version:**

1. Update base task version label
2. Run `hack/build-manifests.sh` to regenerate kustomized variants
3. Commit regenerated YAML files
4. Optionally create migration for the -min variant too

## OCI-TA Variant Migrations

If a task has an `-oci-ta` variant, it MUST also get a migration script. The `validate-migration.sh` CI check enforces this automatically.

Structure:

```
task/<task-name>/
└── migrations/
    └── 0.2.sh

task/<task-name>-oci-ta/
└── migrations/
    └── 0.2.sh
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Migration filename doesn't match version label | Ensure `app.kubernetes.io/version` exactly matches `migrations/<ver>.sh` filename |
| Used `yq -i` in migration | Replace with `pmt modify` commands. See pmt README for all subcommands. |
| Forgot CHANGELOG.md | `./hack/versioning.py new-changelog task/<name>/` |
| Modified an existing migration file | Not allowed. Create a new version instead. |
| Base task bumped, -min variant stale | Run `hack/build-manifests.sh` after any kustomization changes |
| Missing OCI-TA migration | Create migration in both base and `-oci-ta` directories |
| Version label has "v" prefix | Remove: use `0.2`, not `v0.2` |
