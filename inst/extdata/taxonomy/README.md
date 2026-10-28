# Bird taxonomy (IOC World Bird List and Observation.org)

BirdNET v2.4 uses the eBird/Clements taxonomy of about 2021. Observation.org
follows the IOC World Bird List (https://www.worldbirdnames.org) with some
lumps and genera of its own, and its import only accepts its own names.
`export_observation()` translates the names with these tables:

- `birdnet_v2.4_to_ioc_15.2.csv.gz`: every label of BirdNET v2.4 (6,522) with
  its IOC 15.2 name and how it was matched (`match`):
  `same` (same name), `split` (same name, but IOC has split the species: the
  name may now refer to another population; `export_observation()` warns),
  `synonym` (name used by another checklist of the IOC comparison file),
  `english` (same English name), `manual` (checked by hand: lumps and BirdNET
  species that are subspecies in IOC) and `not_bird` (non-species classes,
  amphibians, insects and mammals, which are left out). The column
  `obs_name` is the name exported to Observation.org and `obs_match` how it
  was found: `ioc` (the IOC name is a species of Observation.org), `lumped`
  (Observation.org treats it as a synonym or subspecies of another species,
  e.g. *Corvus cornix* → *Corvus corone*), `birdnet` (the BirdNET name is the
  one of Observation.org) or `manual` (checked by hand).
- `observation_birds.csv.gz`: scientific names of the bird species of
  Observation.org and of their synonyms (`species` is the accepted species),
  from its species list downloaded on 2026-10-28.
- `regional_rules.csv`: splits where the IOC species depends on the region
  (e.g. *Cecropis daurica* is *Cecropis rufula* in Europe, *Calonectris
  diomedea* is *Calonectris borealis* in the Atlantic, *Fringilla coelebs* is
  *Fringilla canariensis* in the Canary Islands). Written by hand.
- `ioc_15.2_birds.csv.gz`: IOC 15.2 species with English and Spanish names.

These tables are built with `data-raw/build_taxonomy.R` (in the source
repository) from the BirdNET v2.4 labels, the file
`IOC_15.2_vs_other_lists.xlsx` and the species list of Observation.org; the
script checks that every bird has a species of Observation.org. Rebuild them
when Observation.org changes its taxonomy (export its species list of the
group Aves again).

## Licence and citation

IOC World Bird List v15.2 by Frank Gill, David Donsker & Pamela Rasmussen
(Eds) is licensed under a Creative Commons Attribution 3.0 Unported License
(https://creativecommons.org/licenses/by/3.0/).

Gill F, D Donsker & P Rasmussen (Eds). 2026. IOC World Bird List (v15.2).
