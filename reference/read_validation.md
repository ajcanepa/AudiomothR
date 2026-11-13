# Reads the decisions of the validation by ear

Looks for the decisions of
[`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md):
the file given in `file` or, otherwise, the most recent
`AudioMoth_<ID>_validation.csv` with some decision, either in the
validation folder of the results or in the Downloads folder (where the
browser saves it; set another one with
`options(AudiomothR.downloads = "/path")`). A file found in Downloads is
copied into the validation folder, so that it stays with the results.

## Usage

``` r
read_validation(am, file = NULL, required = FALSE, quiet = FALSE)
```

## Arguments

- am:

  An `audiomoth` object.

- file:

  CSV file with the decisions (optional).

- required:

  Error when there are no decisions.

- quiet:

  Do not report which file is used.

## Value

A data frame with one row per record (`record_id`, `date`,
`scientific_name`, `decision`: `"valid"`, `"invalid"`, `"unsure"` or
`NA`, `new_name`, `comment`...), or `NULL` when there is no validation.

## Examples

``` r
card <- system.file("extdata", "example", "card", package = "AudiomothR")
am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#> 
#> ── AudioMoth FACADE0012345678 ──────────────────────────────────────────────────
#> • Folder: /home/runner/work/_temp/Library/AudiomothR/extdata/example/card
#> • Site of this card: AudioMoth FACADE0012345678 (41, -3; ±698 m; source:
#> argument)
#> • Map: <https://www.openstreetmap.org/?mlat=41&mlon=-3#map=15/41/-3>
#> • Recordings: 16 in 2 days (2026-10-07 to 2026-10-15, Europe/Madrid time)
#> • Audio: 48,000 Hz, gain Medium, 0.7 min in total
#> • 10 with problems: duration < 3 s
#> • Battery: 4.9 V → 4.5 V
#> • Temperature: 11.7 to 34.4 °C
#> • Results in: /tmp/RtmpoqZwSo/file22a7302c800c
read_validation(am)   # NULL: nothing validated yet
#> NULL
```
