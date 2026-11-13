# Reads a list of species for BirdNET

Translates a list of species into the names of BirdNET v2.4, so that it
can be given to
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
with `species_list`. It is called by
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md);
use it directly to check a list before the analysis.

## Usage

``` r
read_species_list(species_list)
```

## Arguments

- species_list:

  The list: a vector of names, the path of a `.txt` or `.csv` file, or a
  data frame.

## Value

A data frame with one row per BirdNET species: `scientific_name`
(BirdNET name), `english_name` (BirdNET), `input` (the name of the list)
and `match` (`"birdnet"`, `"ioc"`, `"observation"` or `"gbif"`). The
names that were not found are in the attribute `"not_found"`.

## Details

**Accepted forms of the list:**

- A vector of scientific names: `c("Burhinus oedicnemus", "Asio otus")`.

- The path of a text file (`.txt`) with one species per line, such as
  the species list of BirdNET-Analyzer
  (`Burhinus oedicnemus_Eurasian Thick-knee`; the part after `_` is
  ignored) or just scientific names. Empty lines and lines starting with
  `#` are ignored.

- The path of a CSV file, or a data frame, with a column of scientific
  names. The column is found by its name (`scientific_name`,
  `scientific name`, `Scientific Name`, `species`, `taxon`... any case);
  otherwise the first column is used. Other columns (common name, number
  of records, notes...) are ignored. The result of
  [`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md)
  is such a table.

**Names.** Each name is looked up as a name of BirdNET v2.4
(eBird/Clements taxonomy of about 2021), then as a name of the IOC World
Bird List v15.2, of Observation.org (with its synonyms) and of the GBIF
Backbone Taxonomy, so lists taken from eBird, Observation.org,
iNaturalist or GBIF work as they are. Names that are still not found
(e.g. old synonyms such as *Parus caeruleus*) are looked up in the name
matching service of GBIF when there is an internet connection
(`options(AudiomothR.gbif_synonyms = FALSE)` turns it off). A name of a
species that IOC or Observation.org split or lump may stand for several
BirdNET species, and all of them are kept. Subspecies are reduced to
their species and the authors of the names are ignored. The non-species
classes of BirdNET (`"Human vocal"`, `"Dog"`, `"Engine"`...) are
accepted by their exact name. Names that are not found are reported:
BirdNET cannot detect them.

## See also

[`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md)
to build a list from GBIF, and
[`vignette("audiomothr-2-species")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-2-species.md).

## Examples

``` r
# "Carduelis chloris" is a synonym (Observation.org) of Chloris chloris
read_species_list(c("Burhinus oedicnemus", "Asio otus", "Carduelis chloris"))
#> ✔ Species list: 3 species of BirdNET from 3 names.
#>       scientific_name        english_name               input       match
#> 1 Burhinus oedicnemus Eurasian Thick-knee Burhinus oedicnemus     birdnet
#> 2           Asio otus      Long-eared Owl           Asio otus     birdnet
#> 3     Chloris chloris European Greenfinch   Carduelis chloris observation

# The species list of BirdNET-Analyzer
f <- tempfile(fileext = ".txt")
writeLines(c("Burhinus oedicnemus_Eurasian Thick-knee", "Asio otus_Long-eared Owl"), f)
read_species_list(f)
#> ✔ Species list: 2 species of BirdNET from 2 names.
#>       scientific_name        english_name               input   match
#> 1 Burhinus oedicnemus Eurasian Thick-knee Burhinus oedicnemus birdnet
#> 2           Asio otus      Long-eared Owl           Asio otus birdnet

# A CSV file with a column of scientific names (template in the package)
read_species_list(system.file("extdata", "example", "species_list.csv",
                              package = "AudiomothR"))
#> ✔ Species list: 13 species of BirdNET from 13 names.
#>            scientific_name             english_name                   input
#> 1             Cettia cetti          Cetti's Warbler            Cettia cetti
#> 2  Troglodytes troglodytes            Eurasian Wren Troglodytes troglodytes
#> 3        Motacilla cinerea             Gray Wagtail       Motacilla cinerea
#> 4           Motacilla alba            White Wagtail          Motacilla alba
#> 5       Erithacus rubecula           European Robin      Erithacus rubecula
#> 6            Turdus merula       Eurasian Blackbird           Turdus merula
#> 7      Cyanistes caeruleus        Eurasian Blue Tit     Cyanistes caeruleus
#> 8              Parus major                Great Tit             Parus major
#> 9      Burhinus oedicnemus      Eurasian Thick-knee     Burhinus oedicnemus
#> 10               Asio otus           Long-eared Owl               Asio otus
#> 11              Otus scops       Eurasian Scops-Owl              Otus scops
#> 12    Pterocles orientalis Black-bellied Sandgrouse    Pterocles orientalis
#> 13   Caprimulgus europaeus        Eurasian Nightjar   Caprimulgus europaeus
#>      match
#> 1  birdnet
#> 2  birdnet
#> 3  birdnet
#> 4  birdnet
#> 5  birdnet
#> 6  birdnet
#> 7  birdnet
#> 8  birdnet
#> 9  birdnet
#> 10 birdnet
#> 11 birdnet
#> 12 birdnet
#> 13 birdnet
```
