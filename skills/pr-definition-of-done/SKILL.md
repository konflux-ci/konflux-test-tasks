---
name: pr-definition-of-done
description: Use before pushing a PR for review, when CI checks fail, or when reviewing someone else's PR. Pre-push checklist covering all CI requirements, commit conventions, and documentation for task catalog PRs.
---

# PR Definition of Done

## Overview

14+ GitHub Actions workflows run on every PR. This checklist ensures you pass all CI checks before pushing, reducing round-trip time and review cycles. Each section maps to a CI workflow.

## When to Use

- Before pushing a PR for review
- When CI check fails and you need to know which one
- When reviewing someone else's PR
- To understand what CI validates

## Pre-Push Checklist

### Commits

- [ ] Conventional commit format: `type(STONEINTG-XXXX): description`
- [ ] Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`
- [ ] Signed-off: `git commit -s` (DCO signature)
- [ ] Title < 72 characters
- [ ] AI-assisted: add trailer `Assisted-by: <tool-name>` if used

### Task YAML Changes

- [ ] Version label bumped if change should be released: `app.kubernetes.io/version: "x.y[.z]"`
- [ ] CHANGELOG.md updated (or "Unreleased" section if not releasing)
- [ ] Never use `$(params.*)` directly in scripts — use env variables instead
- [ ] All bash scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`
- [ ] No trailing newlines at EOF; last line ends with newline

### Generated Files (run when needed)

- [ ] Kustomize manifests updated: `hack/build-manifests.sh` (for -min variants)
- [ ] README auto-generated: `hack/generate-readme.sh` (if task interface changed)
- [ ] Or run all generators: `hack/generate-everything.sh`

### Migrations (if version bumped)

- [ ] Migration script created at `task/<name>/migrations/<version>.sh`
- [ ] Uses `pmt modify`, NOT `yq -i`
- [ ] Passes shellcheck: `shellcheck task/<name>/migrations/<version>.sh`
- [ ] If task has `-oci-ta` variant, create migration there too
- [ ] CHANGELOG.md updated with user-facing migration notes

### Code Formatting

- [ ] No unrelated whitespace changes
- [ ] No tabs on empty lines
- [ ] One newline at end of file only
- [ ] YAML indentation 2 spaces (consistent with existing files)

### Security

- [ ] No secrets, API keys, or credentials committed
- [ ] No sensitive info in commit messages or PR description
- [ ] Container image references are trusted (konflux-ci, quay.io/redhat-user-workloads, etc.)

## CI Checks Matrix

| Workflow | Triggered By | What Fails It | Repo File |
|----------|-------------|--------------|-----------|
| **YAML Lint** | Any `.yaml`, `.yml` file change | YAML syntax errors, indentation | `.github/workflows/yaml-lint.yaml` |
| **Checkton** | Task YAML changes | ShellCheck violations in embedded scripts | `.github/workflows/checkton.yaml` |
| **Task Lint** | Task YAML changes | `$(params.*)` used directly in script blocks | `.github/workflows/task-lint.yaml` |
| **Versioning** | Task YAML changes | Missing `app.kubernetes.io/version` label, missing CHANGELOG.md | `.github/workflows/versioning.yaml` |
| **Kustomize Build** | `kustomization.yaml`, `patch.yaml` changes | Regenerated manifest files stale | `.github/workflows/check-kustomize-build.yaml` |
| **Task Migrations** | Migration files added/modified | Invalid migration script, failed `pmt modify` | `.github/workflows/check-task-migration.yaml` |
| **Check READMEs** | README files, task structure changes | README out of date or missing | `.github/workflows/check-readmes.yaml` |
| **Check Task YAMLs** | Task YAML changes | Invalid Tekton task definition (kubectl dry-run) | `.github/workflows/check-task-yamls.yaml` |
| **Check TA Variants** | Task changes | Missing or stale trusted-artifacts variants | `.github/workflows/check-ta.yaml` |
| **Check Task Owners** | CODEOWNERS changes | Mismatch between CODEOWNERS and renovate.json | `.github/workflows/check-task-owners.yaml` |
| **Go CI** | `task-generator/*/` changes | golangci-lint, go test, go mod tidy failures | `.github/workflows/go-ci.yaml` |
| **Run Task Tests** | Task `tests/` directory changes | Kind cluster test pipeline failures | `.github/workflows/run-task-tests.yaml` |
| **AgentReady** | Any file change | Code quality and AI-readiness assessment | `.github/workflows/agentready.yaml` |

## Templated Files Warning

Files marked with `<TEMPLATED FILE!>` comment come from [task-repo-shared-ci](https://github.com/konflux-ci/task-repo-shared-ci).

**Do NOT edit these files directly.** Instead, send PR upstream to the template repo or use:

```bash
cruft update --skip-apply-ask --allow-untracked-files
```

Check for `<TEMPLATED FILE!>` in:

- Most of `hack/`
- Most of `.github/workflows/`
- `.github/scripts/`

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Edited a TEMPLATED FILE | Send PR to task-repo-shared-ci instead; or run `cruft update` |
| Kustomize manifests stale | `hack/build-manifests.sh` after changing `kustomization.yaml` or `patch.yaml` |
| TA variant out of date | `hack/generate-ta-tasks.sh` |
| `$(params.*)` in script | Create env var in task spec: `env: - name: MY_VAR value: "$(params.my-param)"` then use `$MY_VAR` |
| Missing CODEOWNERS entry | Add task to CODEOWNERS; run `hack/check-task-owners.sh -f` |
| Checkton fails locally but not in CI | CI uses full git diff history. Run locally: `hack/checkton-local.sh` |
| Versioning warning treated as error | Versioning warnings don't block merge. But best practice: always update version + CHANGELOG together. |
