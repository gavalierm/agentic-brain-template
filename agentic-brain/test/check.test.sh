#!/usr/bin/env bash
# Test of bin/check.sh: the template passes, every broken rule fails with the right message.
# It runs in a temporary folder with its own HOME and never touches the real HOME.
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
expect() { # description code regex
  if [ "$RC" -eq "$2" ] && printf '%s' "$OUT" | grep -qE "$3"; then
    echo "ok   $1"
  else
    echo "FAIL $1 (code $RC, expected $2 and /$3/)"
    printf '%s\n' "$OUT" | sed 's/^/     /'
    FAILS=$((FAILS + 1))
  fi
}
expect_true() { # description command...
  local d=$1; shift
  if "$@"; then echo "ok   $d"; else echo "FAIL $d"; FAILS=$((FAILS + 1)); fi
}

fresh; run_check
expect "template passes" 0 "^check.sh: ok$"

fresh; (cd "$W/agentic-brain/memory" && bash ../bin/check.sh >/dev/null 2>&1); RC=$?; OUT=x
expect "runs from a subfolder too" 0 x

# symlinks
fresh; rm "$W/.claude/skills/error"; run_check
expect "missing symlink is created" 0 "CREATED symlink .claude/skills/error"
expect_true "created symlink points to the skill" test "$(readlink "$W/.claude/skills/error")" = "../../agentic-brain/skills/error"
run_check
expect "second run prints nothing about symlinks" 0 "^check.sh: ok$"

fresh; ln -s ../../agentic-brain/skills/old "$W/.claude/skills/old"; run_check
expect "dangling symlink is deleted" 0 "DELETED dangling symlink .claude/skills/old"
expect_true "dangling symlink is gone" test ! -L "$W/.claude/skills/old"

fresh; mkdir "$W/.claude/skills/foreign"; run_check
expect "other entry without a skill is an error" 1 "ERROR .claude/skills/foreign"

fresh; rm "$W/.claude/skills/error"; mkdir "$W/.claude/skills/error"; run_check
expect "folder instead of a symlink is an error" 1 "ERROR .claude/skills/error: not a symlink"

fresh; mkdir -p "$W/agentic-brain/skills/fresh/scripts"
printf -- '---\nname: fresh\ndescription: Use when a new skill is needed.\n---\n' > "$W/agentic-brain/skills/fresh/SKILL.md"
printf '#!/usr/bin/env bash\ntrue\n' > "$W/agentic-brain/skills/fresh/scripts/a.sh"
run_check
expect "new skill gets a symlink" 0 "CREATED symlink .claude/skills/fresh"

# skills
fresh; rm -rf "$W/agentic-brain/skills/error/scripts"; run_check
expect "skill without scripts" 1 "ERROR agentic-brain/skills/error/scripts: scripts/ is missing"

fresh; rm "$W/agentic-brain/skills/error/scripts/error.sh"; touch "$W/agentic-brain/skills/error/scripts/.gitkeep"; run_check
expect "skill with empty scripts" 1 "ERROR agentic-brain/skills/error/scripts"

fresh; printf -- '---\nname: error\n---\n' > "$W/agentic-brain/skills/error/SKILL.md"; run_check
expect "skill without description" 1 "ERROR agentic-brain/skills/error/SKILL.md: frontmatter has no description"

fresh; rm "$W/agentic-brain/skills/error/SKILL.md"; run_check
expect "skill without SKILL.md" 1 "SKILL.md is missing"

# error register
fresh; bash "$W/agentic-brain/skills/error/scripts/error.sh" class1 "first occurrence" > "$TMP/c1.out"; run_check
expect "one open error is only a warning" 0 "WARNING .*class class1 is open"
bash "$W/agentic-brain/skills/error/scripts/error.sh" class1 "second occurrence" > "$TMP/c2.out"; run_check
expect "duplicate error without a fix" 1 "ERROR agentic-brain/errors/REGISTER.md: class class1 has 2 rows without a fix"
expect_true "error.sh prints the occurrence count" grep -q 'Occurrences of class "class1": 2' "$TMP/c2.out"

fresh
printf '%s\n' '| 2026-01-01 | t | a | fixed | test |' '| 2026-01-02 | t | b | fixed | test |' >> "$W/agentic-brain/errors/REGISTER.md"; run_check
expect "errors with a filled-in fix pass" 0 "^check.sh: ok$"

# scratch
fresh; touch "$W/agentic-brain/scratch/notes.txt"; run_check
expect "scratch not empty" 1 "ERROR agentic-brain/scratch/notes.txt: scratch is not empty"

# memory
fresh; printf -- '- [Missing](missing.md): hook\n' >> "$W/agentic-brain/memory/MEMORY.md"; run_check
expect "MEMORY.md points to a missing file" 1 "ERROR agentic-brain/memory/MEMORY.md: line points to a missing file memory/missing.md"

fresh; printf 'content\n' > "$W/agentic-brain/memory/orphan.md"; run_check
expect "memory file outside the index" 1 "ERROR agentic-brain/memory/orphan.md: file is not in the MEMORY.md index"
printf -- '- [Orphan](orphan.md): hook\n' >> "$W/agentic-brain/memory/MEMORY.md"; run_check
expect "memory file in the index passes" 0 "^check.sh: ok$"

# links
fresh; printf '\n[dead](missing.md)\n' >> "$W/agentic-brain/decisions/README.md"; run_check
expect "dead link" 1 "ERROR agentic-brain/decisions/README.md: dead link to missing.md"

fresh; printf '\nExample `[x](missing.md)` in code.\n' >> "$W/agentic-brain/decisions/README.md"; run_check
expect "link in code is not checked" 0 "^check.sh: ok$"

fresh; printf '\n[ok](README.md) [web](https://example.org/a)\n' >> "$W/agentic-brain/decisions/README.md"
run_check
expect "existing and external links pass" 0 "^check.sh: ok$"

# CLAUDE.md and AGENTS.md
fresh; printf '@agentic-brain/RULES.md\nextra\n' > "$W/AGENTS.md"; run_check
expect "CLAUDE.md and AGENTS.md differ" 1 "ERROR AGENTS.md: content differs"

fresh; printf 'no import\n' | tee "$W/CLAUDE.md" > "$W/AGENTS.md"; run_check
expect "import line is missing" 1 "ERROR CLAUDE.md: line @agentic-brain/RULES.md is missing"

fresh; rm "$W/AGENTS.md"; run_check
expect "AGENTS.md is missing" 1 "ERROR AGENTS.md: file is missing"

# artifacts
fresh; mkdir -p "$W/agentic-brain/artifacts/web"; printf '# Web\n' > "$W/agentic-brain/artifacts/web/PLAYBOOK.md"; run_check
expect "artifact without reference" 1 "ERROR agentic-brain/artifacts/web/reference"
mkdir "$W/agentic-brain/artifacts/web/reference"; printf '<html></html>\n' > "$W/agentic-brain/artifacts/web/reference/sample.html"; run_check
expect "artifact with a reference passes" 0 "^check.sh: ok$"
rm "$W/agentic-brain/artifacts/web/PLAYBOOK.md"; run_check
expect "artifact without PLAYBOOK.md" 1 "ERROR agentic-brain/artifacts/web: PLAYBOOK.md is missing"

# global layer
fresh; mkdir -p "$HOME/agentic-brain/skills/error"; touch "$HOME/agentic-brain/RULES.md"; run_check
expect "same skill in the local and the global layer" 1 "ERROR agentic-brain/skills/error: skill error also exists in the global layer"
rm -rf "$HOME/agentic-brain/skills/error"; run_check
expect "without a duplicate it passes" 0 "^check.sh: ok$"

fresh; mkdir -p "$HOME/agentic-brain/skills" "$W/agentic-brain/skills/shared/scripts"
touch "$HOME/agentic-brain/RULES.md"
printf -- '---\nname: shared\ndescription: Use when a shared skill is needed.\nscope: shared\n---\n' > "$W/agentic-brain/skills/shared/SKILL.md"
printf '#!/usr/bin/env bash\ntrue\n' > "$W/agentic-brain/skills/shared/scripts/a.sh"; run_check
expect "scope shared outside the global layer is a warning" 0 "WARNING agentic-brain/skills/shared: scope is shared"
rm -rf "$HOME/agentic-brain"

# the global repo itself (a folder without a parent agentic-brain/)
N=$((N + 1)); W="$TMP/flat$N"; mkdir -p "$W"; cp -a "$SRC/agentic-brain/." "$W/"; git -C "$W" init -q
OUT=$(cd "$W" && bash bin/check.sh 2>&1); RC=$?
expect "global (the brain is the repo root) passes" 0 "^check.sh: ok$"

# hook
fresh; (cd "$W" && bash agentic-brain/bin/check.sh --install-hook) > "$TMP/hook.out" 2>&1
expect_true "hook is installed" test -x "$W/.git/hooks/pre-commit"
(cd "$W" && bash agentic-brain/bin/check.sh --install-hook) > "$TMP/hook2.out" 2>&1
expect_true "repeated hook installation passes" test "$?" -eq 0
GC=(git -C "$W" -c user.name=t -c user.email=t@example.org)
"${GC[@]}" add -A >/dev/null 2>&1
if "${GC[@]}" commit -qm first >/dev/null 2>&1; then echo "ok   commit in a clean repo passes"; else echo "FAIL commit in a clean repo passes"; FAILS=$((FAILS + 1)); fi
touch "$W/agentic-brain/scratch/junk" "$W/new-file"
"${GC[@]}" add new-file >/dev/null 2>&1
if "${GC[@]}" commit -qm second >/dev/null 2>&1; then
  echo "FAIL hook rejects a commit on error"; FAILS=$((FAILS + 1))
else
  echo "ok   hook rejects a commit on error"
fi

fresh; mkdir -p "$W/.git/hooks"; printf '#!/bin/sh\n# old agentic-brain hook\nbash agentic-brain/bin/check.sh\n' > "$W/.git/hooks/pre-commit"
(cd "$W" && bash agentic-brain/bin/check.sh --install-hook) > /dev/null 2>&1
expect_true "an older own hook is replaced" cmp -s "$W/agentic-brain/bin/pre-commit" "$W/.git/hooks/pre-commit"

fresh; mkdir -p "$W/.git/hooks"; printf '#!/bin/sh\nexit 0\n' > "$W/.git/hooks/pre-commit"
(cd "$W" && bash agentic-brain/bin/check.sh --install-hook) > "$TMP/hook3.out" 2>&1; RC=$?; OUT=$(cat "$TMP/hook3.out")
expect "foreign hook is not overwritten" 1 "another pre-commit hook exists"

echo
if [ "$FAILS" -gt 0 ]; then echo "check.test.sh: $FAILS failures"; exit 1; fi
echo "check.test.sh: all passed"
