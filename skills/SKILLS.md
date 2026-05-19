# Konflux Test Tasks AI Skills

Repository-specific AI skills for the konflux-test-tasks Tekton task catalog. These skills are tool-agnostic and can be used with any AI agent (Claude Code, Codex, Goose, etc.) via symlinks to the agent's skill directory.

## Available Skills

| Skill | Description |
|-------|-------------|
| [task-versioning-and-migration](task-versioning-and-migration/SKILL.md) | Version bumps, migration scripts, CHANGELOG.md, and the pmt modify workflow |
| [testing-tasks](testing-tasks/SKILL.md) | Kind cluster tests, Tekton integration tests, ShellSpec unit tests, and test debugging |
| [pr-definition-of-done](pr-definition-of-done/SKILL.md) | Pre-push checklist: all 14+ CI checks, commit conventions, generated files |
| [ci-cd-quirks](ci-cd-quirks/SKILL.md) | Non-obvious CI behavior: templated files, bundle tagging, Checkton, migration validation |
| [task-generator-usage](task-generator-usage/SKILL.md) | Go-based generators for remote and trusted-artifact task variants |
| [debugging-task-failures](debugging-task-failures/SKILL.md) | Task result formats, scan output schemas, runner images, common failures |

## Setup for Claude Code

Skills are symlinked from `.claude/skills/` for automatic discovery:

```
.claude/skills/task-versioning-and-migration -> ../../skills/task-versioning-and-migration
.claude/skills/testing-tasks -> ../../skills/testing-tasks
.claude/skills/pr-definition-of-done -> ../../skills/pr-definition-of-done
.claude/skills/ci-cd-quirks -> ../../skills/ci-cd-quirks
.claude/skills/task-generator-usage -> ../../skills/task-generator-usage
.claude/skills/debugging-task-failures -> ../../skills/debugging-task-failures
```

## Setup for Other Agents

Create symlinks from your agent's skill directory to `skills/`:

```bash
# Example for Codex
mkdir -p .agents/skills
ln -s ../../skills/task-versioning-and-migration .agents/skills/
ln -s ../../skills/testing-tasks .agents/skills/
# ... etc
```
