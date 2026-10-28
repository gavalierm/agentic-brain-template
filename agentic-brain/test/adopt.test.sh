#!/usr/bin/env bash
# Test of bin/adopt.sh: rollout into an existing repo without overwriting and without a commit.
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
SRC=$(cd "$HERE/../.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1
unset AGENTIC_BRAIN_GLOBAL

FAILS=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; FAILS=$((FAILS + 1)); }
check() { local d=$1; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
has() { printf '%s' "$1" | grep -q -- "$2"; }

GC="git -c user.name=t -c user.email=t@example.org"

# repo with existing content
T1="$TMP/r1"; mkdir -p "$T1/agentic-brain" "$T1/.claude"
git -C "$T1" init -q
printf '# My project\nRule A\n' > "$T1/CLAUDE.md"
printf 'node_modules\n' > "$T1/.gitignore"
printf 'own rules\n' > "$T1/agentic-brain/RULES.md"
printf '{"permissions":{}}\n' > "$T1/.claude/settings.json"
printf 'x\n' > "$T1/f.txt"
git -C "$T1" add -A; $GC -C "$T1" commit -qm start
BEFORE=$(git -C "$T1" rev-list --all --count)

OUT=$(bash "$SRC/agentic-brain/bin/adopt.sh" "$T1" 2>&1); RC=$?
check "adopt: exit code 0" test "$RC" -eq 0
check "adopt: original CLAUDE.md stayed at the start" test "$(head -n 2 "$T1/CLAUDE.md")" = "$(printf '# My project\nRule A')"
check "adopt: import line added once" test "$(grep -cxF '@agentic-brain/RULES.md' "$T1/CLAUDE.md")" -eq 1
check "adopt: AGENTS.md created as a copy of CLAUDE.md" cmp -s "$T1/CLAUDE.md" "$T1/AGENTS.md"
check "adopt: output reports the copy" has "$OUT" "Created AGENTS.md as a copy of CLAUDE.md"
check "adopt: existing RULES.md not overwritten" test "$(cat "$T1/agentic-brain/RULES.md")" = "own rules"
check "adopt: output reports the skipped RULES.md" has "$OUT" "Skipped, already exists: agentic-brain/RULES.md"
check "adopt: skill copied" test -f "$T1/agentic-brain/skills/error/scripts/error.sh"
check "adopt: skill symlink" test "$(readlink "$T1/.claude/skills/error")" = "../../agentic-brain/skills/error"
check "adopt: existing settings.json stayed" test "$(cat "$T1/.claude/settings.json")" = '{"permissions":{}}'
check "adopt: output says what to add to settings.json" has "$OUT" "repeat_guard.mjs"
check "adopt: .gitignore kept the original line" grep -qxF 'node_modules' "$T1/.gitignore"
check "adopt: .gitignore has the scratch line" grep -qxF 'agentic-brain/scratch/*' "$T1/.gitignore"
check "adopt: scratch/.gitkeep copied" test -f "$T1/agentic-brain/scratch/.gitkeep"
check "adopt: committed nothing" test "$(git -C "$T1" rev-list --all --count)" = "$BEFORE"
check "adopt: no warning about a difference, files are identical" test "$(printf '%s' "$OUT" | grep -c 'differ')" -eq 0
check "adopt: check.sh passes in the target" bash "$T1/agentic-brain/bin/check.sh"

A=$(cd "$T1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 cat | cksum)
bash "$SRC/agentic-brain/bin/adopt.sh" "$T1" > /dev/null 2>&1
B=$(cd "$T1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 cat | cksum)
check "adopt: second run changes nothing" test "$A" = "$B"

# empty repo without CLAUDE.md and settings.json, check.sh must pass afterwards
T2="$TMP/r2"; mkdir -p "$T2"; git -C "$T2" init -q
OUT=$(bash "$SRC/agentic-brain/bin/adopt.sh" "$T2" 2>&1); RC=$?
check "adopt (empty repo): exit code 0" test "$RC" -eq 0
check "adopt (empty repo): CLAUDE.md and AGENTS.md identical" cmp -s "$T2/CLAUDE.md" "$T2/AGENTS.md"
check "adopt (empty repo): settings.json same as in the template" cmp -s "$T2/.claude/settings.json" "$SRC/.claude/settings.json"
check "adopt (empty repo): check.sh passes" bash "$T2/agentic-brain/bin/check.sh"

# repo where CLAUDE.md and AGENTS.md already exist and differ
T4="$TMP/r4"; mkdir -p "$T4"; git -C "$T4" init -q
printf 'A\n' > "$T4/CLAUDE.md"; printf 'B\n' > "$T4/AGENTS.md"
OUT=$(bash "$SRC/agentic-brain/bin/adopt.sh" "$T4" 2>&1)
check "adopt (different files): output reports the difference" has "$OUT" "differ"
check "adopt (different files): import in both" test "$(grep -lxF '@agentic-brain/RULES.md' "$T4/CLAUDE.md" "$T4/AGENTS.md" | wc -l)" -eq 2

# target that is not a git repo
T3="$TMP/r3"; mkdir -p "$T3"
bash "$SRC/agentic-brain/bin/adopt.sh" "$T3" > /dev/null 2>&1; RC=$?
check "adopt: folder without git is an error" test "$RC" -eq 1

echo
if [ "$FAILS" -gt 0 ]; then echo "adopt.test.sh: $FAILS failures"; exit 1; fi
echo "adopt.test.sh: all passed"
