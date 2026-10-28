# Register chýb

Jeden riadok je jeden výskyt chyby. Riadok pridáva skript `skills/chyba/scripts/chyba.sh`, nepíš ho ručne.

- Trieda: krátke meno druhu chyby. Rovnaký druh má rovnaké meno.
- Oprava: zmena súboru, ktorá chybu zablokuje (nástroj, pravidlo, kontrola). Vyplníš ju po oprave.
- Test: príkaz, ktorý na chybe zlyhá a po oprave prejde.

Dva a viac riadkov tej istej triedy bez opravy zlyhá v `bin/check.sh`. Jeden riadok bez opravy je upozornenie.

| dátum | trieda | opis | oprava | test |
|---|---|---|---|---|
