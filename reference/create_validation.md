# Creates a page to validate the records by ear

BirdNET makes mistakes, above all with species that are rare at the site
or detected with low confidence. This function prepares a validation
page (`<output>/validation/AudioMoth_<ID>_validation.html`) to check the
records before exporting them to Observation.org:

## Usage

``` r
create_validation(
  am,
  min_confidence = 0.5,
  min_detections = 1,
  n_clips = 2,
  margin_s = 1,
  spectrograms = TRUE,
  open = interactive()
)
```

## Arguments

- am:

  An `audiomoth` object with detections (see
  [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)).

- min_confidence:

  Only detections with at least this confidence are grouped into
  records.

- min_detections:

  Minimum number of detections of the species in the day for the record
  to be validated.

- n_clips:

  Audio clips per record (the best detections, from different
  recordings).

- margin_s:

  Seconds of audio before and after each detection.

- spectrograms:

  Draw the spectrogram of each clip (slower).

- open:

  Open the page in the browser.

## Value

Invisibly, the path of the HTML page.

## Details

- one card per species and day (the unit of a record of
  Observation.org), sorted from the **least plausible** to the most
  plausible: the product of the highest confidence and the probability
  of occurrence of the species at the site and week (BirdNET metadata
  model, when known);

- for each record, `n_clips` audio clips of the best detections (from
  different recordings) with their spectrograms;

- buttons to mark the record as valid, not valid or unsure, a box to
  choose another species (with autocompletion among the BirdNET species)
  and a comment.

The page works offline in any browser, without R (the `validation/`
folder can be sent to someone else). Decisions are kept in the browser
while working; the button **Download decisions (CSV)** saves them as
`AudioMoth_<ID>_validation.csv`. Then
[`export_observation()`](https://ajcanepa.github.io/AudiomothR/reference/export_observation.md)
applies them automatically: it looks for that file in the validation
folder and in the Downloads folder (see
[`read_validation()`](https://ajcanepa.github.io/AudiomothR/reference/read_validation.md)).
A spreadsheet can also be used instead of the page: fill in the columns
`decision` (`valid`, `invalid` or `unsure`) and `new_name` of the CSV
file of the validation folder.

Running the function again (e.g. after analysing more recordings) keeps
the decisions already saved in the validation folder.

## Examples

``` r
# \donttest{
card <- system.file("extdata", "example", "card", package = "AudiomothR")
am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#> ℹ /tmp/RtmpXUCCMs/file233720ae1340 is in the temporary folder of R: it is
#>   deleted when R closes.
#>   For your own recordings give a folder of your own, e.g. `output =
#>   "~/AudiomothR_results/box_01"`.
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
#> • Results in: /tmp/RtmpXUCCMs/file233720ae1340
am$detections <- read_detections(system.file("extdata", "example",
  "birdnet_detections.csv", package = "AudiomothR"))
page <- create_validation(am, open = FALSE)
#> Preparing the audio clips ■■■■■■■■■■■                       33% | ETA:  3s
#> Preparing the audio clips ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100% | ETA:  0s
#> ✔ Validation page with 3 records in
#>   /tmp/RtmpXUCCMs/file233720ae1340/validation/AudioMoth_FACADE0012345678_validation.html.
#> ℹ Listen and decide, press Download decisions (CSV) and run
#>   `export_observation(am)`: the decisions are applied automatically.
# }
```
