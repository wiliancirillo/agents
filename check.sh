#!/usr/bin/env bash
# Checks a project's agent-instruction files against the policy.
# Read-only: reports, never edits. Exit 1 on error, 0 on warnings only.
#
#   ./check.sh <project-dir>
#
# Thresholds can be overridden:
#   MEM_WARN=400 MEM_FAIL=1200 ./check.sh <project-dir>
set -euo pipefail

DEST="${1:?usage: check.sh <project-dir>}"
DEST="$(cd "$DEST" && pwd)"
MEM_WARN="${MEM_WARN:-400}"
MEM_FAIL="${MEM_FAIL:-1200}"

errors=0
warnings=0

indent() { while IFS= read -r l; do [ -n "$l" ] && printf '        %s\n' "$l"; done; }
err()  { echo "FAIL: $*"; errors=$((errors + 1)); }
warn() { echo "WARN: $*"; warnings=$((warnings + 1)); }
ok()   { echo "ok:   $*"; }

AGENTS="$DEST/AGENTS.md"
MEM="$DEST/.agents/PROJECT_MEMORY.md"
DECISIONS="$DEST/.agents/decisions"

# --- structure ---------------------------------------------------------------
[ -f "$AGENTS" ] || err "missing $AGENTS"
[ -f "$MEM" ]    || err "missing $MEM"
[ -d "$DECISIONS" ] || warn "missing $DECISIONS (no decision records yet)"

if [ -f "$DEST/.gitignore" ] && grep -Eq '(^|/)\.agents' "$DEST/.gitignore"; then
  err ".agents is in .gitignore — the memory must be versioned"
fi

[ "$errors" -eq 0 ] || { echo; echo "$errors error(s), $warnings warning(s)"; exit 1; }

# --- placeholders left behind ------------------------------------------------
if grep -qE '^- (Purpose|Architecture|Install command|Run command|Test command):\s*$' "$AGENTS"; then
  err "$AGENTS still has empty placeholders from the template"
else
  ok "AGENTS.md has no empty template placeholders"
fi

if grep -q 'Replace this section with actual project details' "$AGENTS"; then
  warn "$AGENTS still carries the template's instruction line"
fi

# --- entry form (policy: one fact with a pointer, ~300 chars) ----------------
long_warn=$(awk -v n="$MEM_WARN" 'length($0) > n' "$MEM" | wc -l)
long_fail=$(awk -v n="$MEM_FAIL" 'length($0) > n' "$MEM" | wc -l)

if [ "$long_fail" -gt 0 ]; then
  err "$long_fail memory line(s) over $MEM_FAIL chars — split into decisions/ or module docs"
  awk -v n="$MEM_FAIL" 'length($0) > n {printf "        line %d: %d chars | %.60s...\n", NR, length($0), $0}' "$MEM"
elif [ "$long_warn" -gt 0 ]; then
  warn "$long_warn memory line(s) over $MEM_WARN chars"
else
  ok "every memory entry is within $MEM_WARN chars"
fi

# --- feature inventory (policy: what the UI does today is read from the code) -
# Heuristic and deliberately conservative: an entry naming several interface
# widgets at once is describing what the screen has, not what is true about the
# project. It warns, never fails — only a reader can tell the two apart.
inventory=$(awk '
  {
    line = tolower($0)
    n = 0
    split("popover tooltip chevron checkbox dropdown hover click drag chip badge button toolbar sidebar modal placeholder scrollbar", w, " ")
    for (i in w) if (index(line, w[i]) > 0) n++
    if (n >= 4) printf "        line %d: %d widget words | %.60s...\n", NR, n, $0
  }' "$MEM")

if [ -n "$inventory" ]; then
  warn "$(printf '%s' "$inventory" | grep -c .) entry/entries read like feature inventory — what the UI has today is read from the code, not the memory"
  printf '%s\n' "$inventory"
else
  ok "no entry reads like feature inventory"
fi

# --- decision records: referential integrity ---------------------------------
if [ -d "$DECISIONS" ]; then
  files=$(find "$DECISIONS" -maxdepth 1 -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort)
  linked=$(grep -oE 'decisions/[0-9]{3}-[a-z0-9-]+\.md' "$MEM" | sed 's|decisions/||;s|\.md$||' | sort -u || true)

  orphans=$(comm -23 <(echo "$files") <(echo "$linked") | grep -v '^$' || true)
  broken=$(comm -13 <(echo "$files") <(echo "$linked") | grep -v '^$' || true)

  if [ -n "$broken" ]; then
    err "memory links to decision records that do not exist:"
    echo "$broken" | indent
  fi
  if [ -n "$orphans" ]; then
    warn "decision records never referenced from the memory:"
    echo "$orphans" | indent
  fi
  [ -z "$broken$orphans" ] && ok "$(echo "$files" | grep -c .) decision record(s), all cross-referenced"

  # a record without Status/Date is not usable later
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -q '^- Status:' "$DECISIONS/$f.md" || warn "$f.md has no Status line"
    grep -q '^- Date:'   "$DECISIONS/$f.md" || warn "$f.md has no Date line"
  done <<< "$files"
fi

# --- baselines must carry a date (policy: baseline vs run result) ------------
if grep -qiE '(tests? (green|passing)|testes verdes|[0-9]+ (tests?|testes))' "$MEM"; then
  if grep -qiE '(verified|verificado)[^.]{0,40}20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$MEM"; then
    ok "test baseline carries a verification date"
  else
    warn "the memory states a test count without a verification date — a baseline without a date is a run result"
  fi
fi

# --- template drift (adopt.sh stamps the source commit it copied) ----------
# Adopted copies never update by themselves. Files adopted before the stamp
# existed carry none and are skipped.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# drift <adopted file> <source path inside this repository>
drift() {
  local file="$1" src="$2" name rev changed
  name="${file#"$DEST"/}"
  [ -f "$file" ] || return 0
  rev="$(grep -oE "adopted from ${src//./\\.} @ [0-9a-f]+" "$file" | head -1 | awk '{print $NF}' || true)"
  [ -n "$rev" ] && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 0
  if ! git -C "$ROOT" cat-file -e "$rev^{commit}" 2>/dev/null; then
    warn "$name was adopted from commit $rev, unknown to $ROOT"
    return 0
  fi
  changed="$(git -C "$ROOT" log --oneline "$rev..HEAD" -- "$src")"
  if [ -n "$changed" ]; then
    warn "$src changed since adoption ($rev) — port by hand into $name:"
    echo "$changed" | indent
  else
    ok "$name was adopted from the current $src ($rev)"
  fi
}

drift "$AGENTS" templates/AGENTS.project.md
drift "$DEST/.claude/agents/tech-lead.md" subagents/tech-lead.md

# --- tech lead as session agent ----------------------------------------------
# Only for projects that carry the tech lead; older adoptions are left alone.
# agent_of <settings file>: the string value of "agent", empty when unset.
agent_of() {
  grep -oE '"agent"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null | head -1 | sed -E 's/.*"([^"]*)"$/\1/' || true
}

LEAD="$DEST/.claude/agents/tech-lead.md"
SETTINGS="$DEST/.claude/settings.json"
LOCAL="$DEST/.claude/settings.local.json"
if [ -f "$LEAD" ]; then
  agent="$(agent_of "$SETTINGS")"
  if [ ! -f "$SETTINGS" ]; then
    warn ".claude/settings.json is missing — the tech lead is not the session agent"
  elif [ -z "$agent" ]; then
    warn '.claude/settings.json does not set "agent" — the tech lead is not the session agent'
  elif [ "$agent" != "tech-lead" ]; then
    warn ".claude/settings.json sets agent \"$agent\", not \"tech-lead\""
  else
    ok "tech-lead is the session agent"
  fi

  local_agent="$(agent_of "$LOCAL")"
  if [ -n "$local_agent" ] && [ "$local_agent" != "tech-lead" ]; then
    warn ".claude/settings.local.json overrides the session agent with \"$local_agent\""
  fi

  # Tracked files are never reported: they are versioned whatever the rules say.
  if git -C "$DEST" rev-parse --git-dir >/dev/null 2>&1; then
    for f in .claude/agents/tech-lead.md .claude/settings.json; do
      if git -C "$DEST" check-ignore -q "$f"; then
        warn "git ignores $f — version it so every clone starts with the tech lead"
      fi
    done
  fi
fi

# --- secrets -----------------------------------------------------------------
if grep -rInE '(password|secret|api[_-]?key|token)\s*[:=]\s*["'"'"'][^"'"'"']{8,}' "$AGENTS" "$MEM" >/dev/null 2>&1; then
  err "possible credential in AGENTS.md or PROJECT_MEMORY.md"
else
  ok "no credential-shaped strings in the instruction files"
fi

echo
if [ "$errors" -gt 0 ]; then
  echo "$errors error(s), $warnings warning(s)"
  exit 1
fi
echo "passed with $warnings warning(s)"
