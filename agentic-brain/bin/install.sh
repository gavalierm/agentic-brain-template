#!/usr/bin/env bash
# Inštalácia mozgu.
#
#   install.sh           projektová vrstva v tomto repe: symlinky skillov
#                        v .claude/skills a pre-commit hook
#   install.sh --global  toto repo je klon globálneho mozgu (~/agentic-brain):
#                        do ~/.claude/CLAUDE.md pridá import RULES.md a do
#                        ~/.claude/skills dá symlinky na skilly
#
# Skript je idempotentný. Cieľ globálnej inštalácie je $HOME/.claude.
set -u

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
BRAIN=$(cd "$SELF_DIR/.." && pwd -P)

install_project() {
  local rc=0
  bash "$BRAIN/bin/check.sh" || rc=1
  bash "$BRAIN/bin/check.sh" --install-hook || rc=1
  return "$rc"
}

install_global() {
  local home claude imp rel_path link name d cur
  home=${HOME:-}
  if [ -z "$home" ] || [ ! -d "$home" ]; then
    echo "HOME nie je nastavené alebo neexistuje" >&2
    return 1
  fi
  home=$(cd "$home" && pwd -P)
  claude="$home/.claude"
  mkdir -p "$claude/skills"

  # import RULES.md v ~/.claude/CLAUDE.md, cesta s ~ keď je mozog pod HOME
  case "$BRAIN" in
    "$home"/*) rel_path="~/${BRAIN#"$home"/}" ;;
    *) rel_path=$BRAIN ;;
  esac
  imp="@$rel_path/RULES.md"
  if [ -f "$claude/CLAUDE.md" ] && grep -qxF "$imp" "$claude/CLAUDE.md"; then
    echo "Import už je: $imp"
  else
    if [ -s "$claude/CLAUDE.md" ] && [ -n "$(tail -c1 "$claude/CLAUDE.md")" ]; then
      printf '\n' >> "$claude/CLAUDE.md"
    fi
    printf '%s\n' "$imp" >> "$claude/CLAUDE.md"
    echo "Pridaný import do $claude/CLAUDE.md: $imp"
  fi

  # symlinky skillov
  for d in "$BRAIN"/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    link="$claude/skills/$name"
    if [ -L "$link" ]; then
      cur=$(readlink "$link")
      if [ "$cur" = "$BRAIN/skills/$name" ]; then
        echo "Symlink už je: $link"
      else
        echo "Preskočené, cudzí symlink: $link ukazuje na $cur"
      fi
    elif [ -e "$link" ]; then
      echo "Preskočené, v ceste je súbor alebo priečinok: $link"
    else
      ln -s "$BRAIN/skills/$name" "$link"
      echo "Vytvorený symlink: $link"
    fi
  done
  return 0
}

case "${1:-}" in
  "") install_project ;;
  --global) install_global ;;
  *) echo "Použitie: install.sh [--global]" >&2; exit 2 ;;
esac
