#!/usr/bin/env bash
# Test bin/install.sh: --global a idempotencia, projektová inštalácia.
# Všetko beží s HOME v dočasnom priečinku, skutočné ~/.claude sa nemení.
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
SRC=$(cd "$HERE/../.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_NOSYSTEM=1
unset AGENTIC_BRAIN_GLOBAL

FAILS=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; FAILS=$((FAILS + 1)); }
check() { # popis príkaz...
  local d=$1; shift
  if "$@"; then ok "$d"; else bad "$d"; fi
}
snapshot() { # strom pod $1: cesty, ciele symlinkov, obsah
  (cd "$1" && find . -print0 | sort -z | xargs -0 ls -ld | awk '{ $6 = $7 = $8 = ""; print }' && find . -type f -print0 | sort -z | xargs -0 cat | cksum)
}

# 1. global, zanorený mozog (klon šablóny v ~/agentic-brain)
H1="$TMP/h1"; mkdir -p "$H1/.claude"
cp -a "$SRC" "$H1/agentic-brain"; rm -rf "$H1/agentic-brain/.git"
printf 'moje pravidlo' > "$H1/.claude/CLAUDE.md"
mkdir -p "$H1/.claude/skills/chyba"; printf 'cudzie\n' > "$H1/.claude/skills/chyba/SKILL.md"
ln -s /tmp/niekde "$H1/.claude/skills/koniec-ulohy"
OUT=$(HOME="$H1" bash "$H1/agentic-brain/agentic-brain/bin/install.sh" --global 2>&1); RC=$?
check "global: skončí kódom 0" test "$RC" -eq 0
check "global: pôvodný obsah CLAUDE.md ostal" grep -qx 'moje pravidlo' "$H1/.claude/CLAUDE.md"
check "global: import pridaný raz" test "$(grep -cxF '@~/agentic-brain/agentic-brain/RULES.md' "$H1/.claude/CLAUDE.md")" -eq 1
check "global: cudzí priečinok ostal" test "$(cat "$H1/.claude/skills/chyba/SKILL.md")" = cudzie
check "global: cudzí symlink ostal" test "$(readlink "$H1/.claude/skills/koniec-ulohy")" = /tmp/niekde
check "global: výpis hlási preskočenie" bash -c 'printf "%s" "$1" | grep -q "Preskočené"' _ "$OUT"

# 2. global, čistý HOME a idempotencia
H2="$TMP/h2"; mkdir -p "$H2"
cp -a "$SRC" "$H2/agentic-brain"; rm -rf "$H2/agentic-brain/.git"
HOME="$H2" bash "$H2/agentic-brain/agentic-brain/bin/install.sh" --global > "$TMP/g1.out" 2>&1
check "global: symlink chyba ukazuje do klonu" test "$(readlink "$H2/.claude/skills/chyba")" = "$H2/agentic-brain/agentic-brain/skills/chyba"
check "global: symlink koniec-ulohy existuje" test -L "$H2/.claude/skills/koniec-ulohy"
check "global: skill je dosiahnuteľný cez symlink" test -f "$H2/.claude/skills/chyba/SKILL.md"
A=$(snapshot "$H2")
HOME="$H2" bash "$H2/agentic-brain/agentic-brain/bin/install.sh" --global > "$TMP/g2.out" 2>&1
B=$(snapshot "$H2")
check "global: druhý beh nič nezmení" test "$A" = "$B"
check "global: import je v CLAUDE.md raz" test "$(grep -c RULES.md "$H2/.claude/CLAUDE.md")" -eq 1

# 3. global, plochý mozog (koreň repa je mozog), cesta presne podľa návrhu
H3="$TMP/h3"; mkdir -p "$H3/agentic-brain"
cp -a "$SRC/agentic-brain/." "$H3/agentic-brain/"
HOME="$H3" bash "$H3/agentic-brain/bin/install.sh" --global > "$TMP/f1.out" 2>&1
check "plochý global: import @~/agentic-brain/RULES.md" grep -qxF '@~/agentic-brain/RULES.md' "$H3/.claude/CLAUDE.md"
check "plochý global: symlink na skill" test "$(readlink "$H3/.claude/skills/chyba")" = "$H3/agentic-brain/skills/chyba"

# 4. projektová inštalácia
P="$TMP/projekt"; mkdir -p "$P"
cp -a "$SRC/." "$P/"; rm -rf "$P/.git"; git -C "$P" init -q
rm "$P/.claude/skills/chyba"
HOME="$TMP/h4" bash "$P/agentic-brain/bin/install.sh" > "$TMP/p1.out" 2>&1; RC=$?
check "projekt: skončí kódom 0" test "$RC" -eq 0
check "projekt: symlink obnovený" test "$(readlink "$P/.claude/skills/chyba")" = "../../agentic-brain/skills/chyba"
check "projekt: hook nainštalovaný" test -x "$P/.git/hooks/pre-commit"
HOME="$TMP/h4" bash "$P/agentic-brain/bin/install.sh" > "$TMP/p2.out" 2>&1; RC=$?
check "projekt: druhý beh prejde" test "$RC" -eq 0

echo
if [ "$FAILS" -gt 0 ]; then echo "install.test.sh: $FAILS zlyhaní"; exit 1; fi
echo "install.test.sh: všetko prešlo"
