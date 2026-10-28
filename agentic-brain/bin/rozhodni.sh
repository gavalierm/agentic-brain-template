#!/usr/bin/env bash
# Založí ďalší súbor rozhodnutia decisions/D0001-<slug>.md.
# Použitie: rozhodni.sh "<názov>"
set -u

if [ "$#" -ne 1 ] || [ -z "${1// /}" ]; then
  echo "Použitie: rozhodni.sh \"<názov>\"" >&2
  exit 2
fi

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BRAIN=$(cd "$SELF_DIR/.." && pwd)
DIR="$BRAIN/decisions"
mkdir -p "$DIR"

NAME=$(printf '%s' "$1" | tr '\r\n\t' '   ' | sed 's/^ *//; s/ *$//')

SLUG=$(printf '%s' "$NAME" \
  | sed 's/á/a/g;s/Á/a/g;s/ä/a/g;s/Ä/a/g;s/č/c/g;s/Č/c/g;s/ď/d/g;s/Ď/d/g;s/é/e/g;s/É/e/g;s/í/i/g;s/Í/i/g;s/ĺ/l/g;s/Ĺ/l/g;s/ľ/l/g;s/Ľ/l/g;s/ň/n/g;s/Ň/n/g;s/ó/o/g;s/Ó/o/g;s/ô/o/g;s/Ô/o/g;s/ŕ/r/g;s/Ŕ/r/g;s/š/s/g;s/Š/s/g;s/ť/t/g;s/Ť/t/g;s/ú/u/g;s/Ú/u/g;s/ý/y/g;s/Ý/y/g;s/ž/z/g;s/Ž/z/g' \
  | tr 'A-Z' 'a-z' \
  | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//' \
  | cut -c1-50 | sed 's/-$//')
[ -n "$SLUG" ] || SLUG=rozhodnutie

LAST=$(find "$DIR" -maxdepth 1 -name 'D[0-9][0-9][0-9][0-9]-*.md' -exec basename {} \; \
  | sed 's/^D\([0-9]\{4\}\)-.*/\1/' | sort -n | tail -n 1)
NEXT=$(printf '%04d' $((10#${LAST:-0} + 1)))
FILE="$DIR/D$NEXT-$SLUG.md"

cat > "$FILE" <<EOT
---
id: D$NEXT
datum: $(date +%F)
stav: navrhnuté
rozhodol:
---

# $NAME

## Rozhodnutie

## Dôvod
EOT
echo "Založené: $FILE"
