# Bird taxonomy (IOC World Bird List)

Observation.org uses the IOC World Bird List (https://www.worldbirdnames.org),
while BirdNET v2.4 uses the eBird/Clements taxonomy of about 2021.
`export_observation()` translates the names with these tables:

- `birdnet_v2.4_to_ioc_15.2.csv.gz`: every label of BirdNET v2.4 (6,522) with
  its IOC 15.2 name and how it was matched (`match`):
  `same` (same name), `split` (same name, but IOC has split the species: the
  name may now refer to another population; `export_observation()` warns),
  `synonym` (name used by another checklist of the IOC comparison file),
  `english` (same English name), `manual` (checked by hand: lumps and BirdNET
  species that are subspecies in IOC) and `not_bird` (non-species classes,
  amphibians, insects and mammals, which are left out).
- `regional_rules.csv`: splits where the IOC species depends on the region
  (e.g. *Cecropis daurica* is *Cecropis rufula* in Europe, *Calonectris
  diomedea* is *Calonectris borealis* in the Atlantic, *Fringilla coelebs* is
  *Fringilla canariensis* in the Canary Islands). Written by hand.
- `ioc_15.2_birds.csv.gz`: IOC 15.2 species with English and Spanish names.

The first two tables are built with `data-raw/build_taxonomy.R` (in the
source repository) from the BirdNET v2.4 labels and the file
`IOC_15.2_vs_other_lists.xlsx`; the script lists the birds left without an
IOC name so that they can be added to its manual table.

## Licence and citation

IOC World Bird List v15.2 by Frank Gill, David Donsker & Pamela Rasmussen
(Eds) is licensed under a Creative Commons Attribution 3.0 Unported License
(https://creativecommons.org/licenses/by/3.0/).

Gill F, D Donsker & P Rasmussen (Eds). 2026. IOC World Bird List (v15.2).
