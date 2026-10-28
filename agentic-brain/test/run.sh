#!/usr/bin/env bash
# Spustí všetky testy šablóny. Skončí kódom 1 pri prvom zlyhaní.
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)

for t in check.test.sh install.test.sh adopt.test.sh; do
  echo "== $t"
  bash "$HERE/$t" || { echo "ZLYHALO: $t" >&2; exit 1; }
done

echo "== repeat_guard.test.mjs"
node --test "$HERE/repeat_guard.test.mjs" || { echo "ZLYHALO: repeat_guard.test.mjs" >&2; exit 1; }

echo
echo "Všetky testy prešli."
