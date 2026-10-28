# Rozhodnutia

Jedno rozhodnutie je jeden súbor `D0001-<slug>.md`. Číslo rastie o jedna, slug je krátky názov bez diakritiky.

Nové rozhodnutie založí `bin/rozhodni.sh "<názov>"`. Skript nájde najvyššie číslo a vytvorí ďalší súbor s hlavičkou.

## Formát súboru

Súbor začína hlavičkou medzi dvoma riadkami `---`.

- `id`: číslo rozhodnutia, napríklad `D0001`.
- `datum`: dátum zápisu v tvare `2026-01-31`.
- `stav`: `navrhnuté`, `platí`, `zrušené` alebo `nahradené`.
- `rozhodol`: kto rozhodnutie schválil (rola alebo meno).

Za hlavičkou je názov a dve časti.

- `Rozhodnutie`: čo platí, jednou až tromi vetami.
- `Dôvod`: prečo, vrátane cesty, ktorú sme nevybrali.

## Zmena rozhodnutia

Staré rozhodnutie nemaž. Zmeň jeho `stav` na `nahradené` a v novom súbore uveď, ktoré nahrádza. Každé miesto, ktoré staré rozhodnutie ešte tvrdí, oprav v tom istom kroku.

Rozhodnutie nie je poznámka z diskusie. Zapíš ho, až keď ho operátor potvrdil.
