#!/usr/bin/env bash
# Test bin/adopt.sh: nasadenie do existujúceho repa bez prepísania a bez commitu.
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

# repo s existujúcim obsahom
T1="$TMP/r1"; mkdir -p "$T1/agentic-brain" "$T1/.claude"
git -C "$T1" init -q
printf '# Môj projekt\nPravidlo A\n' > "$T1/CLAUDE.md"
printf 'node_modules\n' > "$T1/.gitignore"
printf 'vlastné pravidlá\n' > "$T1/agentic-brain/RULES.md"
printf '{"permissions":{}}\n' > "$T1/.claude/settings.json"
printf 'x\n' > "$T1/f.txt"
git -C "$T1" add -A; $GC -C "$T1" commit -qm start
BEFORE=$(git -C "$T1" rev-list --all --count)

OUT=$(bash "$SRC/agentic-brain/bin/adopt.sh" "$T1" 2>&1); RC=$?
check "adopt: kód 0" test "$RC" -eq 0
check "adopt: pôvodný CLAUDE.md ostal na začiatku" test "$(head -n 2 "$T1/CLAUDE.md")" = "$(printf '# Môj projekt\nPravidlo A')"
check "adopt: riadok importu pribudol raz" test "$(grep -cxF '@agentic-brain/RULES.md' "$T1/CLAUDE.md")" -eq 1
check "adopt: AGENTS.md založený ako kópia CLAUDE.md" cmp -s "$T1/CLAUDE.md" "$T1/AGENTS.md"
check "adopt: výpis hlási kópiu" has "$OUT" "Založený AGENTS.md ako kópia CLAUDE.md"
check "adopt: existujúci RULES.md neprepísaný" test "$(cat "$T1/agentic-brain/RULES.md")" = "vlastné pravidlá"
check "adopt: výpis hlási preskočený RULES.md" has "$OUT" "Preskočené, už existuje: agentic-brain/RULES.md"
check "adopt: skill skopírovaný" test -f "$T1/agentic-brain/skills/chyba/scripts/chyba.sh"
check "adopt: symlink skillu" test "$(readlink "$T1/.claude/skills/chyba")" = "../../agentic-brain/skills/chyba"
check "adopt: existujúci settings.json ostal" test "$(cat "$T1/.claude/settings.json")" = '{"permissions":{}}'
check "adopt: výpis radí, čo pridať do settings.json" has "$OUT" "repeat_guard.mjs"
check "adopt: .gitignore ostal s pôvodným riadkom" grep -qxF 'node_modules' "$T1/.gitignore"
check "adopt: .gitignore má riadok pre scratch" grep -qxF 'agentic-brain/scratch/*' "$T1/.gitignore"
check "adopt: scratch/.gitkeep skopírovaný" test -f "$T1/agentic-brain/scratch/.gitkeep"
check "adopt: nič necommitoval" test "$(git -C "$T1" rev-list --all --count)" = "$BEFORE"
check "adopt: bez varovania o rozdiele, súbory sú rovnaké" test "$(printf '%s' "$OUT" | grep -c 'sa líšia')" -eq 0
check "adopt: check.sh v cieli prejde" bash "$T1/agentic-brain/bin/check.sh"

A=$(cd "$T1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 cat | cksum)
bash "$SRC/agentic-brain/bin/adopt.sh" "$T1" > /dev/null 2>&1
B=$(cd "$T1" && find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 cat | cksum)
check "adopt: druhý beh nič nezmení" test "$A" = "$B"

# prázdne repo bez CLAUDE.md a settings.json, potom check.sh musí prejsť
T2="$TMP/r2"; mkdir -p "$T2"; git -C "$T2" init -q
OUT=$(bash "$SRC/agentic-brain/bin/adopt.sh" "$T2" 2>&1); RC=$?
check "adopt (prázdne repo): kód 0" test "$RC" -eq 0
check "adopt (prázdne repo): CLAUDE.md a AGENTS.md rovnaké" cmp -s "$T2/CLAUDE.md" "$T2/AGENTS.md"
check "adopt (prázdne repo): settings.json rovnaký ako v šablóne" cmp -s "$T2/.claude/settings.json" "$SRC/.claude/settings.json"
check "adopt (prázdne repo): check.sh prejde" bash "$T2/agentic-brain/bin/check.sh"

# repo, kde CLAUDE.md a AGENTS.md už existujú a líšia sa
T4="$TMP/r4"; mkdir -p "$T4"; git -C "$T4" init -q
printf 'A\n' > "$T4/CLAUDE.md"; printf 'B\n' > "$T4/AGENTS.md"
OUT=$(bash "$SRC/agentic-brain/bin/adopt.sh" "$T4" 2>&1)
check "adopt (rôzne súbory): výpis hlási rozdiel" has "$OUT" "sa líšia"
check "adopt (rôzne súbory): import v oboch" test "$(grep -lxF '@agentic-brain/RULES.md' "$T4/CLAUDE.md" "$T4/AGENTS.md" | wc -l)" -eq 2

# cieľ, ktorý nie je git repo
T3="$TMP/r3"; mkdir -p "$T3"
bash "$SRC/agentic-brain/bin/adopt.sh" "$T3" > /dev/null 2>&1; RC=$?
check "adopt: priečinok bez gitu je chyba" test "$RC" -eq 1

echo
if [ "$FAILS" -gt 0 ]; then echo "adopt.test.sh: $FAILS zlyhaní"; exit 1; fi
echo "adopt.test.sh: všetko prešlo"
