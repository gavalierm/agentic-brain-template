---
name: chyba
description: Použi, keď sa pri práci stala chyba (tvoja, nástroja alebo postupu), keď si ručne zopakoval mechanický krok alebo keď ti rovnaká vec zlyhala znova. Zapíše chybu do registra errors/REGISTER.md a povie, koľký je výskyt jej triedy.
---

# Chyba

Register chýb je `agentic-brain/errors/REGISTER.md`. Jeden riadok je jeden výskyt.

## Čo rozhodne agent

- Trieda chyby: krátke meno, rovnaké pre rovnaký druh chyby (napríklad `rucny-download`, `zly-odkaz`).
- Opis: čo sa stalo a čo to spôsobilo.
- Oprava: nástroj, pravidlo alebo kontrola, ktorá chybu zablokuje nabudúce. Oprava je zmena súboru, nie sľub.
- Test: príkaz, ktorý na chybe zlyhá a po oprave prejde.

## Čo urobí skript

`scripts/chyba.sh "<trieda>" "<opis>"` pridá riadok s dnešným dátumom a prázdnymi stĺpcami oprava a test. Vypíše, koľký je výskyt triedy a koľko výskytov nemá opravu.

## Postup

1. Spusti `agentic-brain/skills/chyba/scripts/chyba.sh "<trieda>" "<opis>"`.
2. Nájdi príčinu a oprav ju v súbore, ktorý správanie riadi.
3. Vyplň v riadku stĺpce oprava a test.

Dva a viac výskytov tej istej triedy bez opravy zlyhá v `bin/check.sh`. Jeden výskyt bez opravy je len upozornenie.
