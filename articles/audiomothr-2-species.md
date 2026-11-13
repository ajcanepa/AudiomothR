# 2. Which species BirdNET looks for

Abstract

How AudiomothR chooses the species that BirdNET may propose: the
location filter of BirdNET (how it works, where its values come from and
when it leaves out species that are present), own lists of species
(vectors, the species lists of BirdNET-Analyzer, CSV files) and lists of
the species observed around the recorder, built from GBIF without an
account.

This is the second of three vignettes of AudiomothR. It assumes that you
have followed the first one
([`vignette("audiomothr-1-workflow")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-1-workflow.md)),
where the example card was read and analysed. Here we look in detail at
a single decision of step 3
([`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)):
**which species BirdNET is allowed to propose**. It matters a lot: it
decides which species can appear in your results at all.

``` r

library(AudiomothR)
```

## Three ways of choosing the species

BirdNET v2.4 knows about 6,500 classes: birds of the whole world, plus
some amphibians, insects, mammals and sounds such as “Human vocal”,
“Dog” or “Engine”. Without any limit it often proposes species of other
continents, so
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
offers three options:

| Option | How | When to use it |
|----|----|----|
| **1. Location filter** (default) | `analyze_birdnet(am)` | Common species, well visited areas, records for citizen science |
| **2. Own list of species** | `analyze_birdnet(am, species_list = ...)` | Rare, nocturnal or steppe species; little visited areas; target species of a project |
| **3. No filter** | `analyze_birdnet(am, location_filter = FALSE)` | Exploratory work, when every record is going to be checked by ear |

## Option 1: the location filter (default)

### How it works

Besides the model that listens to the audio, BirdNET has a **metadata
(geographic) model**, trained with the checklists of eBird. Given a
latitude, a longitude and a week of the year, it returns for every
species a **probability of occurrence**: roughly, how often the species
is reported in eBird checklists around that place in that week. BirdNET
divides the year into 48 weeks, four per month (days 1-7, 8-14, 15-21
and 22 to the end).

[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
asks for it at the location of each deployment and for the week of each
recording. **Only the species with a probability of at least
`location_threshold` (0.03, the value of BirdNET) are analysed; the
others are never proposed, whatever the audio.** At the example site, in
October, about 156 species pass the filter:

    Location filter: 156 expected species per site and week on average.

The probabilities are kept, for every species, place and week, in
`location_scores.csv` inside the cache of the analysis, and the
probability of each detected species is in the column `location_prob` of
the detections:

``` r

scores <- read.csv(file.path(am$analysis$cache, "location_scores.csv"))
head(scores[order(-scores$probability), ])          # the most expected species
scores[scores$scientific_name == "Asio otus", ]     # how expected is the long-eared owl?
```

### When it fails

The filter removes most absurd identifications, but it inherits the
biases of eBird. It may leave out species that **are** present:

- in **little visited areas**, with few eBird checklists;
- **nocturnal or secretive species**, rarely reported in daytime
  checklists (owls, the Eurasian stone-curlew, nightjars);
- **scarce or local species** (sandgrouse and other steppe birds, scarce
  migrants);
- recordings made **outside the usual season** of the species at the
  site.

A real example: in the steppes of Villafáfila (Zamora, Spain; 41.84°N
5.60°W), in May (weeks 17 and 19 of BirdNET), the filter keeps the
Eurasian stone-curlew (probability 0.042), but leaves out the little
bustard (0.028), the Eurasian scops owl (0.026), the pin-tailed and the
black-bellied sandgrouse (0.010 and 0.009) and the long-eared owl
(0.002). All of them have been observed within 25 km in spring,
according to GBIF. With the default filter, **those species can never
appear in the results**, even if they sing in front of the recorder.

### Adjusting it

``` r

am <- analyze_birdnet(am, location_threshold = 0.01)   # a lower threshold: more species
am <- analyze_birdnet(am, location_filter = FALSE)      # no filter at all (option 3)
```

A lower threshold keeps more species (and more mistakes); in
Villafáfila, 0.01 would keep the little bustard, the scops owl and the
pin-tailed sandgrouse, but not the black-bellied sandgrouse (0.009) nor
the long-eared owl (0.002): for such species, a list is better. Each
combination of parameters is a separate analysis in the cache: going
back to the default threshold does not analyse the recordings again.

## Option 2: an own list of species

With `species_list`, **only the species of the list are analysed**,
wherever the recorder is, and the location filter is not applied. The
list can be given in four ways.

### a) A vector of scientific names

``` r

my_species <- c("Burhinus oedicnemus", "Asio otus", "Otus scops", "Tetrax tetrax",
                "Pterocles orientalis", "Pterocles alchata")
checked <- read_species_list(my_species)
#> ✔ Species list: 6 species of BirdNET from 6 names.
checked
#>        scientific_name             english_name                input   match
#> 1  Burhinus oedicnemus      Eurasian Thick-knee  Burhinus oedicnemus birdnet
#> 2            Asio otus           Long-eared Owl            Asio otus birdnet
#> 3           Otus scops       Eurasian Scops-Owl           Otus scops birdnet
#> 4        Tetrax tetrax           Little Bustard        Tetrax tetrax birdnet
#> 5 Pterocles orientalis Black-bellied Sandgrouse Pterocles orientalis birdnet
#> 6    Pterocles alchata    Pin-tailed Sandgrouse    Pterocles alchata birdnet
```

[`read_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/read_species_list.md)
is what
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
uses to read the list. Run it first to check your list: it tells you how
many BirdNET species it found and warns about the names it does not
know. The column `match` says how each name was found (`birdnet` = the
BirdNET name itself).

### b) The species list of BirdNET-Analyzer

The desktop version of BirdNET (BirdNET-Analyzer) uses a text file with
one species per line, as `Scientific name_Common name`. Those files can
be used as they are:

``` r

analyzer_list <- file.path(tempdir(), "my_species_list.txt")
writeLines(c(
  "# Steppe birds of my study area",
  "Burhinus oedicnemus_Eurasian Thick-knee",
  "Tetrax tetrax_Little Bustard",
  "Pterocles orientalis_Black-bellied Sandgrouse",
  "Asio otus_Long-eared Owl"
), analyzer_list)

read_species_list(analyzer_list)
#> ✔ Species list: 4 species of BirdNET from 4 names.
#>        scientific_name             english_name                input   match
#> 1  Burhinus oedicnemus      Eurasian Thick-knee  Burhinus oedicnemus birdnet
#> 2        Tetrax tetrax           Little Bustard        Tetrax tetrax birdnet
#> 3 Pterocles orientalis Black-bellied Sandgrouse Pterocles orientalis birdnet
#> 4            Asio otus           Long-eared Owl            Asio otus birdnet
```

Empty lines and lines starting with `#` are ignored; the part after `_`
too, so a file with only scientific names works as well.

### c) A CSV file (e.g. made with a spreadsheet)

A CSV file with **a column of scientific names**. The column is found by
its name: `scientific_name`, `scientific name`, `Scientific Name`,
`species`, `taxon`… (any case); if none is found, the first column is
used. Other columns are ignored, so you can keep notes in them. The
package includes a template:

``` r

template <- system.file("extdata", "example", "species_list.csv", package = "AudiomothR")
read.csv(template)
#>            scientific_name              common_name
#> 1             Cettia cetti          Cetti's Warbler
#> 2  Troglodytes troglodytes            Eurasian Wren
#> 3        Motacilla cinerea             Grey Wagtail
#> 4           Motacilla alba            White Wagtail
#> 5       Erithacus rubecula           European Robin
#> 6            Turdus merula       Eurasian Blackbird
#> 7      Cyanistes caeruleus        Eurasian Blue Tit
#> 8              Parus major                Great Tit
#> 9      Burhinus oedicnemus    Eurasian Stone-curlew
#> 10               Asio otus           Long-eared Owl
#> 11              Otus scops       Eurasian Scops Owl
#> 12    Pterocles orientalis Black-bellied Sandgrouse
#> 13   Caprimulgus europaeus        Eurasian Nightjar
#>                                               notes
#> 1                                                  
#> 2                                                  
#> 3                                                  
#> 4                                                  
#> 5                                                  
#> 6                                                  
#> 7                                                  
#> 8                                                  
#> 9  nocturnal; often left out by the location filter
#> 10 nocturnal; often left out by the location filter
#> 11                                        nocturnal
#> 12                     steppe; little visited areas
#> 13                                        nocturnal
```

To make your own: copy the template, open it with a spreadsheet, write
one species per row and save it as CSV (comma or semicolon separated):

``` r

file.copy(template, "~/my_species_list.csv")
```

### d) A data frame in R

Any table with a column of scientific names, such as the result of
[`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md)
(option 2 from GBIF, below) or of
[`read_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/read_species_list.md)
itself.

### Names from other taxonomies

BirdNET v2.4 uses the eBird/Clements taxonomy of 2021, but your list may
come from elsewhere. Each name is looked up, in this order, as a name of
BirdNET, of the IOC World Bird List v15.2, of Observation.org (with its
synonyms) and of GBIF:

``` r

read_species_list(c("Carduelis chloris", "Cyanistes caeruleus", "Otis tarda", "Burhinus oedicnemis"))
#> ✔ Species list: 2 species of BirdNET from 4 names.
#> Warning: 2 names of the species list are not species of BirdNET v2.4 and are ignored:
#> "Otis tarda" and "Burhinus oedicnemis".
#> ℹ Check the spelling. Species without a model in BirdNET (e.g. Otis tarda)
#>   cannot be detected.
#>       scientific_name        english_name               input       match
#> 1     Chloris chloris European Greenfinch   Carduelis chloris observation
#> 2 Cyanistes caeruleus   Eurasian Blue Tit Cyanistes caeruleus     birdnet
```

- *Carduelis chloris*, an old name still kept as a synonym by
  Observation.org, becomes *Chloris chloris*.
- *Otis tarda*: the great bustard is a real species, but **BirdNET v2.4
  has no model for it**, so it cannot be detected.
- *Burhinus oedicnemis*: a typo. Check the names that are reported!

Names that are still not found are looked up in GBIF when there is an
Internet connection (e.g. *Parus caeruleus* → *Cyanistes caeruleus*).
When a name stands for several BirdNET species (e.g. a species that IOC
lumps but BirdNET splits), all of them are kept.

### Analysing with the list

``` r

am <- analyze_birdnet(am, species_list = analyzer_list)      # or a vector, a CSV, a data frame
```

With BirdNET installed, it prints:

    ✔ Species list: 4 species of BirdNET from 4 names.
    BirdNET: 6 recordings; 6 pending.
    Loading the BirdNET model...
    Species list: 4 species (the location filter is not applied).
    ✔ 0 detections of 0 species saved in '<output>/AudioMoth_FACADE0012345678_detections.csv'.

(None of those steppe birds sings in the example card.) Things to know:

- The list is saved with the results of the analysis
  (`birdnet/<ID>_<key>/species_list.csv`), and the PDF report says that
  an own list was used.
- **Each list is a different analysis** with its own cache: going back
  to a list used before, or to the location filter, reuses its results.
- `location_prob` is still computed, so the validation page still shows
  first the species that are unusual at the site.
- In
  [`process_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/process_audiomoth.md),
  add `species_list = ...` like any other argument of
  [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md).

## Option 2 from GBIF: the species observed around the site

The best list is often that of the species **actually observed** around
the recorder. GBIF (<https://www.gbif.org>) gathers the observations of
eBird, Observation.org and iNaturalist, among many others, and
[`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md)
asks it, **without an account or a key** (it only needs an Internet
connection), which bird species were observed:

- within `radius_km` of each deployment of the box (25 km by default);
- in the months of the recordings (or `months = 1:12` for the whole
  year);
- in the last ten years (`years = c(2015, 2026)` to change them);
- in the datasets of eBird, Observation.org and iNaturalist
  (`datasets = "all"` for every dataset of GBIF, including museum
  collections).

``` r

gbif_list <- gbif_species_list(am, radius_km = 25, file = "~/species_box_01.csv")
```

    Asking GBIF for the bird species within 25 km of 1 site (months 10; 2016-2026)...
    ✔ 109 species of BirdNET observed in GBIF (with ≥ 1 occurrence).
    ℹ 2 other species of GBIF cannot be detected by BirdNET (attribute `not_in_birdnet`).
    ✔ List saved in '~/species_box_01.csv': review it and give it to analyze_birdnet() with species_list.

The result of that query for the example site (made on 2026-11-10) is
included in the package, so it can be looked at here without Internet:

``` r

gbif_list <- read.csv(system.file("extdata", "example", "gbif_species_list.csv",
                                  package = "AudiomothR"))
nrow(gbif_list)
#> [1] 109
head(gbif_list, 10)
#>           scientific_name       english_name              gbif_name records
#> 1             Gyps fulvus   Eurasian Griffon            Gyps fulvus      39
#> 2    Phoenicurus ochruros     Black Redstart   Phoenicurus ochruros      37
#> 3       Fringilla coelebs   Common Chaffinch      Fringilla coelebs      35
#> 4           Turdus merula Eurasian Blackbird          Turdus merula      35
#> 5      Erithacus rubecula     European Robin     Erithacus rubecula      32
#> 6     Carduelis carduelis European Goldfinch    Carduelis carduelis      27
#> 7       Passer domesticus      House Sparrow      Passer domesticus      26
#> 8             Parus major          Great Tit            Parus major      25
#> 9  Phylloscopus collybita  Common Chiffchaff Phylloscopus collybita      25
#> 10    Aegithalos caudatus    Long-tailed Tit    Aegithalos caudatus      24
#>    match
#> 1   gbif
#> 2   gbif
#> 3   gbif
#> 4   gbif
#> 5   gbif
#> 6   gbif
#> 7   gbif
#> 8   gbif
#> 9   gbif
#> 10  gbif
```

- `scientific_name`, `english_name`: the species, with BirdNET names.
- `gbif_name`: its name in GBIF (GBIF resolves the synonyms).
- `records`: number of observations in GBIF with those criteria. Species
  with few records may be rare, or mistakes.
- `match`: `gbif`, or `gbif (spelling)` when the GBIF name only differs
  in its spelling.

The four species that BirdNET detected in the example card are in the
list:

``` r

gbif_list[gbif_list$scientific_name %in% c("Motacilla cinerea", "Motacilla alba",
                                           "Cettia cetti", "Troglodytes troglodytes"), ]
#>            scientific_name    english_name               gbif_name records
#> 12          Motacilla alba   White Wagtail          Motacilla alba      23
#> 28       Motacilla cinerea    Gray Wagtail       Motacilla cinerea      12
#> 29 Troglodytes troglodytes   Eurasian Wren Troglodytes troglodytes      12
#> 36            Cettia cetti Cetti's Warbler            Cettia cetti       9
#>    match
#> 12  gbif
#> 28  gbif
#> 29  gbif
#> 36  gbif
```

### Reviewing, combining and using the list

The list is an ordinary table, so it can be edited before using it,
e.g. to leave out species with a single observation and to add the
target species of a project:

``` r

reviewed <- gbif_list[gbif_list$records >= 2, ]                     # (or min_records = 2)
reviewed <- unique(c(reviewed$scientific_name, my_species))         # + the steppe birds
length(reviewed)
#> [1] 87
```

``` r

am <- analyze_birdnet(am, species_list = reviewed)
# or directly
am <- analyze_birdnet(am, species_list = gbif_species_list(am, radius_km = 30))
# or after editing the CSV saved with file = ... in a spreadsheet
am <- analyze_birdnet(am, species_list = "~/species_box_01.csv")
```

### How wide should the area be?

- **25-50 km**, or a whole province, usually gives a list complete
  enough to include the scarce species without bringing in those of
  other regions.
- In **little visited areas**, use a larger radius (or `months = 1:12`).
- With `min_records = 2` or more, species recorded only once (perhaps by
  mistake) are left out.
- Very large radii bring in species of other habitats (the coast, the
  mountains), which BirdNET will then be allowed to propose.

The species of GBIF that BirdNET cannot detect are in
`attr(gbif_list, "not_in_birdnet")` (they are lost when the list is
saved as CSV); here, the Bonelli’s eagle (*Aquila fasciata*) and the
great bustard (*Otis tarda*).

### Citing the data

The observations belong to the observers and to the publishers of each
dataset. If a list from GBIF is used in a publication, cite GBIF and the
query: the URLs of the queries are in `attr(gbif_list, "queries")` and
the date in `attr(gbif_list, "date")` (e.g. “GBIF.org (2026) GBIF
Occurrence Search, , accessed on 2026-11-10”).
[`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md)
counts the observations of each species; it is not a GBIF download with
a DOI.

## Option 3: no filter

``` r

am <- analyze_birdnet(am, location_filter = FALSE)
```

All the classes of BirdNET are analysed. Nothing is lost, but there will
be mistakes with species of other continents. Use it only when every
record is going to be checked by ear
([`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md),
which shows first the records with the lowest `location_prob`), or to
explore what BirdNET hears.

## Summary

| You want… | Use |
|----|----|
| Records of the common species for Observation.org | The default (location filter) |
| Some species you know are there are missing | `location_threshold = 0.01`, or a list |
| Rare, nocturnal or steppe species | `species_list` with a list from GBIF ([`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md)), edited |
| The target species of a project only | `species_list = c(...)` or your BirdNET-Analyzer list |
| To see everything BirdNET hears | `location_filter = FALSE` + validation by ear |

Next: **vignette 3**,
[`vignette("audiomothr-3-boxes")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-3-boxes.md),
for several cards of the same box, boxes that are moved and reports of
several boxes.

## How to cite

See `citation("AudiomothR")` and the references of
[`vignette("audiomothr-1-workflow")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-1-workflow.md).
When a list from GBIF is used in a publication, cite also GBIF and its
queries (see *Citing the data* above).

## Session information

``` r

sessionInfo()
#> R version 4.6.2 (2026-10-29)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 24.04.5 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] AudiomothR_0.4.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] digest_0.6.39     desc_1.4.3        R6_2.6.1          fastmap_1.2.0    
#>  [5] xfun_0.62         cachem_1.1.0      knitr_1.52        htmltools_0.5.9  
#>  [9] rmarkdown_2.32    lifecycle_1.0.5   cli_3.6.6         sass_0.4.10      
#> [13] pkgdown_2.2.1     textshaping_1.0.5 jquerylib_0.1.4   systemfonts_1.3.2
#> [17] compiler_4.6.2    tools_4.6.2       ragg_1.5.2        bslib_0.12.0     
#> [21] evaluate_1.0.5    yaml_2.3.12       otel_0.3.0        jsonlite_2.0.0   
#> [25] rlang_1.3.0       fs_2.1.0
```
