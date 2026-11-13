# Processes an AudioMoth card from start to end

Chains all the steps:

1.  [`read_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/read_audiomoth.md):
    folder, `CONFIG.TXT`, location and inventory (and, with `copy_to`, a
    copy of the card on the disk, which is used from then on).

2.  [`prepare_audio()`](https://ajcanepa.github.io/AudiomothR/reference/prepare_audio.md):
    conversion to 48 kHz mono when needed.

3.  [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md):
    detections in `AudioMoth_<ID>_detections.csv`.

4.  [`export_observation()`](https://ajcanepa.github.io/AudiomothR/reference/export_observation.md):
    `AudioMoth_<ID>_observation.csv` (only the first time: an existing
    export, perhaps edited by hand, is kept unless `export = TRUE`).

5.  [`extract_examples()`](https://ajcanepa.github.io/AudiomothR/reference/extract_examples.md):
    audio, spectrogram and video of the best detections of
    `example_species` (when given).

6.  [`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md):
    page to validate the records by ear (when `validation = TRUE`).

7.  [`create_report()`](https://ajcanepa.github.io/AudiomothR/reference/create_report.md):
    PDF report (when `report = TRUE`).

## Usage

``` r
process_audiomoth(
  folder = choose_folder(),
  coordinates = NULL,
  site = NULL,
  precision_m = NULL,
  time_zone = "Europe/Madrid",
  output = NULL,
  copy_to = NULL,
  example_species = NULL,
  n_examples = 3,
  example_confidence = 0.85,
  video = TRUE,
  video_style = c("cursor", "scroll"),
  export = NULL,
  validation = FALSE,
  report = FALSE,
  ...
)
```

## Arguments

- folder:

  Folder with `CONFIG.TXT` and the daily folders. By default it is
  chosen with a dialog
  ([`choose_folder()`](https://ajcanepa.github.io/AudiomothR/reference/choose_folder.md)).
  A copy of the recordings without `CONFIG.TXT` is also accepted (then
  `coordinates` is required).

- coordinates:

  Coordinates of the site in any format accepted by
  [`parse_coordinates()`](https://ajcanepa.github.io/AudiomothR/reference/parse_coordinates.md).
  They take priority over those of `CONFIG.TXT`.

- site:

  Name of the sampling site of this deployment (optional; by default
  that of the previous deployment when it is in the same place).

- precision_m:

  Precision of the location in metres (the `accuracy` of
  Observation.org). By default, the one implied by the number of
  decimals.

- time_zone:

  Time zone of the local dates and times, as a name of
  [`OlsonNames()`](https://rdrr.io/r/base/timezones.html)
  (`"Europe/Madrid"`, `"Atlantic/Canary"`...). `"UTC+2"` is accepted and
  translated into the fixed zone `"Etc/GMT-2"`.

- output:

  Results folder (it is created if needed). By default it is asked for
  with
  [`choose_output()`](https://ajcanepa.github.io/AudiomothR/reference/choose_output.md).

- copy_to:

  Copy the card to the disk and work with the copy (see "Copy of the
  card"): `TRUE` (into the results folder) or the path of a backup
  folder. `NULL` (default): no copy, the card is read where it is.

- example_species:

  Species of which to extract examples: names, a named vector
  `c("Cettia cetti" = 3, ...)` with the examples of each one (see
  [`detected_species()`](https://ajcanepa.github.io/AudiomothR/reference/detected_species.md))
  or `"auto"`, which takes the species and numbers proposed by
  [`detected_species()`](https://ajcanepa.github.io/AudiomothR/reference/detected_species.md)
  with `example_confidence`. `NULL` (default) = none.

- n_examples:

  Examples per species (one value for all or one per species) when
  `example_species` are only names.

- example_confidence:

  Minimum confidence of the examples.

- video, video_style:

  Create the videos of the examples, and their style (`"cursor"` or
  `"scroll"`).

- export:

  Export to Observation.org: `NULL` (default) only when the CSV does not
  exist yet, `TRUE` always (an edited CSV is still kept), or `FALSE`.

- validation:

  Create the validation page
  ([`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md)).

- report:

  Create a PDF report with
  [`create_report()`](https://ajcanepa.github.io/AudiomothR/reference/create_report.md)
  (needs Quarto).

- ...:

  Other arguments for
  [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
  (e.g. `language`, `min_confidence`, `location_threshold`,
  `species_list`).

## Value

Invisibly, the `audiomoth` object with its detections.

## Details

If it is interrupted, running it again continues where it stopped. When
`output` is not given, the results folder is asked for in the console
(see
[`choose_output()`](https://ajcanepa.github.io/AudiomothR/reference/choose_output.md)).

## Examples

``` r
if (FALSE) { # \dontrun{
# Not run: it reads a real card and runs BirdNET, which is installed the
# first time (Python, TensorFlow and the model: about 3 GB)
am <- process_audiomoth(
  coordinates = "41.123456, -3.123456",    # copied from Google Earth
  output = "~/AudiomothR_results/box_01",
  copy_to = TRUE,                          # copy the card first and work on the copy
  example_species = "auto",
  validation = TRUE
)

# With an own list of species instead of the location filter
am <- process_audiomoth(output = "~/AudiomothR_results/box_01", copy_to = "/media/backup",
                        species_list = "~/species_list.txt")
} # }
```
