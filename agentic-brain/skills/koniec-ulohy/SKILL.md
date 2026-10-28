---
name: koniec-ulohy
description: Použi na konci každej úlohy, pred hlásením výsledku operátorovi. Spustí kontrolu repa bin/check.sh a vypíše checklist konca úlohy z RULES.md s výsledkom kontroly.
---

# Koniec úlohy

## Čo rozhodne agent

- Či je opakovaný postup z úlohy skill so skriptom.
- Či je chyba z behu v registri a či nová vedomosť patrí do `memory/` alebo `decisions/`.
- Či má skill alebo artefakt dosah mimo projektu. Ak áno, vpíš do frontmattru `scope: shared` a uveď ho v hlásení operátorovi.

## Čo urobí skript

`scripts/koniec.sh` spustí `agentic-brain/bin/check.sh` a vypíše checklist z časti Koniec úlohy v `RULES.md`. Bod o kontrole označí podľa jej výsledku. Ostatné body potvrdzuješ ty. Skript skončí kódom kontroly.

## Postup

1. Spusti `agentic-brain/skills/koniec-ulohy/scripts/koniec.sh`.
2. Oprav každú chybu z výpisu a spusti skript znova.
3. Prejdi ručné body checklistu.
4. Až potom nahlás koniec úlohy.
