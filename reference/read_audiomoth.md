# Reads an AudioMoth card: configuration, location and inventory

Identifies the recordings of each daily folder with the data of the
`CONFIG.TXT` file (device, sample rate, gain...) and with the metadata
that AudioMoth writes in each WAV file (start time in UTC, gain, battery
and temperature, from the comment or the GUANO block). The inventory is
saved as `AudioMoth_<ID>_recordings.csv` in the `output` folder. The
audio is not loaded.

## Usage

``` r
read_audiomoth(
  folder = choose_folder(),
  coordinates = NULL,
  site = NULL,
  precision_m = NULL,
  time_zone = "Europe/Madrid",
  output = NULL,
  copy_to = NULL
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

## Value

An object of class `audiomoth`: a list with `folder` (the copy when
`copy_to` is used), `card_folder` (the original card, or `NULL`),
`config`, `location`, `site` and `deployment` (of this card),
`time_zone`, `output`, `recordings` (data frame with one row per WAV
file of all the cards of the box, with the `deployment`, `site`, `lat`,
`lon` and `precision_m` of its deployment) and `deployments` (one row
per card).

## Details

**Copy of the card (recommended).** With `copy_to`, the card is first
copied to the disk and everything is done with the copy: the card can be
formatted for the next deployment as soon as the copy is finished, the
recordings are kept as a backup, and the steps that go back to the audio
([`extract_examples()`](https://ajcanepa.github.io/AudiomothR/reference/extract_examples.md),
[`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md),
a new analysis) keep working after the card is gone. Without it, the
card is read where it is (it is never modified), and those steps need
the card connected at the same path. `copy_to = TRUE` copies the card
into the results folder
(`<output>/recordings/<first date>-<last date>/`); a folder (e.g. on an
external disk) copies it into
`<copy_to>/AudioMoth_<ID>/<first date>-<last date>/`, so one backup
folder can keep the cards of every box. The copy keeps the structure of
the card (`CONFIG.TXT` and daily folders) and the dates of the files;
each file is checked by its size, and files already copied are skipped,
so an interrupted copy continues where it stopped. The original folder
is kept in the column `card_folder` of the deployments. Reading the copy
again later (with `folder`) needs no `copy_to`.

**Location of the deployment.** Taken from `coordinates` when given (the
recommended way, since the box may have moved); for a card read before,
the location it was given then; otherwise from the `Location` field of
`CONFIG.TXT`, with a warning (it must have been updated in the AudioMoth
app when the box was placed, and it only has two decimals, about 700 m).
If there is none and the session is interactive, it is asked for in the
console (Enter = the site of the previous deployment): just copy and
paste the position of a point from Google Earth or Google Maps (see
[`parse_coordinates()`](https://ajcanepa.github.io/AudiomothR/reference/parse_coordinates.md)).
When `coordinates` and `CONFIG.TXT` are more than 10 km apart, a warning
is given (and an error when latitude and longitude look swapped).

**Recordings that are not valid** (column `problem`): unreadable or
empty files, interrupted recordings, recordings shorter than 3 s,
recordings without a date and duplicated copies of the same recording.
Triggered recordings (`*T.WAV`, amplitude or frequency threshold) are
recognised and their real duration, with the silences, is used.

**One results folder per box.** The `output` folder gathers all the
cards of a box (AudioMoth): each card read is a *deployment*, with its
own dates, site and location, and its recordings are added to those of
the cards read before (`AudioMoth_<ID>_deployments.csv`). BirdNET, the
export to Observation.org, the validation and the report then cover the
whole period of the box, each recording with the location of its
deployment, so a box can be moved between sampling sites. Reading a card
again replaces its deployment (and keeps its location unless
`coordinates` are given). The cards of two different boxes cannot share
a folder. It is better outside the card, which is usually formatted for
the next deployment. When `output` is not given, it is asked for in the
console (see
[`choose_output()`](https://ajcanepa.github.io/AudiomothR/reference/choose_output.md)),
suggesting `~/AudiomothR_results/AudioMoth_<ID>` or the folder chosen
before for the same box; in a non-interactive session (`Rscript`) it is
the folder remembered for the box or, if there is none, it must be
given.

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
#> • Results in: /tmp/RtmpQ97hCs/file22e568726174
head(am$recordings[, c("file", "start_local", "duration_s", "valid", "problem")])
#>                                   file         start_local duration_s valid
#> 1 FACADE0012345678_20261007_041500.WAV 2026-10-07 06:15:00       0.05 FALSE
#> 2 FACADE0012345678_20261007_055000.WAV 2026-10-07 07:50:00       0.05 FALSE
#> 3 FACADE0012345678_20261007_064000.WAV 2026-10-07 08:40:09       7.00  TRUE
#> 4 FACADE0012345678_20261007_071500.WAV 2026-10-07 09:15:44       7.00  TRUE
#> 5 FACADE0012345678_20261007_073000.WAV 2026-10-07 09:30:00       0.05 FALSE
#> 6 FACADE0012345678_20261007_080500.WAV 2026-10-07 10:05:04       7.00  TRUE
#>          problem
#> 1 duration < 3 s
#> 2 duration < 3 s
#> 3           <NA>
#> 4           <NA>
#> 5 duration < 3 s
#> 6           <NA>

# Copying the card first into the results folder (recommended with real cards)
out <- tempfile()
am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = out, copy_to = TRUE)
#> Copying the card to
#> /tmp/RtmpQ97hCs/file22e558cfcfb8/recordings/20261007-20261015: 17 files (4 MB).
#> ✔ Card copied (17 files): the analysis uses the copy, and the card can be
#>   formatted once you have checked it.
#> 
#> ── AudioMoth FACADE0012345678 ──────────────────────────────────────────────────
#> • Card: /home/runner/work/_temp/Library/AudiomothR/extdata/example/card
#> (copied)
#> • Copy of the card (used from now on):
#> /tmp/RtmpQ97hCs/file22e558cfcfb8/recordings/20261007-20261015
#> • Site of this card: AudioMoth FACADE0012345678 (41, -3; ±698 m; source:
#> argument)
#> • Map: <https://www.openstreetmap.org/?mlat=41&mlon=-3#map=15/41/-3>
#> • Recordings: 16 in 2 days (2026-10-07 to 2026-10-15, Europe/Madrid time)
#> • Audio: 48,000 Hz, gain Medium, 0.7 min in total
#> • 10 with problems: duration < 3 s
#> • Battery: 4.9 V → 4.5 V
#> • Temperature: 11.7 to 34.4 °C
#> • Results in: /tmp/RtmpQ97hCs/file22e558cfcfb8
am$folder   # the copy: <output>/recordings/20261007-20261015
#> [1] "/tmp/RtmpQ97hCs/file22e558cfcfb8/recordings/20261007-20261015"
```
