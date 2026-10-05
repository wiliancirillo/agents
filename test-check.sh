#!/usr/bin/env bash
# Tests that check.sh actually bites.
#
#   ./test-check.sh
#
# A check that stops reading its input keeps printing `ok`, which looks exactly
# like a check that works. So every case below builds a project fixture, breaks
# exactly one thing, and asserts that check.sh reports it — plus one case that
# breaks nothing and must stay silent.
#
# Everything happens in a temporary directory. A test that mutates the working
# tree is a test nobody dares run.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILED=0
CASES=0

# Builds a project that check.sh passes cleanly.
fixture() {
  local d="$WORK/p"
  rm -rf "$d"
  mkdir -p "$d/.agents/decisions"

  cat > "$d/AGENTS.md" <<'EOF'
# Instructions for AI agents

## Repository-specific information

- Purpose: a fixture.
- Architecture: one file.
- Install command: `true`
- Run command: `true`
- Test command: `true`
EOF

  cat > "$d/.agents/PROJECT_MEMORY.md" <<'EOF'
# Project memory

## Commands

Verificado em 2026-08-24, bash 5.2: `true` (12 tests green).

## Active architectural decisions

- [Only one](decisions/001-only-one.md)
EOF

  cat > "$d/.agents/decisions/001-only-one.md" <<'EOF'
# Architectural decision: only one

- Status: accepted
- Date: 2026-08-24
EOF
  echo "$d"
}

# expect <name> <exit code> <substring the report must contain>
expect() {
  local name="$1" want_code="$2" want="$3" out code
  CASES=$((CASES + 1))
  out="$("$ROOT/check.sh" "$WORK/p" 2>&1)"; code=$?

  if [ "$code" -ne "$want_code" ]; then
    printf '  FAIL  %s — exit %d, expected %d\n' "$name" "$code" "$want_code"
    printf '%s\n' "$out" | sed 's/^/          /'
    FAILED=1
    return
  fi
  if [ -n "$want" ] && ! printf '%s' "$out" | grep -qF -- "$want"; then
    printf '  FAIL  %s — report lacks: %s\n' "$name" "$want"
    printf '%s\n' "$out" | sed 's/^/          /'
    FAILED=1
    return
  fi
  printf '  ok    %s\n' "$name"
}

echo "check.sh"

p="$(fixture)"
expect "clean fixture passes" 0 "passed with 0 warning"

p="$(fixture)"; rm "$p/AGENTS.md"
expect "missing AGENTS.md" 1 "missing"

p="$(fixture)"; rm "$p/.agents/PROJECT_MEMORY.md"
expect "missing PROJECT_MEMORY.md" 1 "missing"

p="$(fixture)"; rm -rf "$p/.agents/decisions"
expect "missing decisions/ warns only" 0 "no decision records yet"

# A freshly adopted project: decisions/ exists, nothing in it, and the memory
# links nothing. grep finds no link and exits 1; under `set -e` + `pipefail`
# that used to kill check.sh silently before the summary.
p="$(fixture)"; rm "$p/.agents/decisions/001-only-one.md"; sed -i '/^- \[Only one\]/d' "$p/.agents/PROJECT_MEMORY.md"
expect "fresh adoption with no decision links" 0 "0 decision record(s), all cross-referenced"

p="$(fixture)"; echo ".agents/" > "$p/.gitignore"
expect "memory excluded from git" 1 "must be versioned"

p="$(fixture)"; printf -- '- Purpose:\n' >> "$p/AGENTS.md"
expect "unfilled template placeholder" 1 "empty placeholders"

p="$(fixture)"; printf -- '- %s\n' "$(head -c 1300 /dev/zero | tr '\0' 'x')" >> "$p/.agents/PROJECT_MEMORY.md"
expect "entry over the hard limit" 1 "over 1200 chars"

p="$(fixture)"; printf -- '- %s\n' "$(head -c 500 /dev/zero | tr '\0' 'x')" >> "$p/.agents/PROJECT_MEMORY.md"
expect "entry over the soft limit warns" 0 "over 400 chars"

p="$(fixture)"; printf -- '- [Ghost](decisions/002-ghost.md)\n' >> "$p/.agents/PROJECT_MEMORY.md"
expect "memory links a missing record" 1 "do not exist"

p="$(fixture)"; printf -- '- Status: accepted\n' > "$p/.agents/decisions/002-orphan.md"
expect "record nobody references" 0 "never referenced"

p="$(fixture)"; sed -i '/^- Status:/d' "$p/.agents/decisions/001-only-one.md"
expect "record without a Status" 0 "no Status line"

p="$(fixture)"; sed -i 's/^Verificado.*/12 tests green, no date./' "$p/.agents/PROJECT_MEMORY.md"
expect "test baseline without a date" 0 "without a verification date"

p="$(fixture)"; printf -- 'api_key = "hunter2hunter2"\n' >> "$p/.agents/PROJECT_MEMORY.md"
expect "credential in the memory" 1 "possible credential"

p="$(fixture)"
cat >> "$p/.agents/PROJECT_MEMORY.md" <<'ENTRY'
- The list has a filter popover, a sort popover, hover quick actions on each row, an avatar checkbox for multi-select, a chip on every card and a button in the footer.
ENTRY
expect "entry that is UI inventory" 0 "feature inventory"

p="$(fixture)"
cat >> "$p/.agents/PROJECT_MEMORY.md" <<'ENTRY'
- Never do network I/O while holding the DB lock; every batch op refuses a mix of accounts before touching the cache.
ENTRY
expect "invariant is not mistaken for inventory" 0 "passed with 0 warning"

p="$(fixture)"
printf -- '- %s\n' "$(head -c 200 /dev/zero | tr '\0' 'x')" >> "$p/.agents/PROJECT_MEMORY.md"
CASES=$((CASES + 1))
# Captured, not piped: check.sh exits 1 here, and under `pipefail` a pipeline
# would carry that exit code even when grep matched.
out="$(MEM_FAIL=100 "$ROOT/check.sh" "$WORK/p" 2>&1)"
if printf '%s' "$out" | grep -qF "over 100 chars"; then
  printf '  ok    %s\n' "threshold honours MEM_FAIL"
else
  printf '  FAIL  %s — report lacks: over 100 chars\n' "threshold honours MEM_FAIL"
  printf '%s\n' "$out" | sed 's/^/          /'
  FAILED=1
fi

# Template drift. The stamps point at real commits of this repository, so the
# cases read its history instead of faking one.
current="$(git -C "$ROOT" log -1 --format=%h -- templates/AGENTS.project.md)"
first="$(git -C "$ROOT" rev-list --max-parents=0 --abbrev-commit HEAD | tail -1)"
stamp() { printf '\n<!-- adopted from templates/AGENTS.project.md @ %s -->\n' "$1" >> "$WORK/p/AGENTS.md"; }

p="$(fixture)"; stamp "$current"
expect "stamp at the current template" 0 "adopted from the current template"

p="$(fixture)"; stamp "$first"
expect "template changed since adoption warns" 0 "changed since adoption"

p="$(fixture)"; stamp deadbeef
expect "stamp at an unknown commit warns" 0 "unknown to"

# The adopted tech lead carries its own stamp, checked the same way.
lead_current="$(git -C "$ROOT" log -1 --format=%h -- subagents/tech-lead.md)"
lead() {
  mkdir -p "$WORK/p/.claude/agents"
  printf -- '---\nname: tech-lead\n---\n\n<!-- adopted from subagents/tech-lead.md @ %s -->\n' "$1" > "$WORK/p/.claude/agents/tech-lead.md"
}

p="$(fixture)"; lead "$lead_current"
expect "tech lead stamp at the current source" 0 "tech-lead.md was adopted from the current subagents/tech-lead.md"

p="$(fixture)"; lead "$first"
expect "tech lead changed since adoption warns" 0 "subagents/tech-lead.md changed since adoption"

echo
echo "adopt.sh"

CASES=$((CASES + 1))
d="$WORK/adopted"; mkdir -p "$d"
"$ROOT/adopt.sh" "$d" >/dev/null && "$ROOT/adopt.sh" "$d" >/dev/null
n="$(grep -c "adopted from templates/AGENTS.project.md @ $current" "$d/AGENTS.md")"
if [ "$n" -eq 1 ]; then
  printf '  ok    %s\n' "stamps the template commit once"
else
  printf '  FAIL  %s — found %s stamp(s), expected 1\n' "stamps the template commit once" "$n"
  FAILED=1
fi

CASES=$((CASES + 1))
n="$(grep -c "adopted from subagents/tech-lead.md @ $lead_current" "$d/.claude/agents/tech-lead.md" 2>/dev/null)"
n="${n:-0}"
if [ "$n" -eq 1 ]; then
  printf '  ok    %s\n' "stamps the tech lead commit once"
else
  printf '  FAIL  %s — found %s stamp(s), expected 1\n' "stamps the tech lead commit once" "$n"
  FAILED=1
fi

CASES=$((CASES + 1))
if grep -Eq '"agent"[[:space:]]*:[[:space:]]*"tech-lead"' "$d/.claude/settings.json" 2>/dev/null; then
  printf '  ok    %s\n' "creates settings.json with the tech lead as session agent"
else
  printf '  FAIL  %s\n' "creates settings.json with the tech lead as session agent"
  FAILED=1
fi

CASES=$((CASES + 1))
d="$WORK/configured"; mkdir -p "$d/.claude"
printf '{ "model": "opus" }\n' > "$d/.claude/settings.json"
cp "$d/.claude/settings.json" "$WORK/settings.before"
out="$("$ROOT/adopt.sh" "$d" 2>&1)"
if printf '%s' "$out" | grep -qF 'ACTION: add "agent": "tech-lead"' && cmp -s "$WORK/settings.before" "$d/.claude/settings.json"; then
  printf '  ok    %s\n' "existing settings without agent: asks, never edits"
else
  printf '  FAIL  %s\n' "existing settings without agent: asks, never edits"
  printf '%s\n' "$out" | sed 's/^/          /'
  FAILED=1
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "$CASES cases, all passed"
  exit 0
fi
echo "$CASES cases, failures above"
exit 1
