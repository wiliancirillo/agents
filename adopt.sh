#!/usr/bin/env bash
# Adopts the agent-instructions structure in a project.
# Idempotent: never overwrites existing files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:?usage: adopt.sh <project-dir>}"
DEST="$(cd "$DEST" && pwd)"

created_any=0

copy() {
  local src="$1" dst="$2"
  if [ -e "$dst" ]; then
    echo "SKIP (exists): $dst"
    return 1
  else
    cp "$src" "$dst"
    created_any=1
    echo "created: $dst"
  fi
}

mkdir -p "$DEST/.agents/decisions"
# The stamp records which template commit the project copied, so check.sh can
# tell when the template moved on. The copy never updates by itself.
if copy "$ROOT/templates/AGENTS.project.md" "$DEST/AGENTS.md"; then
  rev="$(git -C "$ROOT" log -1 --format=%h -- templates/AGENTS.project.md 2>/dev/null || true)"
  [ -n "$rev" ] && printf '\n<!-- adopted from templates/AGENTS.project.md @ %s -->\n' "$rev" >> "$DEST/AGENTS.md"
fi
copy "$ROOT/templates/PROJECT_MEMORY.md" "$DEST/.agents/PROJECT_MEMORY.md" || true

# Every adopted project starts with the tech lead as its default session agent.
# Other roles are hired by the tech lead itself, when the work needs them.
mkdir -p "$DEST/.claude/agents"
if copy "$ROOT/subagents/tech-lead.md" "$DEST/.claude/agents/tech-lead.md"; then
  rev="$(git -C "$ROOT" log -1 --format=%h -- subagents/tech-lead.md 2>/dev/null || true)"
  [ -n "$rev" ] && printf '\n<!-- adopted from subagents/tech-lead.md @ %s -->\n' "$rev" >> "$DEST/.claude/agents/tech-lead.md"
fi

# No JSON tooling here (dependency-free Bash): create the settings file when it
# is missing, otherwise only say what to add.
SETTINGS="$DEST/.claude/settings.json"
if [ ! -e "$SETTINGS" ]; then
  printf '{\n  "agent": "tech-lead"\n}\n' > "$SETTINGS"
  created_any=1
  echo "created: $SETTINGS"
elif grep -Eq '"agent"[[:space:]]*:' "$SETTINGS"; then
  agent="$(grep -oE '"agent"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS" | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || true)"
  if [ "$agent" = "tech-lead" ]; then
    echo "SKIP (agent already set): $SETTINGS"
  else
    echo "WARNING: $SETTINGS sets agent \"$agent\", not \"tech-lead\" — left unchanged."
  fi
else
  echo "ACTION: add \"agent\": \"tech-lead\" to $SETTINGS by hand."
fi

if [ -e "$DEST/CLAUDE.md" ] || [ -L "$DEST/CLAUDE.md" ]; then
  echo "SKIP (exists): $DEST/CLAUDE.md"
else
  ln -s AGENTS.md "$DEST/CLAUDE.md"
  created_any=1
  echo "linked:  $DEST/CLAUDE.md -> AGENTS.md"
fi

if [ -f "$DEST/.gitignore" ] && grep -Eq '(^|/)\.agents' "$DEST/.gitignore"; then
  echo "WARNING: .agents appears in $DEST/.gitignore — remove it so the memory is versioned."
fi
# git knows every ignore rule (nested files, globs, negations); outside a git
# repository, fall back to the obvious pattern.
if git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1; then
  for f in .claude/agents/tech-lead.md .claude/settings.json; do
    if git -C "$DEST" check-ignore -q "$f"; then
      echo "WARNING: git ignores $f in $DEST — version it so every clone starts with the tech lead."
    fi
  done
elif [ -f "$DEST/.gitignore" ] && grep -Eq '^/?\.claude/?(\*)?$' "$DEST/.gitignore"; then
  echo "WARNING: .claude is in $DEST/.gitignore — version .claude/agents/ and .claude/settings.json."
fi

if [ "$created_any" -eq 1 ]; then
  echo "done. Now fill in:"
  echo "  - $DEST/AGENTS.md (Repository-specific information and rules; remove placeholders)"
  echo "  - $DEST/.agents/PROJECT_MEMORY.md (verified facts only)"
  echo "  - $DEST/.claude/agents/tech-lead.md (only if the project needs more than the generic lead)"
else
  echo "done. Nothing to create — this project is already adopted."
fi
