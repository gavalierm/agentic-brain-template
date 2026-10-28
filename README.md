# agentic-brain-template

Šablóna priečinka `agentic-brain/` pre repo projektu. Agent v ňom nájde pravidlá, skilly, artefakty, register chýb, rozhodnutia a pamäť na jednom viditeľnom mieste. Potrebuje len git, bash a node. Server, správca úloh ani iný nástroj nie sú potrebné.

## Čo repo je

Repo má dve použitia s tou istou štruktúrou.

- Priečinok `agentic-brain/` v repe projektu je lokálna vrstva. Nesie pravidlá a znalosť jedného projektu.
- Repo `~/agentic-brain` na stroji agenta je globálna vrstva. Nesie pravidlá a skilly pre všetky projekty stroja.

V projekte `CLAUDE.md` a `AGENTS.md` v koreni majú jediný riadok `@agentic-brain/RULES.md`. Globálna vrstva sa do projektu nekopíruje, načíta ju `~/.claude/CLAUDE.md` používateľa.

Claude Code číta skilly len z `.claude/skills/<meno>`. Preto je tam pre každý skill symlink na `agentic-brain/skills/<meno>`. Priečinok `.claude/` nesie len symlinky a `settings.json`, dáta v ňom nie sú. Symlinky v gite na Windows vyžadujú nastavenie a nie sú overené. Bash na Windows ide cez Git Bash alebo WSL.

## Nové repo

1. Na GitHube použi "Use this template", alebo repo naklonuj a zmaž jeho históriu.
2. Spusti `agentic-brain/bin/install.sh`. Doplní symlinky skillov a nainštaluje pre-commit hook.
3. Spusti `agentic-brain/bin/check.sh`.

## Existujúce repo

Z klonu šablóny spusti `agentic-brain/bin/adopt.sh <cesta-k-repu>`. Skript skopíruje `agentic-brain/` bez prepísania existujúcich súborov a vypíše, čo preskočil. Založí symlinky skillov a `.claude/settings.json` (ak chýba, inak vypíše, čo doň pridať). Pridá riadok `@agentic-brain/RULES.md` do `CLAUDE.md` a `AGENTS.md` a riadky pre `scratch/` do `.gitignore`. Nič necommituje.

Potom v cieľovom repe spusti `agentic-brain/bin/check.sh --install-hook` a `agentic-brain/bin/check.sh`. Ak sa `CLAUDE.md` a `AGENTS.md` líšia, `check.sh` to vyhlási za chybu. Zjednoť ich.

## Globálna vrstva

1. Naklonuj repo do `~/agentic-brain`.
2. Spusti `agentic-brain/bin/install.sh --global` z klonu.

Skript pridá do `~/.claude/CLAUDE.md` riadok s importom `RULES.md` a vytvorí symlinky `~/.claude/skills/<meno>` do klonu. Existujúci cudzí symlink alebo priečinok nechá a vypíše ho. Druhý beh nič nezmení.

Cloud a Cowork relácie `~/.claude/` stroja nečítajú. Tam patrí kópia globálnej vrstvy priamo do repa projektu.

## Čo robí check.sh

`agentic-brain/bin/check.sh` beží z koreňa repa aj z podpriečinka. Pri chybe skončí kódom 1 a vypíše riadok s cestou na každú chybu. Kontroluje tieto veci.

- `CLAUDE.md` a `AGENTS.md` existujú, sú rovnaké a majú riadok importu.
- Každý skill má `SKILL.md` s `description` a neprázdny `scripts/`.
- Každý skill má symlink v `.claude/skills`. Chýbajúci vytvorí, visiaci zmaže, cudziu položku nahlási.
- Skill s rovnakým menom v lokáli a v globále je chyba.
- Každý artefakt má `PLAYBOOK.md` a neprázdny `reference/`.
- Dva a viac riadkov registra chýb tej istej triedy bez opravy je chyba. Jeden je upozornenie.
- `scratch/` je prázdny.
- `MEMORY.md` a súbory pamäte sa zhodujú.
- Relatívne odkazy v md súboroch ukazujú na existujúce súbory.
- Skill alebo artefakt so `scope: shared`, ktorý nie je v globále, je upozornenie.

Voliteľný pre-commit hook spustí `check.sh` pred každým commitom a pri chybe commit odmietne. Nainštaluje ho `agentic-brain/bin/check.sh --install-hook`. Hook sa kopíruje do `.git/hooks/pre-commit`, `core.hooksPath` sa nemení.

## Hook proti ručnému opakovaniu

`.claude/settings.json` zapína hook `agentic-brain/bin/repeat_guard.mjs` pre nástroj Bash v Claude Code. Tretí rôzny ručný beh toho istého programu v relácii zamietne a vyzve na skript. Programy, ktoré hook nepočíta, sú v `agentic-brain/bin/repeat_guard.allow`. Hook je voliteľný, pravidlo a `check.sh` platia aj bez neho.

## Testy

Spusti `agentic-brain/test/run.sh`. Testy bežia v dočasných priečinkoch, na tvoj HOME ani repo nesiahnu.
