# AudiomothR

[![R-CMD-check](https://github.com/ajcanepa/AudiomothR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/ajcanepa/AudiomothR/actions/workflows/R-CMD-check.yaml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23646408.svg)](https://doi.org/10.5281/zenodo.23646408)

R package to process the cards of **AudioMoth** recorders, from the SD card
to the records of a citizen-science platform:

1. **Read the card**: configuration (`CONFIG.TXT`), location and metadata of
   each WAV file (start time in UTC, battery, temperature), with checks of
   faulty, duplicated or triggered recordings.
2. **Analyse the recordings with BirdNET** through
   [birdnetR](https://birdnet-team.github.io/birdnetR/), with a species filter
   by location and week, and a cache that resumes interrupted analyses.
3. **Review the species** and **extract examples**: the exact sound of the
   best detections, their spectrogram and a **video of the spectrogram** with
   the audio.
4. **Validate the records by ear** (optional) on a web page that works in any
   browser, from the least to the most plausible.
5. **Export to Observation.org**, translating BirdNET names into the names
   of Observation.org.
6. Create a **PDF report** of one or several recorders.

---

## 1. Requirements

| What | Required | What for | How to install |
|---|---|---|---|
| **R ≥ 4.1** | Yes | — | <https://cran.r-project.org> |
| R packages `birdnetR`, `tuneR`, `processx`, `cli`, `reticulate`, `rlang` | Yes | BirdNET, audio, external programs, messages | Installed with AudiomothR |
| **ffmpeg** | Yes | Converting audio to 48 kHz, clips and MP4 videos | Linux: `sudo apt install ffmpeg` · macOS: `brew install ffmpeg` · Windows: `winget install ffmpeg` |
| **Internet connection** (first time only) | Yes | birdnetR downloads its Python, TensorFlow and the BirdNET model | Automatic: Python does not need to be installed by hand |
| ~3 GB of disk | Yes | Python environment of BirdNET (Python 3.11 and TensorFlow 2.15, in the reticulate/uv cache) and the model (73 MB) | Automatic with `setup_birdnet()` (or the first `analyze_birdnet()`) |
| `seewave` | No | Spectrogram computation (AudiomothR has an equivalent one of its own) | `install.packages("seewave")` |
| `rstudioapi` or `tcltk` | No | Dialog to choose the card folder | Come with RStudio / R |
| **Quarto ≥ 1.4**, `knitr`, `rmarkdown` | No | PDF report (`create_report()`); no LaTeX needed | Included in RStudio and Positron; otherwise <https://quarto.org> |
| `maptiles`, `sf`, `terra` | No | Map of the recorders on OpenStreetMap in the report (without them, a map without background) | `install.packages(c("maptiles", "sf", "terra"))` |
| `testthat` | No | Tests | `install.packages("testthat")` |

## 2. Installation

```r
install.packages("remotes")
remotes::install_github("ajcanepa/AudiomothR")            # latest version
remotes::install_github("ajcanepa/AudiomothR@v0.3.0")     # a given version
```

Check that everything is ready:

```r
library(AudiomothR)
check_requirements()   # what is installed, what is missing, language of the names
setup_birdnet()        # the 1st time: installs Python, TensorFlow and the BirdNET model (a few minutes)
```

`setup_birdnet()` works the same on **Windows, macOS (Intel and Apple
silicon) and Linux**: birdnetR installs its own Python with uv, so neither
Python nor TensorFlow have to be installed by hand, and AudiomothR downloads
the BirdNET model itself (with retries and an integrity check) into the folder
where BirdNET looks for it:

| System | Model folder |
|---|---|
| Windows | `%APPDATA%\birdnet\models\v2.4\TFLite` |
| macOS | `~/Library/Application Support/birdnet/models/v2.4/TFLite` |
| Linux | `~/.local/share/birdnet/models/v2.4/TFLite` |

Besides R, only **ffmpeg** has to be installed (see the table above) and, for
the report, Quarto. On Windows, TensorFlow needs the *Microsoft Visual C++
Redistributable*, which almost every computer already has; if loading BirdNET
fails with a message about `msvcp140.dll`, install it from
<https://aka.ms/vs/17/release/vc_redist.x64.exe>.

## 3. Quick start (everything in one call)

```r
library(AudiomothR)

am <- process_audiomoth(
  folder = "/path/to/the/card",                   # or without it: a dialog opens
  coordinates = "41°07'24.4\"N 3°07'24.4\"W",     # copied from Google Earth
  site = "River - bridge",                        # optional
  output = "~/AudioMoth_results/river_bridge",    # one folder per card
  example_species = "auto",                       # examples of the detected species
  validation = TRUE,                              # page to validate the records by ear
  report = TRUE                                   # PDF report (needs Quarto)
)
```

The **folder** is the root of the card: the one that contains `CONFIG.TXT` and
the daily folders (`20261006/`, `20261007/`...). The **output** folder keeps
the results; when it is not given, it is asked for in the console, suggesting
`~/AudiomothR_results/AudioMoth_<ID>_<date>` (or the folder chosen last time
for the same card). In scripts run with `Rscript` it must be given.

## 4. Step by step

```r
library(AudiomothR)

# 1. Card, CONFIG.TXT, location and inventory of the recordings
am <- read_audiomoth("/path/to/the/card", coordinates = "41.123456, -3.123456",
                     output = "~/AudioMoth_results/card_01")

# 2-3. Audio ready for BirdNET and analysis (it resumes if interrupted)
am <- prepare_audio(am)                 # optional: analyze_birdnet() does it
am <- analyze_birdnet(am)               # common names in the language of the system
am <- analyze_birdnet(am, language = "es")   # ...or in another one (no new analysis)

# 4. Which species: prints a vector ready to copy, change the n and paste
species <- detected_species(am)
#> species <- c(
#>   "Cettia cetti"            = 3,  # Cetti's Warbler | 41 detections | confidence max. 0.97, mean 0.71
#>   "Troglodytes troglodytes" = 2,  # Eurasian Wren | 12 detections | ...
#> )

# 5. Examples (WAV + PNG + MP4) of the chosen species
extract_examples(am, species)                                   # the vector as returned
extract_examples(am, c("Cettia cetti" = 3, "Eurasian Wren" = 1))
extract_examples(am, "Cettia cetti", style = "scroll")           # another style of video

# 6. Validation by ear (optional): open the page, decide, download the decisions
create_validation(am)

# 7. CSV for Observation.org (applies the validation automatically)
export_observation(am)

# 8. PDF report (one recorder, or several: one section each or all together)
create_report(am)
create_report(list(am1, am2, am3), by_recorder = FALSE, output = "report_river")
```

### Resuming the work another day

Recordings already analysed are not analysed again: just repeat

```r
am <- read_audiomoth("/path/to/the/card", coordinates = "41.123456, -3.123456",
                     output = "~/AudioMoth_results/card_01")
am <- analyze_birdnet(am)     # only analyses what is missing
```

The BirdNET cache (`<output>/birdnet/`) keeps one folder per combination of
parameters: changing a parameter analyses the card again **without deleting
the previous results**, and going back to the previous parameters reuses
them. Changing `language` or raising `min_confidence` above 0.1 does not need
a new analysis. If the location changes after the analysis (e.g. to correct
it), `export_observation()` uses the current one.

## 5. Functions

| Function | What it does | Returns |
|---|---|---|
| `process_audiomoth()` | The whole workflow in one call | `audiomoth` object |
| `check_requirements()` | Which requirements (ffmpeg, birdnetR, Quarto...) are installed, how to install the missing ones and the language of the common names | Logical vector |
| `setup_birdnet()` | Installs and checks BirdNET (Python environment and model) | `TRUE` |
| `choose_folder()` | Dialog to choose the folder of the card | Path |
| `choose_output()` | Asks for the results folder in the console | Path |
| `read_audiomoth(folder, coordinates, site, precision_m, time_zone, output)` | Reads `CONFIG.TXT`, the location and the metadata of all the WAV files; saves the inventory | `audiomoth` object (`am$config`, `am$location`, `am$recordings`) |
| `read_config(file)` | Reads a `CONFIG.TXT` file | List of settings |
| `parse_coordinates(text)` | Reads coordinates copied from Google Earth / Maps or a GPS | `lat`, `lon`, `precision_m` |
| `prepare_audio(am)` | Converts to 48 kHz mono what needs it (expanding triggered recordings) | `am` with `birdnet_path` |
| `analyze_birdnet(am, min_confidence, language, version, location_filter, ...)` | Analyses with BirdNET and saves the CSV of detections | `am` with `am$detections` |
| `read_detections(x)` | Reads the detections of an `am` or of an `AudioMoth_<ID>_detections.csv` | Data frame |
| `species_summary(x, min_confidence)` | Summary by species: detections, days, confidence, probability of occurrence, candidate examples | Data frame |
| `detected_species(x, min_confidence, example_confidence, n_max)` | Prints the detected species as a vector `c("species" = n, ...)` ready to paste into `extract_examples()`, and returns it | Named vector |
| `select_examples(x, species, n, ...)` | Chooses the best detections (without creating files) | Data frame |
| `extract_examples(am, species, n, margin_s, style, ...)` | Creates the WAV, PNG and MP4 of each example | Index of examples |
| `spectrogram_image(wav, file, ...)` | PNG spectrogram of any WAV file | Path |
| `spectrogram_video(wav, file, style, ...)` | MP4 video of the spectrogram of any WAV file, with its audio | Path |
| `create_validation(am, min_confidence, n_clips, ...)` | Web page to validate the records by ear | Path of the page |
| `read_validation(am, file)` | Reads the decisions of the validation | Data frame |
| `export_observation(am, min_confidence, min_detections, ...)` | Import CSV for Observation.org | Data frame |
| `create_report(recorders, by_recorder, output, ...)` | PDF report (Quarto + Typst) of one or several recorders | Path of the PDF |

The full help of each function is in R: `?analyze_birdnet`, `?export_observation`...

## 6. Location

AudioMoth only writes the location in `CONFIG.TXT` when it was set in its
app, and with **two decimals (~700 m)**. Therefore:

1. If `coordinates` are given, they are used (with a warning if they are
   more than 10 km away from the `CONFIG.TXT`, and an error if latitude and
   longitude look swapped).
2. Otherwise, the location of `CONFIG.TXT` is used (with a note about its
   low precision).
3. If there is none either, it is asked for in the console in an interactive
   session (with a map link to check it); otherwise there is an error asking
   for `coordinates`.

`coordinates` accepts what is copied from **Google Earth**, **Google Maps**
or a **GPS**:

| Format | Example |
|---|---|
| Decimal degrees (Google Maps / Earth) | `"41.123456, -3.123456"` |
| Degrees, minutes and seconds | `"41°07'24.4\"N 3°07'24.4\"W"` |
| Spanish hemisphere letters (O = west) | `"41°07'24.4\"N 3°07'24.4\"O"` |
| Degrees and decimal minutes | `"41°07.407'N 3°07.407'W"` |
| Hemisphere first (handheld GPS) | `"N41 07.407 W3 07.407"` |
| Without symbols | `"41 07 24.4 N 3 07 24.4 W"` |
| Google Earth placemark (KML) | `"<coordinates>-3.123456,41.123456,0</coordinates>"` |
| Google Maps link | `"https://www.google.com/maps/@41.123456,-3.123456,17z"` |
| Decimal comma | `"41,123456 -3,123456"` |
| Numeric vector | `c(41.123456, -3.123456)` |

Without hemisphere letters the **latitude goes first**. The precision (column
`accuracy` of Observation.org) follows from the decimals written; it can be
set with `read_audiomoth(precision_m = 10)`.

## 7. Times

AudioMoth records in **UTC** unless another zone was set in its app; the zone
of each recording is read from its metadata. All local dates and times of
the CSV files are in `time_zone` (by default `Europe/Madrid`, with daylight
saving time; use `"Atlantic/Canary"` in the Canary Islands) and the column
`utc_offset` keeps the offset of each one; `recording_start_utc` keeps the
original UTC time.

## 8. Criteria

| Step | Criterion (default) | Argument |
|---|---|---|
| Analysis | Detections with confidence ≥ 0.10 are saved, only of the species expected at the site and week (BirdNET metadata model, threshold 0.03) | `analyze_birdnet(min_confidence, location_filter, location_threshold)` |
| Doubts | A detection has *no doubts* when BirdNET proposed no other species in the same 3 s window with confidence ≥ 0.1 | — |
| Examples | Confidence **≥ 0.85** and **no doubts**; the ones with the highest confidence, at most one per recording | `extract_examples(min_confidence, no_doubts, n)` |
| Validation | Records (species and day) with detections of confidence ≥ 0.5, from the least to the most plausible | `create_validation(min_confidence, min_detections)` |
| Observation.org | One record per species and day; detections with confidence ≥ 0.80 and at least 2 that day, plus the records validated by ear | `export_observation(min_confidence, min_detections, no_doubts_only)` |

BirdNET gives a **confidence score** (0-1), not a measured precision: a high
value does not guarantee that the identification is right.

## 9. Results

In the `output` folder (asked for when not given; better outside the card,
which is usually formatted for the next deployment, and **one per card**):

| File | Contents |
|---|---|
| `AudioMoth_<ID>_recordings.csv` | Inventory: file, day, UTC and local time, duration, sample rate, battery, temperature, problems and state of the analysis |
| `AudioMoth_<ID>_detections.csv` | All the detections: file, local date and time, start and end (s), species, confidence, `n_labels_window`, `other_confidence_max`, `no_doubts`, `location_prob`, coordinates |
| `AudioMoth_<ID>_observation.csv` / `.json` | Import file for Observation.org and the criteria used |
| `examples/<species>/*.wav, *.png, *.mp4` | Clip, spectrogram and video of each example |
| `examples/AudioMoth_<ID>_examples.csv` | Index of the examples (relative paths) |
| `validation/` | Validation page, clips and decisions (`AudioMoth_<ID>_validation.csv`) |
| `report/` | Quarto folder of the report (`report.qmd`, data and figures) and the PDF |
| `birdnet/<ID>_<key>/` | BirdNET results per recording, parameters, versions (`metadata.txt`), errors and probability of occurrence of the species; do not delete it |
| `audio_48k/` | 48 kHz mono copies (only when needed); they can be deleted once the analysis is finished |
| `.inventory_cache.rds` | Metadata of the WAV files already read, so that reading the card again is fast |

## 10. Observation.org

The CSV follows exactly the format of `observations-import-example.xlsx` (19
columns, UTF-8 without BOM, commas, dates `YYYY-MM-DD`, times `HH:MM`,
decimal coordinates with a point), with these values:

| Column | Value |
|---|---|
| `date` / `time` | Local date / time of the first detection of the day |
| `scientific name` | Name of the bird species in Observation.org. BirdNET v2.4 labels (eBird/Clements) are translated into the IOC World Bird List v15.2 and then into the species list of Observation.org, which follows IOC with its own lumps and genera (e.g. *Corvus cornix* → *Corvus corone*, *Saxicola stejnegeri* → *Saxicola maurus*; the BirdNET name is kept in `notes`). Every bird of BirdNET v2.4 has a valid name of Observation.org (see `inst/extdata/taxonomy/README.md`). Classes that are not birds are left out; species split by IOC are translated according to the location when the rule is clear (e.g. *Cecropis daurica* → *Cecropis rufula* in Europe) and reported otherwise. Own equivalences with `equivalences = c("BirdNET name" = "Observation.org name")` |
| `lat` / `lng` / `accuracy` | Location of the recorder and its precision (m, at most 1000) |
| `number` | 1 |
| `notes` | `"Identified with BirdNET <version>"` (`"ID mediante BirdNET <version>"` in Spanish), whether it was validated by ear, and the best detection (file, second and confidence) |
| `is certain` | `True` for the records validated by ear, `False` for the rest |
| `method` / `counting method` | `Oído` / `Sin especificar` (values of the Observation.org import example) |
| `external reference` | `AudioMoth_<ID>_<YYYYMMDD>_<species>`, unique and stable |

`method`, `counting_method` and `activity` are checked against the values
that Observation.org accepts for birds. If the CSV is edited by hand (e.g.
with a spreadsheet, keeping it comma separated), a new export does not
overwrite it.

## 11. Videos

`spectrogram_video()` draws the spectrogram once with R and ffmpeg animates it
(about 1 s per video): MP4 H.264 + AAC, 1280×720, valid for any player and
for social media.

- `style = "cursor"`: the whole spectrogram with a moving line.
- `style = "scroll"`: the spectrogram scrolls under a fixed line.

Dashed white lines mark the 3 s window of the detection. Other settings:
`fps`, `max_freq` (Hz, 12 000 by default), `db_range`, `width`, `height`,
`window_s`.

## 12. Approximate times

Measured on a 12-core laptop with 1-min recordings at 48 kHz:

| Step | Time |
|---|---|
| Inventory (`read_audiomoth`) | ~2 s for 1,700 recordings |
| BirdNET (`analyze_birdnet`) | ~1 s per 1-min recording (a card of 1,700 recordings: ~30 min) |
| Example (WAV + PNG + MP4) | ~1 s |
| Validation page | ~0.5 s per record |
| Observation.org | seconds |

Recordings at 250 kHz take longer (they are first converted to 48 kHz).

## 13. Troubleshooting

| Message / symptom | Solution |
|---|---|
| `Cannot find ffmpeg` | Install ffmpeg (see Requirements) or set its path: `options(AudiomothR.ffmpeg = "C:/ffmpeg/bin/ffmpeg.exe")` |
| `Cannot find Quarto` | Use RStudio or Positron (they include it), install it from <https://quarto.org> or set its path: `options(AudiomothR.quarto = "/path/to/quarto")` |
| `Cannot write in ...` | The card is write-protected: give another `output` folder |
| `The results folder ... already holds the results of another AudioMoth` | Use one `output` folder per card (and per deployment) |
| The map of the report has no background | Install `maptiles`, `sf` and `terra`, and check the Internet connection |
| `There is no CONFIG.TXT` | Choose the root folder of the card, not a daily folder (or give `coordinates` to read a copy without `CONFIG.TXT`) |
| The first run of BirdNET takes long | Normal: it installs Python and TensorFlow and downloads the model once (run `setup_birdnet()` beforehand) |
| `Cannot download the BirdNET v2.4 model` | Check the connection and run `setup_birdnet()` again, or download the zip shown in the message and unzip it into the model folder (see Installation) |
| `Give the results folder with output` | In scripts (`Rscript`) the results folder must be given: `output = "~/AudiomothR_results/card_01"` |
| Species from other continents | Check that `location_filter = TRUE` and that the coordinates are right (latitude first; west negative) |
| `0 of the 3 requested examples meet the criteria` | See `species_summary()` or lower `min_confidence` / use `no_doubts = FALSE` |
| A name "without a bird species in Observation.org" (only with own names) | Add `equivalences = c("BirdNET name" = "Observation.org name")` in `export_observation()` |
| Messages | `options(AudiomothR.quiet = TRUE)` hides the informative messages (warnings are always shown) |

## 14. Origin of the code, data and licences

- Reading of `CONFIG.TXT` and WAV files, and the first taxonomic
  equivalences, adapted from **Biosonora**. Export criteria and notes from the
  reports of the acoustic box (`Informes_Quarto_Caja_Acustica`).
- AudiomothR: GPL (≥ 3). birdnetR: MIT. **BirdNET models: CC BY-NC-SA 4.0
  (non-commercial use only).** IOC World Bird List: CC BY 3.0. See
  `inst/COPYRIGHTS` and `inst/extdata/taxonomy/README.md`; the taxonomy
  tables are rebuilt with `data-raw/build_taxonomy.R`.

## 15. Example data and vignette

The package includes an example AudioMoth card in
`inst/extdata/example/card/`
(`system.file("extdata", "example", "card", package = "AudiomothR")`): a
`CONFIG.TXT` file and two days of real recordings (16 WAV files),
**anonymised**: the device ID and the location are fictitious, and most WAV
files were cut to 0.05 s (10 of the 16 appear with `problem: "duration < 3
s"`, on purpose); 6 files keep ~7 s of real song.
`inst/extdata/example/birdnet_detections.csv` has the detections that BirdNET
v2.4 returned for this card.

See `vignette("audiomothr")` for a complete tour, step by step, with this
card, including the validation by ear.

> **Before uploading the CSV to Observation.org, check it.** BirdNET
> identifications are automatic and sometimes wrong: validate at least the
> unusual species or those with low confidence with `create_validation()`.

## 16. Tests

```r
devtools::test()   # more than 200 checks; conversion, video and report tests are
                   # skipped without ffmpeg, without Quarto or on CRAN
```

BirdNET is replaced by a mock in the tests, so they run without Python.

## 17. How to cite

If you use AudiomothR, cite the version you used (`citation("AudiomothR")`):

> Canepa-Oneto A, de la Fuente Gamero P, Barbero-Aparicio JA,
> Fernández-Ruiz C, Olivares A, Marticorena-Sánchez R (2026). *AudiomothR:
> Acoustic Processing of AudioMoth Recordings with BirdNET*. R package
> version 0.3.0. <https://doi.org/10.5281/zenodo.23646408>

Each version published on GitHub is archived in Zenodo with its own DOI; the
DOI above always resolves to the latest version.
