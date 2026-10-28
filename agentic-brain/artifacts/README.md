# Artefakty

Artefakt je schválený vzor opakovanej práce. Operátor schválil konkrétny výsledok a jeho pravidlá sú zapísané, aby ich každý agent použil rovnako.

## Štruktúra

```
artifacts/<meno>/
  PLAYBOOK.md
  reference/
```

- `<meno>`: krátke a podľa veci, nie podľa agenta alebo projektu.
- `PLAYBOOK.md`: čo artefakt pokrýva, pravidlá ako krátke vety s konkrétnymi hodnotami a dôvodom, čo nerobiť a ako výsledok overiť.
- `reference/`: schválený výsledok ako šablóna, ktorú sa dá skopírovať, nie opis. Je to zdroj pravdy pre hodnoty. Priečinok nesmie byť prázdny.

Pri rozpore medzi textom a referenciou platí referencia. Pri zmene referencie uprav aj `PLAYBOOK.md` a naopak.

## Rozsah

Artefakt s dosahom mimo projektu nesie vo frontmattri `PLAYBOOK.md` riadok `scope: shared`. Do centrálneho repa ho povyšuje operátor.

## Založenie

Artefakt zakladá agent, ktorý vec urobil, a schvaľuje ho operátor. Bez schválenia sa nezakladá. Vzorový artefakt tu nie je, vzniká z prvej schválenej práce.
