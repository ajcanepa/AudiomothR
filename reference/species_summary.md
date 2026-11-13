# Summary of the detections by species

Counts, for each species, the detections with a confidence of at least
`min_confidence`. Detections in overlapping windows of the same song
(see the `overlap` argument of
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md))
count as one event.

## Usage

``` r
species_summary(
  x,
  min_confidence = 0.5,
  example_confidence = 0.85,
  no_doubts = TRUE,
  species_only = TRUE
)
```

## Arguments

- x:

  An `audiomoth` object with detections, a list of them (several
  recorders) or a data frame from
  [`read_detections()`](https://ajcanepa.github.io/AudiomothR/reference/read_detections.md).

- min_confidence:

  Only detections with at least this confidence.

- example_confidence, no_doubts:

  Criteria of the examples (those of
  [`select_examples()`](https://ajcanepa.github.io/AudiomothR/reference/select_examples.md)),
  used to count the `example_candidates`.

- species_only:

  Leave out the BirdNET classes that are not species ("Engine", "Human
  vocal", "Dog"...).

## Value

A data frame with one row per species: `detections` (events), `days`,
`recordings`, maximum and mean confidence, `location_prob` (lowest
probability of occurrence at the site in the weeks with detections, from
the BirdNET metadata model; `NA` when unknown) and `example_candidates`
(recordings with a detection that meets the criteria of the examples).

## Examples

``` r
d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
                                 package = "AudiomothR"))
species_summary(d, min_confidence = 0.5)
#>           scientific_name     common_name detections days recordings
#> 1       Motacilla cinerea    Gray Wagtail          1    1          1
#> 2            Cettia cetti Cetti's Warbler          1    1          1
#> 3 Troglodytes troglodytes   Eurasian Wren          1    1          1
#>   confidence_max confidence_mean location_prob example_candidates
#> 1         0.8222           0.822        0.2949                  0
#> 2         0.8196           0.820        0.5931                  0
#> 3         0.6319           0.632        0.2354                  0
```
