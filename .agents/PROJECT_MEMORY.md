# Project memory

## Project purpose

- Primary goal: one canonical file of personal working rules, wired into every AI tool, plus the templates and checks that carry the same rules into other repositories.
- Explicit non-goals: not a framework, not a product, not project memory for any single repository.
- Intended users: the owner. Public for transparency.

## Architecture

- `AGENTS.md` — the canonical personal rules. Symlinked into the global tool files; see [001](decisions/001-root-agents-is-the-canonical-file.md).
- `RTK.md` — RTK output-condensing note, included from `AGENTS.md` via `@RTK.md` (Claude Code include syntax; other tools ignore the line).
- `wire.sh` — creates those global symlinks. `adopt.sh` — installs the structure into a project. Both idempotent.
- `check.sh` — reports a project against the policy. `test-check.sh` — proves each check bites.
- `subagents/` — project-agnostic Claude Code subagent definitions. `adopt.sh` copies `tech-lead.md` into every adopted project as its default session agent; see [002](decisions/002-every-adopted-project-starts-with-a-tech-lead.md).
- `templates/` — copied into adopted projects. `reference/` — long-form material, never loaded automatically by agents.

## Domain language

| Term | Meaning |
| --- | --- |
| canonical file | The root `AGENTS.md`, source of truth for personal rules. |
| adopted project | A repository carrying `AGENTS.md` + `.agents/`, installed by `adopt.sh`. |
| entry form | The per-item size limit on memory entries; measured by `check.sh`. |
| baseline | A falsifiable expectation with a date, as opposed to a run result. |

## Invariants

- The root `AGENTS.md` is read in every session of every tool: a line that does not change a decision is pure cost.
- `wire.sh` never overwrites a regular file, and `adopt.sh` never overwrites anything.
- `check.sh` only reports; nothing here edits another repository.

## Development environment

- Bash and `shellcheck`. No runtime, no package manager, no dependencies.

## Commands

```text
Install:             none
Run (global wiring): ./wire.sh
Run (adopt project): ./adopt.sh <project-dir>
Test existing suite: ./test-check.sh
Lint:                shellcheck wire.sh adopt.sh check.sh test-check.sh
Verify a project:    ./check.sh <project-dir>
```

Verificado em 2026-09-23, bash 5.3: `./test-check.sh` (21 casos verdes), `shellcheck` limpo nos quatro scripts, `./check.sh .` sem avisos.

## Conventions

- Portuguese in `README.md` and `reference/`; English in `AGENTS.md`, `templates/`, and `subagents/`, which live inside code repositories.
- Scripts are dependency-free Bash, idempotent, and must stay `shellcheck`-clean.

## External integrations

| Integration | Purpose | Contract or documentation | Failure considerations |
| --- | --- | --- | --- |
| Global tool files | Deliver the canonical rules to each tool | `wire.sh` | A tool that reads a regular file instead of a symlink is skipped, never overwritten. |

## Active architectural decisions

- [The root AGENTS.md is the canonical file, not a project file](decisions/001-root-agents-is-the-canonical-file.md)
- [Every adopted project starts with a tech lead](decisions/002-every-adopted-project-starts-with-a-tech-lead.md)

## Known constraints and pitfalls

- Editing `AGENTS.md` changes behaviour in every tool on this machine at once, with no staging step.
- `subagents/` must stay project-agnostic: no project names, stacks, paths, or decision numbers. The delegated-work commit exception in `AGENTS.md` (mirrored in the template) is what lets the tech lead's agents commit; change both together.
- `templates/AGENTS.project.md` deliberately restates rules from `AGENTS.md`; the mirrored sections are mapped in `templates/README.md` and drift silently if only one side is edited.
- The adopted `.claude/agents/tech-lead.md` is a stamped copy too; `check.sh` warns when `subagents/tech-lead.md` moved on. `mailbridgr` and `nfepack` predate the convention and stay without it.
- An adopted project keeps its own copy of the rules from the day it was adopted: fixing the template does not reach it. `adopt.sh` stamps the template commit; `check.sh` warns when the template moved on. Projects adopted before the stamp carry none.
- `check.sh` thresholds (400/1200) are calibrated on two adopted projects, not derived. Treat a failure as a question, not a verdict.

## Canonical documentation

- `README.md` (how the repository is used), `reference/PROJECT-MEMORY-POLICY.md` (the full memory policy).

## Maintenance

Update this file in the same change-set that makes it inaccurate. Git already stores the history.
