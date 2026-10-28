#!/usr/bin/env bash
# Pridá riadok do errors/REGISTER.md a vypíše, koľký je výskyt triedy.
# Použitie: chyba.sh "<trieda>" "<opis>"
set -u

if [ "$#" -ne 2 ] || [ -z "${1// /}" ] || [ -z "${2// /}" ]; then
  echo "Použitie: chyba.sh \"<trieda>\" \"<opis>\"" >&2
  exit 2
fi

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BRAIN=$(cd "$SELF_DIR/../../.." && pwd)
REG="$BRAIN/errors/REGISTER.md"

clean() { printf '%s' "$1" | tr '\r\n\t' '   ' | tr '|' '/' | sed 's/^ *//; s/ *$//'; }
TRIEDA=$(clean "$1")
OPIS=$(clean "$2")

if [ ! -f "$REG" ]; then
  echo "Chýba register $REG" >&2
  exit 1
fi

# súbor musí končiť novým riadkom
if [ -s "$REG" ] && [ -n "$(tail -c1 "$REG")" ]; then
  printf '\n' >> "$REG"
fi
printf '| %s | %s | %s |  |  |\n' "$(date +%F)" "$TRIEDA" "$OPIS" >> "$REG"

awk -F'|' -v t="$TRIEDA" '
  function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
  /^\|/ {
    if (trim($2) !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) next
    if (tolower(trim($3)) != tolower(t)) next
    all++
    if (trim($5) == "") open++
  }
  END {
    printf "Výskyt triedy \"%s\": %d\n", t, all
    printf "Z toho bez opravy: %d\n", open
    if (open >= 2) print "Dva výskyty bez opravy zlyhajú v bin/check.sh. Oprav príčinu a vyplň stĺpce oprava a test."
  }' "$REG"
