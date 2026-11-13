# 3. Several cards, several boxes and reports

Abstract

How AudiomothR works with real monitoring: the successive cards of a
box, a box moved between sites, coming back to the work another day,
cards that were not copied, and PDF reports of one or several boxes.

This is the third of three vignettes of AudiomothR. The first one
([`vignette("audiomothr-1-workflow")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-1-workflow.md))
processed **one card**. In real work, an AudioMoth stays in the field
for weeks or months: its SD card is replaced every few days, the box is
sometimes moved to another site, the work is done over several days, and
several boxes are compared. This vignette shows how AudiomothR handles
all that.

``` r

library(AudiomothR)
```

## One results folder per box

The key idea: **each box (AudioMoth) has one results folder**, given
with `output`, and every card of that box is read into it. Each card
becomes a **deployment**, with its own dates, site and location. All the
steps (BirdNET, examples, validation, Observation.org, report) then work
with all the cards of the box at once, each recording with the location
of its own deployment.

    ~/AudiomothR_results/
    ├── box_01/      ← all the cards of the box FACADE0012345678
    │   ├── AudioMoth_FACADE0012345678_deployments.csv   (one row per card)
    │   ├── AudioMoth_FACADE0012345678_recordings.csv    (all the recordings)
    │   ├── AudioMoth_FACADE0012345678_detections.csv    (all the detections)
    │   └── recordings/  (copies of the cards, with copy_to = TRUE)
    └── box_02/      ← all the cards of another box

Two different boxes cannot share a results folder (AudiomothR stops with
an error if you try).

## Two cards of the same box

To show it with the example card of the package, we split it into two
“cards”, as if the SD card had been replaced between 7 and 15 October
and the box had been moved about 4 km:

``` r

example_card <- system.file("extdata", "example", "card", package = "AudiomothR")
make_card <- function(day) {
  card <- file.path(tempdir(), paste0("card_", day))
  dir.create(file.path(card, day), recursive = TRUE, showWarnings = FALSE)
  file.copy(file.path(example_card, "CONFIG.TXT"), card)
  file.copy(list.files(file.path(example_card, day), full.names = TRUE), file.path(card, day))
  card
}
card_1 <- make_card("20261007")   # first card: 7 October
card_2 <- make_card("20261015")   # second card: 15 October
```

With real cards you do not need any of this: put the SD card in the
computer and give its path.

### The first card

``` r

output <- file.path(tempdir(), "AudiomothR_results", "box_01")

am <- read_audiomoth(card_1, coordinates = "41.00, -3.00", site = "River - bridge",
                     output = output, copy_to = TRUE)
#> ℹ /tmp/RtmpElCi7t/AudiomothR_results/box_01 is in the temporary folder of R: it
#>   is deleted when R closes.
#>   For your own recordings give a folder of your own, e.g. `output =
#>   "~/AudiomothR_results/box_01"`.
#> Copying the card to
#> /tmp/RtmpElCi7t/AudiomothR_results/box_01/recordings/20261007-20261007: 9 files
#> (2 MB).
#> ✔ Card copied (9 files): the analysis uses the copy, and the card can be
#>   formatted once you have checked it.
#> 
#> 
#> ── AudioMoth FACADE0012345678 ──────────────────────────────────────────────────
#> 
#> • Card: /tmp/RtmpElCi7t/card_20261007 (copied)
#> 
#> • Copy of the card (used from now on):
#> /tmp/RtmpElCi7t/AudiomothR_results/box_01/recordings/20261007-20261007
#> 
#> • Site of this card: River - bridge (41, -3; ±698 m; source: argument)
#> 
#> • Map: <https://www.openstreetmap.org/?mlat=41&mlon=-3#map=15/41/-3>
#> 
#> • Recordings: 8 in 1 day (2026-10-07 to 2026-10-07, Europe/Madrid time)
#> 
#> • Audio: 48,000 Hz, gain Medium, 0.4 min in total
#> 
#> • 5 with problems: duration < 3 s
#> 
#> • Battery: 4.9 V → 4.8 V
#> 
#> • Temperature: 12.5 to 16.3 °C
#> 
#> • Results in: /tmp/RtmpElCi7t/AudiomothR_results/box_01
```

### Some days later: the next card

The second card is read **with the same `output`**. The box was moved,
so its new coordinates and site are given:

``` r

am <- read_audiomoth(card_2, coordinates = "41.03, -2.97", site = "Pine forest",
                     output = output, copy_to = TRUE)
#> Copying the card to
#> /tmp/RtmpElCi7t/AudiomothR_results/box_01/recordings/20261015-20261015: 9 files
#> (2 MB).
#> ✔ Card copied (9 files): the analysis uses the copy, and the card can be
#>   formatted once you have checked it.
#> 
#> 
#> ── AudioMoth FACADE0012345678 ──────────────────────────────────────────────────
#> 
#> • Card: /tmp/RtmpElCi7t/card_20261015 (copied)
#> 
#> • Copy of the card (used from now on):
#> /tmp/RtmpElCi7t/AudiomothR_results/box_01/recordings/20261015-20261015
#> 
#> • Site of this card: Pine forest (41.03, -2.97; ±698 m; source: argument)
#> 
#> • Deployments of this box: 2 (River - bridge, Pine forest)
#> 
#> • Map:
#> <https://www.openstreetmap.org/?mlat=41.03&mlon=-2.97#map=15/41.03/-2.97>
#> 
#> • Recordings: 16 in 2 days (2026-10-07 to 2026-10-15, Europe/Madrid time)
#> 
#> • Audio: 48,000 Hz, gain Medium, 0.7 min in total
#> 
#> • 10 with problems: duration < 3 s
#> 
#> • Battery: 4.9 V → 4.5 V
#> 
#> • Temperature: 11.7 to 34.4 °C
#> 
#> • Results in: /tmp/RtmpElCi7t/AudiomothR_results/box_01
```

The summary now says *Deployments of this box: 2*. The deployments are
in `am$deployments` (and in `AudioMoth_<ID>_deployments.csv`):

``` r

am$deployments[, c("deployment", "site", "lat", "lon", "first_date", "last_date", "recordings")]
#>   deployment           site   lat   lon first_date  last_date recordings
#> 1  D20261007 River - bridge 41.00 -3.00 2026-10-07 2026-10-07          8
#> 2  D20261015    Pine forest 41.03 -2.97 2026-10-15 2026-10-15          8
```

and each recording knows its deployment and its location:

``` r

table(am$recordings$deployment, am$recordings$site)
#>            
#>             Pine forest River - bridge
#>   D20261007           0              8
#>   D20261015           8              0
```

What to know about the location of each card:

- `coordinates` given: they are used (recommended).
- Not given, and the card was already read before: the location it was
  given then.
- Not given, new card: the location of its `CONFIG.TXT` (with a warning,
  since it is only right if it was updated in the AudioMoth app when the
  box was moved) or, if there is none, R asks for it in the console,
  where pressing Enter reuses the site of the previous card.
- Reading **the same card again** replaces its deployment (it does not
  duplicate it); if new `coordinates` are given, its recordings are
  analysed again with the new location.

The copies of both cards are in `recordings/`, one folder per card:

``` r

list.files(file.path(output, "recordings"))
#> [1] "20261007-20261007" "20261015-20261015"
```

### Analysing all the cards

``` r

am <- analyze_birdnet(am)
```

[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
only analyses the recordings that have no result yet: after the first
card, adding a card analyses only the new one. With the location filter,
each card uses the species expected at **its own** site (vignette 2).
Here, without BirdNET, we load the detections of the example card, as in
vignette 1:

``` r

saved <- system.file("extdata", "example", "birdnet_detections.csv", package = "AudiomothR")
am$detections <- read_detections(saved)
file.copy(saved, file.path(output, "AudioMoth_FACADE0012345678_detections.csv"), overwrite = TRUE)
#> [1] TRUE
```

### Everything else works with all the cards

``` r

species_summary(am)
#>           scientific_name     common_name detections days recordings
#> 1       Motacilla cinerea    Gray Wagtail          1    1          1
#> 2            Cettia cetti Cetti's Warbler          1    1          1
#> 3 Troglodytes troglodytes   Eurasian Wren          1    1          1
#>   confidence_max confidence_mean location_prob example_candidates
#> 1         0.8222           0.822        0.2949                  0
#> 2         0.8196           0.820        0.5931                  0
#> 3         0.6319           0.632        0.2354                  0
obs <- export_observation(am, min_confidence = 0.5, min_detections = 1)
#> ✔ 3 records (3 species) for Observation.org in
#>   /tmp/RtmpElCi7t/AudiomothR_results/box_01/AudioMoth_FACADE0012345678_observation.csv.
#> ℹ Criteria: confidence ≥ 0.5, ≥ 1 detection per species and day.
obs[, c("date", "scientific name", "lat", "lng", "accuracy")]
#>         date         scientific name lat lng accuracy
#> 1 2026-10-07       Motacilla cinerea  41  -3      698
#> 2 2026-10-07            Cettia cetti  41  -3      698
#> 3 2026-10-07 Troglodytes troglodytes  41  -3      698
```

Each record of Observation.org takes the location of its own deployment:
the detections of 7 October are at the bridge (`41, -3`); if there had
been any on 15 October, they would be at the pine forest
(`41.03, -2.97`). The examples, the validation page and the report also
cover all the cards.

## Coming back another day

The results folder keeps everything, so the work can stop at any time
and go on another day (or on another computer, if the folder is in a
shared or synchronised disk). To recover the `am` object, read the box
again from its results folder: with `copy_to`, read the **copy** of a
card (the card itself may have been formatted):

``` r

copies <- list.files(file.path(output, "recordings"), full.names = TRUE)
am <- read_audiomoth(copies[2], output = output)
#> 
#> ── AudioMoth FACADE0012345678 ──────────────────────────────────────────────────
#> • Folder:
#> /tmp/RtmpElCi7t/AudiomothR_results/box_01/recordings/20261015-20261015
#> • Site of this card: Pine forest (41.03, -2.97; ±698 m; source: argument)
#> • Deployments of this box: 2 (River - bridge, Pine forest)
#> • Map:
#> <https://www.openstreetmap.org/?mlat=41.03&mlon=-2.97#map=15/41.03/-2.97>
#> • Recordings: 16 in 2 days (2026-10-07 to 2026-10-15, Europe/Madrid time)
#> • Audio: 48,000 Hz, gain Medium, 0.7 min in total
#> • 10 with problems: duration < 3 s
#> • Battery: 4.9 V → 4.5 V
#> • Temperature: 11.7 to 34.4 °C
#> • Results in: /tmp/RtmpElCi7t/AudiomothR_results/box_01
```

Nothing is copied or analysed again: the card was read before, so its
deployment, site and location are kept (no `coordinates` needed), and
the other deployments of the box are still there. The detections are
read from the results folder:

``` r

am$detections <- read_detections(am)
nrow(am$detections)
#> [1] 6
```

With BirdNET, `am <- analyze_birdnet(am)` does the same and, if a
recording was left without a result (an interrupted analysis), analyses
it.

In an interactive session, `output` can even be left out: R suggests the
folder used before for **the same box** (it remembers it by its device
ID), and Enter accepts it
([`choose_output()`](https://ajcanepa.github.io/AudiomothR/reference/choose_output.md)):

``` r

am <- read_audiomoth(copies[2])
#> ℹ Results folder of this box (outside the card; it gathers all the cards of the box).
#>   Press Enter to use '/tmp/.../AudiomothR_results/box_01', or type another path.
#> Results folder:
```

### When the card was not copied

Without `copy_to`, the inventory points to the files **on the card**.
When the card is no longer connected (or has been formatted):

- the results already obtained are kept, and the detections, the export
  to Observation.org and the report still work;
- the steps that need the audio do not:
  [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
  cannot analyse the recordings without a result (it warns *card not
  connected*), and
  [`extract_examples()`](https://ajcanepa.github.io/AudiomothR/reference/extract_examples.md)
  and
  [`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md)
  cannot cut the clips.

Connecting the card again at the same path, or reading it again with
[`read_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/read_audiomoth.md)
wherever it is mounted, solves it. **This is why `copy_to` is
recommended.**

## The report of a box

``` r

pdf <- create_report(am, title = "Monitoring of the river", open = FALSE)
```

``` r

basename(pdf)
```

*(This block was not run when building the vignette: Quarto was not
found on this computer.)*

The report of a box covers all its deployments: the map shows both
sites, and the tables of recordings and records state the site of each
one.

| Argument | Meaning |
|----|----|
| `recorders` | One box (`am`) or several (`list(am1, am2)`) |
| `by_recorder` | Several boxes: one section per box (`TRUE`, default) or all together (`FALSE`) |
| `output` | Folder of the report (by default `<output>/report/` of the box; required for several boxes) |
| `title` | Title of the report |
| `min_confidence` | Minimum confidence of the detections that count (0.5) |
| `map` | Draw the map (needs `maptiles`, `sf` and `terra` for the background) |
| `overwrite_template` | Replace a `report.qmd` edited by hand |

## Several boxes

Each box is read into its own folder, and
[`create_report()`](https://ajcanepa.github.io/AudiomothR/reference/create_report.md)
takes a list of them:

``` r

river  <- read_audiomoth("E:/", coordinates = "41.123456, -3.123456",
                         output = "~/AudiomothR_results/box_01", copy_to = TRUE)
forest <- read_audiomoth("F:/", coordinates = "41.200000, -3.300000",
                         output = "~/AudiomothR_results/box_02", copy_to = TRUE)
river  <- analyze_birdnet(river)
forest <- analyze_birdnet(forest)

# One section per box
create_report(list(river, forest), output = "~/AudiomothR_results/report_2026")

# All the boxes together (a single summary of the species of the area)
create_report(list(river, forest), by_recorder = FALSE, output = "~/AudiomothR_results/report_2026_all")
```

In the report, each box is named after its site or, when it has been at
several sites, after its device ID (`AudioMoth FACADE0012345678`); the
map shows all the sites of all the boxes.

To process many cards in a script,
[`process_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/process_audiomoth.md)
can be used for each one (with `Rscript`, `output` must always be
given):

``` r

cards <- c(box_01 = "/media/you/SD_01", box_02 = "/media/you/SD_02")
boxes <- lapply(names(cards), function(box) {
  process_audiomoth(cards[[box]], output = file.path("~/AudiomothR_results", box),
                    copy_to = TRUE, validation = TRUE)
})
create_report(boxes, output = "~/AudiomothR_results/report_2026")
```

## Editing the report

[`create_report()`](https://ajcanepa.github.io/AudiomothR/reference/create_report.md)
writes a Quarto folder: `report.qmd` (the text and the code of the
report), `report_data.rds` (the data), `report_functions.R` and the
figures. You can edit `report.qmd` (e.g. add a paragraph about the study
area or change a figure) and render it again, from a terminal in that
folder:

``` sh
quarto render report.qmd
```

or by calling
[`create_report()`](https://ajcanepa.github.io/AudiomothR/reference/create_report.md)
again, which **keeps your edits** (unless `overwrite_template = TRUE`)
and updates the data.

## Summary

| Situation | What to do |
|----|----|
| New card of a box | `read_audiomoth(card, coordinates, output = <folder of the box>, copy_to = TRUE)`, then `analyze_birdnet(am)` |
| The box was moved | The same, with the new `coordinates` and `site` |
| A location was wrong | Read that card again with the right `coordinates` |
| Coming back another day | `read_audiomoth(<copy of a card>, output = <folder of the box>)` and `analyze_birdnet(am)` or `read_detections(am)` |
| Another box | Another `output` folder |
| A report of several boxes | `create_report(list(am1, am2), output = ...)` |

See also
[`vignette("audiomothr-1-workflow")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-1-workflow.md)
for the steps of one card and
[`vignette("audiomothr-2-species")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-2-species.md)
for the choice of species.

## How to cite

See `citation("AudiomothR")` and the references of
[`vignette("audiomothr-1-workflow")`](https://ajcanepa.github.io/AudiomothR/articles/audiomothr-1-workflow.md).

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
#>  [9] rmarkdown_2.32    lifecycle_1.0.5   ps_1.9.3          cli_3.6.6        
#> [13] processx_3.9.0    sass_0.4.10       pkgdown_2.2.1     textshaping_1.0.5
#> [17] jquerylib_0.1.4   systemfonts_1.3.2 compiler_4.6.2    tools_4.6.2      
#> [21] ragg_1.5.2        bslib_0.12.0      evaluate_1.0.5    yaml_2.3.12      
#> [25] otel_0.3.0        jsonlite_2.0.0    rlang_1.3.0       fs_2.1.0
```
