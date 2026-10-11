# Architectural decision: Hermes gets the rules as an auto-loaded skill

- Status: accepted
- Date: 2026-10-11
- Supersedes: none
- Superseded by: none

## Context

Claude Code, Codex CLI, and Gemini CLI read a global instruction file, so `wire.sh` symlinks it to the canonical `AGENTS.md`. Hermes has no such file. It loads `AGENTS.md` only from the current working directory, and its one global file, `SOUL.md`, holds the persona: symlinking it would replace the persona.

`wire.sh` used to append a one-line pointer to `SOUL.md` asking the model to read the canonical file. That pointer puts no rule in the context; it works only if the model obeys it and spends a tool call at the start of every session.

Hermes injects every skill listed in `skills.auto_load` into the system prompt of each new session, on every surface.

## Decision

`wire.sh` generates the skill `$HERMES_HOME/skills/personal/agents-rules/SKILL.md` from `AGENTS.md` with `RTK.md` inlined, because Hermes does not resolve the `@RTK.md` include. It then adds `agents-rules` to `skills.auto_load` through `hermes config set`, keeping the existing entries.

The generated file carries a marker and the SHA-256 of its sources. `wire.sh` overwrites it only when the marker is present and the hash differs; a file without the marker is reported and left alone. The old `SOUL.md` pointer is reported as obsolete, never edited.

## Alternatives considered

### Keep the SOUL.md pointer

- Advantages: one line, nothing to keep in sync.
- Disadvantages: the rules reach the model only if it chooses to read them.
- Reason not chosen: the delivery is not guaranteed, which is the whole point of wiring.

### Concatenate the rules into SOUL.md

- Advantages: always loaded.
- Disadvantages: mixes persona and rules in one file, and `wire.sh` would have to rewrite a regular file it does not own.
- Reason not chosen: breaks the rule that `wire.sh` never overwrites a file it did not create.

### A `pre_llm_call` plugin that reads the file live

- Advantages: never stale.
- Disadvantages: code to maintain against a hook API not verified here.
- Reason not chosen: more moving parts than the problem needs.

## Consequences

### Positive

- Every new Hermes session carries the rules in its system prompt, in any directory.
- Re-running `wire.sh` is idempotent: an unchanged source reports `ok (up to date)`.

### Negative or trade-offs

- The skill is a copy. Editing `AGENTS.md` or `RTK.md` does not reach Hermes until `./wire.sh` runs again.
- The rules cost context in every Hermes session, as they already do in the other tools.

## Verification

Run `./wire.sh`, then `hermes config get skills.auto_load` lists `agents-rules`. A fresh session outside any repository, `hermes chat -Q -q "<ask for a rule from AGENTS.md>"`, quotes it without reading a file.

## References

- `wire.sh`, `README.md`
