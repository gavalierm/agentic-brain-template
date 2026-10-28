#!/usr/bin/env bash
# Nasadí šablónu do existujúceho repa. Nič necommituje a nič neprepíše.
# Použitie: adopt.sh <cieľový-repo>
set -u

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "Použitie: adopt.sh <cieľový-repo>" >&2
  exit 2
fi

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SRC=$(cd "$SELF_DIR/.." && pwd -P)
TARGET=$(cd "$1" && pwd -P)

if [ ! -e "$TARGET/.git" ]; then
  echo "$TARGET nie je git repo (chýba .git)" >&2
  exit 1
fi
if [ "$SRC" = "$TARGET/agentic-brain" ] || [ "$SRC" = "$TARGET" ]; then
  echo "Zdroj a cieľ sú ten istý priečinok" >&2
  exit 1
fi

DEST="$TARGET/agentic-brain"
IMPORT="@agentic-brain/RULES.md"

# 1. agentic-brain/ bez prepísania existujúcich súborov
copied=0; skipped=0
while IFS= read -r f; do
  r=${f#"$SRC"/}
  case "$r" in
    scratch/.gitkeep) ;;
    scratch/*) continue ;;
  esac
  if [ -e "$DEST/$r" ] || [ -L "$DEST/$r" ]; then
    echo "Preskočené, už existuje: agentic-brain/$r"
    skipped=$((skipped + 1))
  else
    mkdir -p "$(dirname "$DEST/$r")"
    cp -p "$f" "$DEST/$r"
    copied=$((copied + 1))
  fi
done < <(find "$SRC" -type f ! -path '*/.git/*' ! -name '.DS_Store' | sort)
echo "Skopírované súbory: $copied, preskočené: $skipped"

# 2. symlinky skillov
for d in "$DEST"/skills/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  link="$TARGET/.claude/skills/$name"
  if [ -L "$link" ] || [ -e "$link" ]; then
    echo "Preskočené, už existuje: .claude/skills/$name"
  else
    mkdir -p "$TARGET/.claude/skills"
    ln -s "../../agentic-brain/skills/$name" "$link"
    echo "Vytvorený symlink: .claude/skills/$name"
  fi
done

# 3. .claude/settings.json
SETTINGS="$TARGET/.claude/settings.json"
if [ ! -e "$SETTINGS" ]; then
  mkdir -p "$TARGET/.claude"
  cat > "$SETTINGS" <<'EOT'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$CLAUDE_PROJECT_DIR/agentic-brain/bin/repeat_guard.mjs\""
          }
        ]
      }
    ]
  }
}
EOT
  echo "Vytvorený .claude/settings.json s hookom repeat_guard"
elif grep -q 'repeat_guard.mjs' "$SETTINGS"; then
  echo "Hook repeat_guard už je v .claude/settings.json"
else
  echo "Preskočené, .claude/settings.json už existuje. Pridaj do hooks.PreToolUse túto položku:"
  cat <<'EOT'
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "node \"$CLAUDE_PROJECT_DIR/agentic-brain/bin/repeat_guard.mjs\"" }
        ]
      }
EOT
fi

# 4. riadok importu v CLAUDE.md a AGENTS.md
for f in CLAUDE.md AGENTS.md; do
  p="$TARGET/$f"
  if [ -f "$p" ] && grep -qxF "$IMPORT" "$p"; then
    echo "Riadok importu už je v $f"
    continue
  fi
  if [ -s "$p" ] && [ -n "$(tail -c1 "$p")" ]; then printf '\n' >> "$p"; fi
  printf '%s\n' "$IMPORT" >> "$p"
  echo "Pridaný riadok $IMPORT do $f"
done
if ! cmp -s "$TARGET/CLAUDE.md" "$TARGET/AGENTS.md"; then
  echo "Pozor: CLAUDE.md a AGENTS.md sa líšia. check.sh vyžaduje rovnaký obsah, zjednoť ich."
fi

# 5. .gitignore
GI="$TARGET/.gitignore"
for line in "agentic-brain/scratch/*" "!agentic-brain/scratch/.gitkeep"; do
  if [ -f "$GI" ] && grep -qxF "$line" "$GI"; then continue; fi
  if [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ]; then printf '\n' >> "$GI"; fi
  printf '%s\n' "$line" >> "$GI"
  echo "Pridaný riadok do .gitignore: $line"
done

echo
echo "Hotovo. Nič som necommitoval. Ďalej v cieľovom repe:"
echo "  agentic-brain/bin/check.sh --install-hook"
echo "  agentic-brain/bin/check.sh"
exit 0
