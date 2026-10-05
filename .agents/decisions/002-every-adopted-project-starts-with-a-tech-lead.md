# Architectural decision: every adopted project starts with a tech lead

- Status: accepted
- Date: 2026-10-05
- Supersedes: none
- Superseded by: none

## Context

Work in a project often splits into planning, implementation, review, and tests. Claude Code can run a subagent as the session's main agent (`agent` in `.claude/settings.json`) and start other subagents from it. A tech lead definition written for one project proved useful, but it carried that project's name, stack, and decisions.

Without a convention, each project would grow its own team from nothing, and the rules that make delegation safe (briefs, worktree branches, review loop, commit limits) would drift between projects.

## Decision

`subagents/tech-lead.md` is a project-agnostic definition. `adopt.sh` copies it to `.claude/agents/tech-lead.md` in every adopted project and sets it as the default session agent in `.claude/settings.json`.

The tech lead is the only role created at adoption. Every other role is written by the tech lead into `.claude/agents/` of the project, when the work needs it.

The delegated-work exception in `AGENTS.md` and in `templates/AGENTS.project.md` lets agents started by a brief commit on their own worktree branch, never on the default or a shared branch, never with a push.

Projects adopted before this decision do not receive the convention unless `adopt.sh` runs on them again: it creates the tech lead and the settings file wherever they are missing. Running it again is the explicit way for an older project to join.

## Alternatives considered

### Ship a full standard team at adoption

- Advantages: engineers, reviewer, and testers available from day one.
- Disadvantages: every definition's `description` costs context in every session, needed or not; generic roles fit few projects without edits.
- Reason not chosen: roles are cheaper and better fitted when hired for real work.

### Wire the tech lead globally in `~/.claude/agents/`

- Advantages: one copy, no drift.
- Disadvantages: present in every session on the machine, including projects that do not use it; not versioned with the project.
- Reason not chosen: the team belongs to the project, like its memory.

## Consequences

### Positive

- Every new project has the same planning and delegation loop from the first session.
- Team definitions are versioned with the project they serve.

### Negative or trade-offs

- Each project holds a copy; fixes to `subagents/tech-lead.md` are ported by hand. `adopt.sh` stamps the source commit and `check.sh` warns on drift.
- `adopt.sh` cannot edit an existing `.claude/settings.json` without JSON tooling; it only says what to add, or warns when another agent is set.
- A higher-precedence setting wins over the project's: `claude --agent`, `.claude/settings.local.json`, or managed settings. `check.sh` warns when the project or local settings name another agent, or when git ignores the tech lead or the settings file.
- The convention targets Claude Code; other tools read `AGENTS.md` only.

## Verification

Run `./adopt.sh` on an empty directory: it creates `.claude/agents/tech-lead.md` with a stamp and `.claude/settings.json` with `"agent": "tech-lead"`. `./check.sh` on that directory reports the tech lead as adopted from the current source.

`./test-check.sh` covers both: the adoption cases check the tech lead stamp, the settings file, and ignore rules; the check cases check tech lead drift, the session agent, and ignore rules.

## References

- `subagents/tech-lead.md`, `adopt.sh`, `check.sh`, `AGENTS.md` (Git, commits, push, and CI)
