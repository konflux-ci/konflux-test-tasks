## AGENTS.md

This repository contains a collection of [Tekton](https://tekton.dev/) resources and helpers designed to support building and running test tasks in the [Konflux CI](https://konflux-ci.dev/docs/) pipelines. The goal is to provide a trusted set of testing tasks that can be used to ensure the quality of the images that are built in the Konflux CI system.

## Technology Stack

- **Language**: Tekton, bash
- **Pipeline engine**: Tekton PipelineRuns
- **Testing**: Tekton integration pipelines and GitHub actions
- **Build**: Tekton build pipelines

## Repository Structure

```
tasks/                 # standardized Tekton tasks that are used to run different kinds of verifications for container builds
policies/              # Conforma policies that need to be applied when building bundle images of individual tasks
task-generator/        # Collection of tools used for generating various versions of tasks
.tekton/               # Tekton build PipelineRuns which create Tekton bundle images
.tekton/integration/   # Tetkon integration test PipelineRuns for validating task functionality in Konflux environments
hack/                  # Various scripts that are used during the CI runs of the build/test/release workflow for the individual Tekton tasks
```

## Architecture

### Tekton tasks
The most important part of this repository is the collection of Tekton tasks which are meant to be used in the Konflux
pipelines within the [build-definitions](https://github.com/konflux-ci/build-definitions) repository. The tasks are built via the Konflux build pipelines and are distributed in the form of individual Tekton bundle images. The individual tasks are versioned according to the guidance outlined in the `README.md`

### Step runner images
The main runner images used in individual steps within the Tekton tasks are as follows:

- `konflux-test`: the utility image used for running non-specific task steps, providing the utils bash functions and executing Conftest policies, source code at https://github.com/konflux-ci/konflux-test
- `task-runner`: the utility image mainly used for running the oras to attach oci artifacts, source code at https://github.com/konflux-ci/task-runner
- `clair-in-ci`: the Clair database image for executing vulnerability scans with the clair-in-ci tool, source code at https://github.com/konflux-ci/clair-in-ci-db
- `clamav-db`: the Clamav database image for executing anti-viruse scans with the clamscan tool, source code at https://github.com/konflux-ci/konflux-clamav

### Shared CI

Some of the CI scripts and workflows in this repo come from the [task-repo-shared-ci](https://github.com/konflux-ci/task-repo-shared-ci) template repo. All the files that come from the template repo have a `<TEMPLATED FILE!>` comment near the top to help identify them.

## Development Guidelines

- See `CONTRIBUTING.md` and `README.md` for overall guidelines for making contributions to this repository.
- **Git**: conventional commits with Jira ticket as scope — `type(issue-id): description` (e.g. `feat(STONEINTG-1519): create PR group snapshots from ComponentGroups`)
    - The `main` branch is read only, never push there directly, a new feature branch must be created instead
    - Pull requests are used to propose changes to the `main` branch
- Don't change whitespaces or newlines in the existing unrelated code and never add whitespaces or tabs to empty lines
- Don't remove unrelated code and don't change files when/where modifications are not needed
- Don't add trailing newlines at the end of file, last newline character is at the end of code
- Never use Tekton parameters as "$(params.*)" directly in the script, make Tekton env variable first in Tekton task definition and use env variable in the script
- If a user hasn't specified otherwise, default script language is `bash`
- Add the shebang of the script language to the script
- Always set `set -euo pipefail` at the beginning of the bash script to prevent unexpected errors
