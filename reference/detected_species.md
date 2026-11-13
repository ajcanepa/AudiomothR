# Detected species, ready to choose examples

Summarises the detected species (like
[`species_summary()`](https://ajcanepa.github.io/AudiomothR/reference/species_summary.md))
and prints a vector `c("scientific name" = n, ...)` ready to copy,
change the `n` and paste into
[`extract_examples()`](https://ajcanepa.github.io/AudiomothR/reference/extract_examples.md).
The proposed `n` is the number of examples that meet the criteria of
[`select_examples()`](https://ajcanepa.github.io/AudiomothR/reference/select_examples.md)
(confidence of at least `example_confidence`, no doubts and one per
recording), at most `n_max`. The same vector is returned (invisibly), so
it can also be passed on directly:
`extract_examples(am, detected_species(am))`.

## Usage

``` r
detected_species(
  x,
  min_confidence = 0.5,
  example_confidence = 0.85,
  no_doubts = TRUE,
  n_max = 3,
  print = TRUE
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

- n_max:

  Largest number of examples proposed per species.

- print:

  Print the vector.

## Value

Invisibly, a named integer vector (species = number of examples) with
the summary of
[`species_summary()`](https://ajcanepa.github.io/AudiomothR/reference/species_summary.md)
(plus the column `n_proposed`) as attribute `"summary"`.

## Details

With several recorders, `n` is the largest number of examples that one
recorder can give, since
[`extract_examples()`](https://ajcanepa.github.io/AudiomothR/reference/extract_examples.md)
works recorder by recorder.

BirdNET confidence is a score, not the probability that the
identification is right: it helps to sort the detections, but only
listening to the examples tells whether they are correct (see
[`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md)).

## Examples

``` r
d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
                                 package = "AudiomothR"))
species <- detected_species(d, example_confidence = 0.5)
#> # Species with confidence >= 0.5. n = examples that meet the criteria
#> # (confidence >= 0.5, no doubts, one per recording), up to 3. Change the n and paste it
#> # into extract_examples(am, species).
#> species <- c(
#>   "Motacilla cinerea"       = 0,  # Gray Wagtail | 1 detection | confidence max. 0.82, mean 0.82
#>   "Cettia cetti"            = 1,  # Cetti's Warbler | 1 detection | confidence max. 0.82, mean 0.82
#>   "Troglodytes troglodytes" = 1   # Eurasian Wren | 1 detection | confidence max. 0.63, mean 0.63
#> )
attr(species, "summary")
#>           scientific_name     common_name detections days recordings
#> 1       Motacilla cinerea    Gray Wagtail          1    1          1
#> 2            Cettia cetti Cetti's Warbler          1    1          1
#> 3 Troglodytes troglodytes   Eurasian Wren          1    1          1
#>   confidence_max confidence_mean location_prob example_candidates n_proposed
#> 1         0.8222           0.822        0.2949                  0          0
#> 2         0.8196           0.820        0.5931                  1          1
#> 3         0.6319           0.632        0.2354                  1          1
```
