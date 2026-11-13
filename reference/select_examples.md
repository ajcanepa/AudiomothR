# Chooses the best detections of each species

Only detections with a confidence of at least `min_confidence` are
accepted and, with `no_doubts = TRUE`, only those in which BirdNET
proposed no other species in the same 3 s window. The ones with the
highest confidence are taken, at most one per recording, so that the
examples are varied.

## Usage

``` r
select_examples(
  x,
  species,
  n = 3,
  min_confidence = 0.85,
  no_doubts = TRUE,
  one_per_recording = TRUE
)
```

## Arguments

- x:

  An `audiomoth` object with detections, or a data frame from
  [`read_detections()`](https://ajcanepa.github.io/AudiomothR/reference/read_detections.md).

- species:

  Names of the species: scientific or common names of BirdNET (case and
  accents do not matter) or IOC names. Also a named vector
  `c("Cettia cetti" = 3, ...)` with the number of examples of each
  species, as printed and returned by
  [`detected_species()`](https://ajcanepa.github.io/AudiomothR/reference/detected_species.md).

- n:

  Largest number of examples per species: one value for all of them or
  one per species. Not used when `species` already has the number of
  each one. Species with `n = 0` are skipped.

- min_confidence:

  Minimum confidence of the examples.

- no_doubts:

  Require that BirdNET proposed no other species in the same window.

- one_per_recording:

  At most one example from each recording.

## Value

A data frame with the chosen detections (column `example`: order within
its species).

## Examples

``` r
d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
                                 package = "AudiomothR"))
select_examples(d, "Cettia cetti", n = 1, min_confidence = 0.5)
#>          device_id deployment                    site lat lon precision_m
#> 1 FACADE0012345678  D20261007 Fictitious example site  41  -3         698
#>   day_folder                                 file path recording_start_utc
#> 1   20261007 FACADE0012345678_20261007_071500.WAV <NA> 2026-10-07 07:15:44
#>   local_date local_time utc_offset     time_zone start_s end_s scientific_name
#> 1 2026-10-07   09:15:47        200 Europe/Madrid       3     6    Cettia cetti
#>       common_name is_species confidence n_labels_window other_confidence_max
#> 1 Cetti's Warbler       TRUE     0.8196               1                    0
#>   no_doubts event location_prob birdnet_week        model example
#> 1      TRUE     5        0.5931           37 BirdNET v2.4       1
```
