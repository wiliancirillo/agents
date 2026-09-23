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

if [ "$created_any" -eq 1 ]; then
  echo "done. Now fill in:"
  echo "  - $DEST/AGENTS.md (Repository-specific information and rules; remove placeholders)"
  echo "  - $DEST/.agents/PROJECT_MEMORY.md (verified facts only)"
else
  echo "done. Nothing to create — this project is already adopted."
fi
