#!/usr/bin/env bash
# Spustí bin/check.sh a vypíše checklist konca úlohy z RULES.md s výsledkom.
set -u

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BRAIN=$(cd "$SELF_DIR/../../.." && pwd)
RULES="$BRAIN/RULES.md"

bash "$BRAIN/bin/check.sh"
RC=$?

echo
echo "Checklist konca úlohy:"
if [ ! -f "$RULES" ]; then
  echo "  chýba $RULES" >&2
  exit 1
fi
awk -v rc="$RC" '
  /^## / { in_sec = ($0 ~ /^## Koniec úlohy[[:space:]]*$/); next }
  in_sec && /^[-*] / {
    item = substr($0, 3)
    if (item ~ /check\.sh/) {
      printf "  [%s] %s\n", (rc == 0 ? "OK" : "CHYBA"), item
    } else {
      printf "  [ ] %s\n", item
    }
  }' "$RULES"
echo
if [ "$RC" -eq 0 ]; then
  echo "Kontrola prešla. Body označené [ ] potvrď sám."
else
  echo "Kontrola zlyhala. Oprav chyby vyššie a spusti skript znova."
fi
exit "$RC"
