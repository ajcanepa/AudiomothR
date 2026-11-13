# Reads the detections of an AudioMoth

Reads the detections of an AudioMoth

## Usage

``` r
read_detections(x)
```

## Arguments

- x:

  An `audiomoth` object (its detections, or the CSV of its results
  folder) or the path of an `AudioMoth_<ID>_detections.csv` file.

## Value

A data frame with one row per detection (3 s window and species). When
`x` is an `audiomoth` object, the paths of the recordings are taken from
its current inventory (the card may have been moved since the analysis).

## Examples

``` r
d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
                                 package = "AudiomothR"))
d[, c("local_time", "scientific_name", "confidence", "no_doubts")]
#>   local_time         scientific_name confidence no_doubts
#> 1   08:40:09       Motacilla cinerea     0.8222     FALSE
#> 2   08:40:09          Motacilla alba     0.1448     FALSE
#> 3   08:40:12       Motacilla cinerea     0.4824     FALSE
#> 4   08:40:12          Motacilla alba     0.1194     FALSE
#> 5   09:15:47            Cettia cetti     0.8196      TRUE
#> 6   10:05:04 Troglodytes troglodytes     0.6319      TRUE
```
