#!/usr/bin/env bash
# Test bin/check.sh: šablóna prejde, každé pravidlo pokazené zlyhá so správnou hláškou.
# Beží v dočasnom priečinku s vlastným HOME, na skutočný HOME nesiaha.
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
SRC=$(cd "$HERE/../.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1
unset AGENTIC_BRAIN_GLOBAL

N=0; FAILS=0; W=""; OUT=""; RC=0

fresh() {
  N=$((N + 1)); W="$TMP/w$N"
  mkdir -p "$W"
  cp -a "$SRC/." "$W/"
  rm -rf "$W/.git"
  git -C "$W" init -q
}
run_check() { OUT=$(cd "${1:-$W}" && bash agentic-brain/bin/check.sh 2>&1); RC=$?; }
expect() { # popis kód regex
  if [ "$RC" -eq "$2" ] && printf '%s' "$OUT" | grep -qE "$3"; then
    echo "ok   $1"
  else
    echo "FAIL $1 (kód $RC, čakal som $2 a /$3/)"
    printf '%s\n' "$OUT" | sed 's/^/     /'
    FAILS=$((FAILS + 1))
  fi
}
expect_true() { # popis príkaz...
  local d=$1; shift
  if "$@"; then echo "ok   $d"; else echo "FAIL $d"; FAILS=$((FAILS + 1)); fi
}

fresh; run_check
expect "šablóna prejde" 0 "v poriadku"

fresh; (cd "$W/agentic-brain/memory" && bash ../bin/check.sh >/dev/null 2>&1); RC=$?; OUT=x
expect "beží aj z podpriečinka" 0 x

# symlinky
fresh; rm "$W/.claude/skills/chyba"; run_check
expect "chýbajúci symlink sa vytvorí" 0 "VYTVORENÝ symlink .claude/skills/chyba"
expect_true "vytvorený symlink ukazuje na skill" test "$(readlink "$W/.claude/skills/chyba")" = "../../agentic-brain/skills/chyba"
run_check
expect "druhý beh nič nevypíše o symlinkoch" 0 "^check.sh: v poriadku$"

fresh; ln -s ../../agentic-brain/skills/stary "$W/.claude/skills/stary"; run_check
expect "visiaci symlink sa zmaže" 0 "ZMAZANÝ visiaci symlink .claude/skills/stary"
expect_true "visiaci symlink je preč" test ! -L "$W/.claude/skills/stary"

fresh; mkdir "$W/.claude/skills/cudzi"; run_check
expect "iná položka bez skillu je chyba" 1 "CHYBA .claude/skills/cudzi"

fresh; rm "$W/.claude/skills/chyba"; mkdir "$W/.claude/skills/chyba"; run_check
expect "adresár namiesto symlinku je chyba" 1 "CHYBA .claude/skills/chyba: nie je symlink"

fresh; mkdir -p "$W/agentic-brain/skills/novy/scripts"
printf -- '---\nname: novy\ndescription: Použi, keď treba nový skill.\n---\n' > "$W/agentic-brain/skills/novy/SKILL.md"
printf '#!/usr/bin/env bash\ntrue\n' > "$W/agentic-brain/skills/novy/scripts/a.sh"
run_check
expect "nový skill dostane symlink" 0 "VYTVORENÝ symlink .claude/skills/novy"

# skilly
fresh; rm -rf "$W/agentic-brain/skills/chyba/scripts"; run_check
expect "skill bez scripts" 1 "CHYBA agentic-brain/skills/chyba/scripts: chýba scripts/"

fresh; rm "$W/agentic-brain/skills/chyba/scripts/chyba.sh"; touch "$W/agentic-brain/skills/chyba/scripts/.gitkeep"; run_check
expect "skill s prázdnym scripts" 1 "CHYBA agentic-brain/skills/chyba/scripts"

fresh; printf -- '---\nname: chyba\n---\n' > "$W/agentic-brain/skills/chyba/SKILL.md"; run_check
expect "skill bez description" 1 "CHYBA agentic-brain/skills/chyba/SKILL.md: frontmatter nemá description"

fresh; rm "$W/agentic-brain/skills/chyba/SKILL.md"; run_check
expect "skill bez SKILL.md" 1 "chýba SKILL.md"

# register chýb
fresh; bash "$W/agentic-brain/skills/chyba/scripts/chyba.sh" trieda1 "prvý výskyt" > "$TMP/c1.out"; run_check
expect "jedna otvorená chyba je len upozornenie" 0 "UPOZORNENIE .*trieda trieda1 je otvorená"
bash "$W/agentic-brain/skills/chyba/scripts/chyba.sh" trieda1 "druhý výskyt" > "$TMP/c2.out"; run_check
expect "duplicitná chyba bez opravy" 1 "CHYBA agentic-brain/errors/REGISTER.md: trieda trieda1 má 2 riadkov bez opravy"
expect_true "chyba.sh vypíše výskyt triedy" grep -q 'Výskyt triedy "trieda1": 2' "$TMP/c2.out"

fresh
printf '%s\n' '| 2026-01-01 | t | a | opravené | test |' '| 2026-01-02 | t | b | opravené | test |' >> "$W/agentic-brain/errors/REGISTER.md"; run_check
expect "chyby s vyplnenou opravou prejdú" 0 "v poriadku"

# scratch
fresh; touch "$W/agentic-brain/scratch/poznamky.txt"; run_check
expect "scratch neprázdny" 1 "CHYBA agentic-brain/scratch/poznamky.txt: scratch nie je prázdny"

# pamäť
fresh; printf -- '- [Chýba](nie-je.md): háčik\n' >> "$W/agentic-brain/memory/MEMORY.md"; run_check
expect "MEMORY.md ukazuje na neexistujúci súbor" 1 "CHYBA agentic-brain/memory/MEMORY.md: riadok ukazuje na neexistujúci súbor memory/nie-je.md"

fresh; printf 'obsah\n' > "$W/agentic-brain/memory/sirota.md"; run_check
expect "súbor pamäte mimo indexu" 1 "CHYBA agentic-brain/memory/sirota.md: súbor nie je v indexe"
printf -- '- [Sirota](sirota.md): háčik\n' >> "$W/agentic-brain/memory/MEMORY.md"; run_check
expect "súbor pamäte v indexe prejde" 0 "v poriadku"

# odkazy
fresh; printf '\n[mŕtvy](nie-je.md)\n' >> "$W/agentic-brain/decisions/README.md"; run_check
expect "mŕtvy odkaz" 1 "CHYBA agentic-brain/decisions/README.md: mŕtvy odkaz na nie-je.md"

fresh; printf '\nPríklad `[x](nie-je.md)` v kóde.\n' >> "$W/agentic-brain/decisions/README.md"; run_check
expect "odkaz v kóde sa nekontroluje" 0 "v poriadku"

fresh; printf '\n[ok](README.md) [web](https://example.org/a)\n' >> "$W/agentic-brain/decisions/README.md"
run_check
expect "existujúci a vonkajší odkaz prejdú" 0 "v poriadku"

# CLAUDE.md a AGENTS.md
fresh; printf '@agentic-brain/RULES.md\nnavyše\n' > "$W/AGENTS.md"; run_check
expect "CLAUDE.md a AGENTS.md rôzne" 1 "CHYBA AGENTS.md: obsah sa líši"

fresh; printf 'bez importu\n' | tee "$W/CLAUDE.md" > "$W/AGENTS.md"; run_check
expect "chýba riadok importu" 1 "CHYBA CLAUDE.md: chýba riadok @agentic-brain/RULES.md"

fresh; rm "$W/AGENTS.md"; run_check
expect "chýba AGENTS.md" 1 "CHYBA AGENTS.md: súbor chýba"

# artefakty
fresh; mkdir -p "$W/agentic-brain/artifacts/web"; printf '# Web\n' > "$W/agentic-brain/artifacts/web/PLAYBOOK.md"; run_check
expect "artefakt bez reference" 1 "CHYBA agentic-brain/artifacts/web/reference"
mkdir "$W/agentic-brain/artifacts/web/reference"; printf '<html></html>\n' > "$W/agentic-brain/artifacts/web/reference/vzor.html"; run_check
expect "artefakt s referenciou prejde" 0 "v poriadku"
rm "$W/agentic-brain/artifacts/web/PLAYBOOK.md"; run_check
expect "artefakt bez PLAYBOOK.md" 1 "CHYBA agentic-brain/artifacts/web: chýba PLAYBOOK.md"

# globál
fresh; mkdir -p "$HOME/agentic-brain/skills/chyba"; touch "$HOME/agentic-brain/RULES.md"; run_check
expect "rovnaký skill v lokáli a v globále" 1 "CHYBA agentic-brain/skills/chyba: skill chyba existuje aj v globále"
rm -rf "$HOME/agentic-brain/skills/chyba"; run_check
expect "bez duplicity prejde" 0 "v poriadku"

fresh; mkdir -p "$HOME/agentic-brain/skills" "$W/agentic-brain/skills/zdielany/scripts"
touch "$HOME/agentic-brain/RULES.md"
printf -- '---\nname: zdielany\ndescription: Použi, keď treba zdieľaný skill.\nscope: shared\n---\n' > "$W/agentic-brain/skills/zdielany/SKILL.md"
printf '#!/usr/bin/env bash\ntrue\n' > "$W/agentic-brain/skills/zdielany/scripts/a.sh"; run_check
expect "scope shared mimo globálu je upozornenie" 0 "UPOZORNENIE agentic-brain/skills/zdielany: scope shared"
rm -rf "$HOME/agentic-brain"

# globálne repo samo (priečinok bez nadradeného agentic-brain/)
N=$((N + 1)); W="$TMP/flat$N"; mkdir -p "$W"; cp -a "$SRC/agentic-brain/." "$W/"; git -C "$W" init -q
OUT=$(cd "$W" && bash bin/check.sh 2>&1); RC=$?
expect "global (mozog je koreň repa) prejde" 0 "v poriadku"

# hook
fresh; (cd "$W" && bash agentic-brain/bin/check.sh --install-hook) > "$TMP/hook.out" 2>&1
expect_true "hook je nainštalovaný" test -x "$W/.git/hooks/pre-commit"
(cd "$W" && bash agentic-brain/bin/check.sh --install-hook) > "$TMP/hook2.out" 2>&1
expect_true "opakovaná inštalácia hooku prejde" test "$?" -eq 0
GC=(git -C "$W" -c user.name=t -c user.email=t@example.org)
"${GC[@]}" add -A >/dev/null 2>&1
if "${GC[@]}" commit -qm prvy >/dev/null 2>&1; then echo "ok   commit s čistým repom prejde"; else echo "FAIL commit s čistým repom prejde"; FAILS=$((FAILS + 1)); fi
touch "$W/agentic-brain/scratch/junk" "$W/novy-subor"
"${GC[@]}" add novy-subor >/dev/null 2>&1
if "${GC[@]}" commit -qm druhy >/dev/null 2>&1; then
  echo "FAIL hook odmietne commit pri chybe"; FAILS=$((FAILS + 1))
else
  echo "ok   hook odmietne commit pri chybe"
fi

fresh; mkdir -p "$W/.git/hooks"; printf '#!/bin/sh\nexit 0\n' > "$W/.git/hooks/pre-commit"
(cd "$W" && bash agentic-brain/bin/check.sh --install-hook) > "$TMP/hook3.out" 2>&1; RC=$?; OUT=$(cat "$TMP/hook3.out")
expect "cudzí hook sa neprepíše" 1 "existuje iný pre-commit hook"

echo
if [ "$FAILS" -gt 0 ]; then echo "check.test.sh: $FAILS zlyhaní"; exit 1; fi
echo "check.test.sh: všetko prešlo"
