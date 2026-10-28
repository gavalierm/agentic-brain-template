#!/usr/bin/env bash
# Kontrola repa projektu. Kód 0 je v poriadku, kód 1 je aspoň jedna chyba.
# Beží z koreňa repa aj z podpriečinka. Chyba je jeden riadok na stderr s cestou,
# upozornenie je riadok na stdout.
#
#   check.sh                 spustí všetky kontroly
#   check.sh --install-hook  skopíruje bin/pre-commit do .git/hooks/pre-commit
#
# Premenná AGENTIC_BRAIN_GLOBAL môže ukázať na priečinok globálneho mozgu
# (s RULES.md a skills/). Bez nej sa hľadá ~/agentic-brain.
set -u

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
BRAIN=$(cd "$SELF_DIR/.." && pwd -P)

case "${1:-}" in
  ""|--install-hook) ;;
  *) echo "Použitie: check.sh [--install-hook]" >&2; exit 2 ;;
esac

ROOT=$(git -C "$BRAIN" rev-parse --show-toplevel 2>/dev/null) || ROOT=""
if [ -z "$ROOT" ]; then
  if [ "$(basename "$BRAIN")" = "agentic-brain" ]; then ROOT=$(dirname "$BRAIN"); else ROOT=$BRAIN; fi
fi
ROOT=$(cd "$ROOT" && pwd -P)

# projekt: priečinok agentic-brain/ v repe projektu, global: repo je samo mozog
if [ "$BRAIN" = "$ROOT" ]; then MODE=global; else MODE=project; fi

ERRS=0
err() { echo "CHYBA $1: $2" >&2; ERRS=$((ERRS + 1)); }
warn() { echo "UPOZORNENIE $1: $2"; }
info() { echo "$1"; }
rel() { printf '%s' "${1#"$ROOT"/}"; }

# riadky frontmattru (medzi prvými dvoma ---)
fm() { tr -d '\r' < "$1" | awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }'; }
fm_get() { fm "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -n 1; }
# text bez blokov kódu a bez textu v spätných apostrofoch
strip_code() { tr -d '\r' < "$1" | awk '/^```/ { f = !f; next } !f { gsub(/`[^`]*`/, ""); print }'; }
nonempty_dir() { [ -d "$1" ] && [ -n "$(find "$1" -type f ! -name '.gitkeep' ! -name '.DS_Store' 2>/dev/null | head -n 1)" ]; }

# priečinok globálneho mozgu, prázdny výstup a kód 1, keď neexistuje alebo je to tento
global_brain() {
  local d=""
  if [ -n "${AGENTIC_BRAIN_GLOBAL:-}" ]; then
    d=$AGENTIC_BRAIN_GLOBAL
  elif [ -f "${HOME:-/nonexistent}/agentic-brain/RULES.md" ] || [ -d "${HOME:-/nonexistent}/agentic-brain/skills" ]; then
    d=$HOME/agentic-brain
  elif [ -f "${HOME:-/nonexistent}/agentic-brain/agentic-brain/RULES.md" ] || [ -d "${HOME:-/nonexistent}/agentic-brain/agentic-brain/skills" ]; then
    d=$HOME/agentic-brain/agentic-brain
  fi
  [ -n "$d" ] && [ -d "$d" ] || return 1
  d=$(cd "$d" && pwd -P)
  [ "$d" = "$BRAIN" ] && return 1
  printf '%s' "$d"
}

install_hook() {
  local src="$BRAIN/bin/pre-commit" gitdir hooks dst
  [ -f "$src" ] || { err "$(rel "$src")" "chýba pre-commit hook"; return 1; }
  gitdir=$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null) || { err "$ROOT" "nie je git repo, hook sa nenainštaluje"; return 1; }
  gitdir=$(cd "$ROOT" && cd "$gitdir" && pwd -P)
  hooks="$gitdir/hooks"
  dst="$hooks/pre-commit"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    err "$dst" "existuje iný pre-commit hook, nechal som ho, pridaj do neho volanie agentic-brain/bin/check.sh"
    return 1
  fi
  mkdir -p "$hooks"
  cp "$src" "$dst" && chmod +x "$dst"
  info "Hook nainštalovaný: $dst"
  if [ -n "$(git -C "$ROOT" config core.hooksPath 2>/dev/null)" ]; then
    warn "$dst" "core.hooksPath je nastavené, git hook z .git/hooks nespustí"
  fi
  return 0
}

if [ "${1:-}" = "--install-hook" ]; then
  install_hook && exit 0
  exit 1
fi

# 1. CLAUDE.md a AGENTS.md
check_entry_files() {
  [ "$MODE" = project ] || return 0
  local line="@agentic-brain/RULES.md" f ok=1
  for f in CLAUDE.md AGENTS.md; do
    if [ ! -f "$ROOT/$f" ]; then err "$f" "súbor chýba"; ok=0; continue; fi
    grep -qxF "$line" "$ROOT/$f" || err "$f" "chýba riadok $line"
  done
  if [ "$ok" = 1 ] && ! cmp -s "$ROOT/CLAUDE.md" "$ROOT/AGENTS.md"; then
    err "AGENTS.md" "obsah sa líši od CLAUDE.md, súbory musia byť rovnaké"
  fi
}

# 2. skilly
check_skills() {
  local d name f
  for d in "$BRAIN"/skills/*/; do
    [ -d "$d" ] || continue
    d=${d%/}; name=$(basename "$d"); f="$d/SKILL.md"
    if [ ! -f "$f" ]; then
      err "$(rel "$d")" "chýba SKILL.md"
    elif [ -z "$(fm_get "$f" description)" ]; then
      err "$(rel "$f")" "frontmatter nemá description"
    fi
    nonempty_dir "$d/scripts" || err "$(rel "$d")/scripts" "chýba scripts/ alebo je prázdny"
  done
}

# 3. symlinky .claude/skills
check_symlinks() {
  [ "$MODE" = project ] || return 0
  local sdir="$ROOT/.claude/skills" d name link want cur p
  for d in "$BRAIN"/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d"); link="$sdir/$name"; want="../../agentic-brain/skills/$name"
    if [ -L "$link" ]; then
      cur=$(readlink "$link")
      [ "$cur" = "$want" ] && continue
      if [ -e "$link" ]; then
        [ "$(cd "$link" 2>/dev/null && pwd -P)" = "$BRAIN/skills/$name" ] && continue
        err "$(rel "$link")" "symlink ukazuje na $cur, má na $want"
        continue
      fi
      rm "$link"; info "ZMAZANÝ visiaci symlink $(rel "$link")"
    elif [ -e "$link" ]; then
      err "$(rel "$link")" "nie je symlink, má byť symlink na $want"
      continue
    fi
    mkdir -p "$sdir" && ln -s "$want" "$link" && info "VYTVORENÝ symlink $(rel "$link") na $want"
  done
  for p in "$sdir"/* "$sdir"/.[!.]*; do
    [ -L "$p" ] || [ -e "$p" ] || continue
    name=$(basename "$p")
    case "$name" in .gitkeep|.DS_Store) continue ;; esac
    [ -d "$BRAIN/skills/$name" ] && continue
    if [ -L "$p" ] && [ ! -e "$p" ]; then
      rm "$p"; info "ZMAZANÝ visiaci symlink $(rel "$p")"
    else
      err "$(rel "$p")" "položka v .claude/skills nemá skill v agentic-brain/skills"
    fi
  done
}

# 4. rovnaké meno skillu v lokáli a v globále
check_duplicates() {
  local g d name
  g=$(global_brain) || return 0
  for d in "$BRAIN"/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ -d "$g/skills/$name" ] && err "$(rel "${d%/}")" "skill $name existuje aj v globále ($g/skills/$name)"
  done
}

# 5. artefakty
check_artifacts() {
  local d
  for d in "$BRAIN"/artifacts/*/; do
    [ -d "$d" ] || continue
    d=${d%/}
    [ -f "$d/PLAYBOOK.md" ] || err "$(rel "$d")" "chýba PLAYBOOK.md"
    nonempty_dir "$d/reference" || err "$(rel "$d")/reference" "chýba reference/ alebo je prázdny"
  done
}

# 6. register chýb
check_register() {
  local f="$BRAIN/errors/REGISTER.md" kind t n
  [ -f "$f" ] || { err "$(rel "$f")" "chýba register chýb"; return; }
  while IFS=$'\t' read -r kind t n; do
    if [ "$kind" = ERR ]; then
      err "$(rel "$f")" "trieda $t má $n riadkov bez opravy, oprav príčinu a vyplň stĺpce oprava a test (alebo založ úlohu)"
    else
      warn "$(rel "$f")" "trieda $t je otvorená, jeden riadok bez opravy"
    fi
  done < <(tr -d '\r' < "$f" | awk -F'|' '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^\|/ {
      if (trim($2) !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) next
      t = tolower(trim($3))
      if (!(t in seen)) { seen[t] = 1; order[++k] = t }
      if (trim($5) == "") open[t]++
    }
    END {
      for (i = 1; i <= k; i++) {
        t = order[i]
        if (open[t] >= 2) printf "ERR\t%s\t%d\n", t, open[t]
        else if (open[t] == 1) printf "WARN\t%s\t1\n", t
      }
    }')
}

# 7. scratch
check_scratch() {
  local p
  [ -d "$BRAIN/scratch" ] || return 0
  while IFS= read -r p; do
    err "$(rel "$p")" "scratch nie je prázdny, zmaž súbor alebo z neho urob skill"
  done < <(find "$BRAIN/scratch" -mindepth 1 ! -name '.gitkeep' | sort)
}

# 8. pamäť
check_memory() {
  local idx="$BRAIN/memory/MEMORY.md" t f name
  [ -f "$idx" ] || { err "$(rel "$idx")" "chýba index pamäte"; return; }
  while IFS= read -r t; do
    case "$t" in http://*|https://*) continue ;; esac
    t=${t%%#*}
    [ -e "$BRAIN/memory/$t" ] || err "$(rel "$idx")" "riadok ukazuje na neexistujúci súbor memory/$t"
  done < <(strip_code "$idx" | grep '^- \[' | sed -n 's/^- \[[^]]*\](\([^)]*\)).*/\1/p')
  for f in "$BRAIN"/memory/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    [ "$name" = MEMORY.md ] && continue
    strip_code "$idx" | grep -qF "($name)" || err "$(rel "$f")" "súbor nie je v indexe MEMORY.md"
  done
}

# 9. relatívne odkazy v md súboroch
check_md_links() {
  local f dir link path
  while IFS= read -r f; do
    dir=$(dirname "$f")
    while IFS= read -r link; do
      case "$link" in http://*|https://*|mailto:*|\#*|/*|~*|"") continue ;; esac
      path=${link%%#*}; path=${path%% *}
      [ -n "$path" ] || continue
      [ -e "$dir/$path" ] || err "$(rel "$f")" "mŕtvy odkaz na $path"
    done < <(strip_code "$f" | grep -o '\[[^]]*\]([^)]*)' | sed 's/^\[[^]]*\](\(.*\))$/\1/')
  done < <(find "$BRAIN" -name '*.md' ! -path "$BRAIN/scratch/*" ! -path '*/.git/*' | sort)
}

# 10. položky so scope: shared, ktoré nie sú v globále
check_shared() {
  local g kind file d name
  g=$(global_brain) || return 0
  for kind in skills:SKILL.md artifacts:PLAYBOOK.md; do
    file=${kind#*:}; kind=${kind%%:*}
    for d in "$BRAIN/$kind"/*/; do
      [ -f "$d$file" ] || continue
      name=$(basename "$d")
      if [ "$(fm_get "$d$file" scope)" = shared ] && [ ! -d "$g/$kind/$name" ]; then
        warn "$(rel "${d%/}")" "scope shared, ale v globále ($g/$kind) nie je, uveď ho v hlásení operátorovi"
      fi
    done
  done
}

check_entry_files
check_skills
check_symlinks
check_duplicates
check_artifacts
check_register
check_scratch
check_memory
check_md_links
check_shared

if [ "$ERRS" -gt 0 ]; then
  echo "check.sh: $ERRS chýb" >&2
  exit 1
fi
echo "check.sh: v poriadku"
exit 0
