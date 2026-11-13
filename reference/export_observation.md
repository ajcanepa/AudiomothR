# Exports the detections in the format of Observation.org

Groups the detections into one record per species and day. BirdNET names
are translated into the names of the bird species of Observation.org,
which follows the IOC World Bird List with its own lumps and genera
(e.g. *Corvus cornix* is exported as *Corvus corone*, with the BirdNET
name in the notes): every bird of BirdNET v2.4 has a valid name of
Observation.org. Classes that are not birds (noise, human voice, frogs,
insects...) are left out. Species that IOC has split are translated
according to the location when the rule is clear (e.g. *Cecropis
daurica* is *Cecropis rufula* in Europe) and are reported otherwise.

## Usage

``` r
export_observation(
  am,
  min_confidence = 0.8,
  min_detections = 2,
  no_doubts_only = FALSE,
  species = NULL,
  from = NULL,
  to = NULL,
  validation = NULL,
  validated_only = FALSE,
  method = "Oído",
  counting_method = "Sin especificar",
  activity = "",
  is_certain = c("auto", "True", "False"),
  notes = NULL,
  language = default_language(),
  equivalences = NULL,
  file = NULL,
  overwrite = FALSE
)
```

## Arguments

- am:

  An `audiomoth` object with detections (see
  [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)).
  Each record takes the location (`lat`, `lng`, `accuracy`) of the
  deployment (card) of its recordings, as it is now in `am`.

- min_confidence:

  Minimum confidence of the detections that count.

- min_detections:

  Minimum number of detections (events) of the species in the day.

- no_doubts_only:

  Count only the detections without another species in the same window.

- species:

  Only these species (scientific or common name of BirdNET, or name of
  Observation.org).

- from, to:

  Local dates (`"2026-10-07"` or `"07/10/2026"`) that limit the period.

- validation:

  Use the validation of
  [`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md):
  `NULL` (default) when there is one, `TRUE` to require it, `FALSE` to
  ignore it.

- validated_only:

  Export only the records validated as correct.

- method, counting_method, activity:

  Fixed values of those columns, checked against the values that
  Observation.org accepts for birds (in Spanish, as in its import
  example).

- is_certain:

  `"auto"` (default: `"True"` for the records validated by ear and
  `"False"` for the rest, since the identification is automatic),
  `"True"` or `"False"`.

- notes:

  Text of the column `notes`. By default
  `"Identified with BirdNET <version>"`
  (`"ID mediante BirdNET <version>"` when `language` is Spanish),
  followed by the best detection of the record.

- language:

  Language of the default notes.

- equivalences:

  Named vector of own equivalences
  `c("BirdNET name" = "Observation.org name")`, which take priority. The
  names must be bird species of Observation.org (or their synonyms).

- file:

  Output CSV. By default `<output>/AudioMoth_<ID>_observation.csv`.

- overwrite:

  Overwrite the CSV even if it has been edited by hand.

## Value

Invisibly, the exported data frame (columns of Observation.org).

## Details

**Validation.** When the records have been checked by ear with
[`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md),
the decisions are applied: records marked as not valid are left out,
relabelled ones are exported under their new name, and records marked as
valid are exported even if they do not meet `min_confidence` or
`min_detections` (and, by default, with `is certain = True`).

**Hand-edited files.** If `AudioMoth_<ID>_observation.csv` has been
edited since it was exported, it is not overwritten (unless
`overwrite = TRUE`): the new export is saved with the date and time in
its name. The criteria used are saved next to it, in
`AudioMoth_<ID>_observation.json`.

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
#> • Results in: /tmp/RtmpQ97hCs/file22e58a35c54
am$detections <- read_detections(system.file("extdata", "example",
  "birdnet_detections.csv", package = "AudiomothR"))
obs <- export_observation(am, min_confidence = 0.5, min_detections = 1)
#> ✔ 3 records (3 species) for Observation.org in
#>   /tmp/RtmpQ97hCs/file22e58a35c54/AudioMoth_FACADE0012345678_observation.csv.
#> ℹ Criteria: confidence ≥ 0.5, ≥ 1 detection per species and day.
obs[, c("date", "time", "scientific name", "is certain")]
#>         date  time         scientific name is certain
#> 1 2026-10-07 08:40       Motacilla cinerea      False
#> 2 2026-10-07 09:15            Cettia cetti      False
#> 3 2026-10-07 10:05 Troglodytes troglodytes      False
```
