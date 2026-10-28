# Pravidlá projektu

Súbor načíta agent v každej relácii. Platí pre všetko, čo robíš v tomto repe.
Všetky dáta agenta sú v jednom viditeľnom priečinku `agentic-brain/`.

## Kde čo je

- `agentic-brain/skills/<meno>/`: skill, `SKILL.md` a `scripts/`. Claude Code ho číta cez symlink `.claude/skills/<meno>`, ten založí `agentic-brain/bin/check.sh`.
- `agentic-brain/artifacts/<meno>/`: schválený vzor práce, `PLAYBOOK.md` a `reference/`.
- `agentic-brain/errors/REGISTER.md`: register chýb. Riadok pridá skript `skills/chyba/scripts/chyba.sh`.
- `agentic-brain/decisions/`: rozhodnutia, jeden súbor `D0001-<slug>.md` na rozhodnutie. Nové založí `bin/rozhodni.sh`.
- `agentic-brain/memory/MEMORY.md`: index pamäte, obsah je v `memory/<subor>.md`.
- `agentic-brain/scratch/`: pracovné súbory úlohy. Git ich ignoruje, na konci úlohy je priečinok prázdny.
- `agentic-brain/bin/`: kontrola `check.sh`, inštalácia `install.sh`, nasadenie `adopt.sh`, `rozhodni.sh` a hook `repeat_guard.mjs`.

Priečinok `.claude/` nesie len symlinky na skilly a `settings.json`. Dáta v ňom nie sú.

## Povinná automatizácia

Ty rozhoduješ cieľ a kontroluješ výsledok. Mechanický krok robí skript.

Mechanický krok je upload, download, hľadanie, porovnanie, presun a prevod. Taký krok nerob ručne príkazmi v termináli. Napíš skript do `agentic-brain/skills/<meno>/scripts/` a spusti ho.

- Ručný beh mechanického kroku je chyba. Zapíš ju do registra cez skill `chyba`.
- Každý skill má `scripts/`. `SKILL.md` povie, čo rozhodne agent a čo urobí skript.
- Skript, ktorý sa dá použiť znova, patrí do skillu, nie do `scratch/`.
- Hook `bin/repeat_guard.mjs` (voliteľný, len Claude Code) zamietne tretí ručný beh toho istého programu s rôznymi argumentmi v jednej relácii. Pravidlo platí aj bez hooku.

## Koniec úlohy

Pred hlásením konca spusti skill `koniec-ulohy`. Overí tieto body.

- `agentic-brain/bin/check.sh` prešiel bez chyby.
- `agentic-brain/scratch/` je prázdny.
- Opakovaný postup je skill so skriptom.
- Chyba z behu je v registri chýb.
- Nová vedomosť je v `memory/` alebo v `decisions/`.
- Skill alebo artefakt s dosahom mimo projektu má vo frontmattri `scope: shared` a je v hlásení operátorovi.

## Centrum a lokál

Tento priečinok je lokálna vrstva projektu. Voliteľná druhá vrstva je centrálne repo s tou istou štruktúrou. Na stroji agenta je klonované ako `~/agentic-brain` a nainštalované cez `agentic-brain/bin/install.sh --global`.

Voliteľný riadok `upstream: <url>` v hlavičke tohto súboru ukazuje na centrálne repo.

Položku so `scope: shared` povyšuje do centra operátor. Agent ju len označí v hlásení konca úlohy. Skill s rovnakým menom v lokáli a v centre je chyba, `check.sh` ju nahlási.

## Artefakt

Artefakt je schválený vzor opakovanej práce. Pred návrhom alebo implementáciou veci, ktorú môže artefakt pokrývať, pozri zoznam `agentic-brain/artifacts/`.

1. Ak jeden sedí, prečítaj celý `PLAYBOOK.md` a otvor súbory v `reference/`.
2. Hodnoty (farby, rozmery, písmo, štruktúru) preber z referencie, nepíš ich z pamäte. Pri rozpore medzi textom a referenciou platí referencia.
3. Od artefaktu sa odchýľ len so zdôvodnením. Odchýlku napíš operátorovi jednou vetou a pravidlo neprepisuj.
4. Postup overenia z playbooku urob pred odovzdaním a uveď výsledok.
5. Nový artefakt zakladá agent, ktorý vec urobil, a schvaľuje ho operátor. Bez schválenia sa nezakladá.
