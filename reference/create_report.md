# Creates a PDF report of one or several AudioMoth recorders

Prepares a Quarto folder with everything it needs (`report.qmd`,
`_section.qmd`, `report_functions.R`, `report_data.rds` and the
spectrograms of the examples) and renders it as a PDF with Quarto and
Typst (LaTeX is not needed).

## Usage

``` r
create_report(
  recorders,
  by_recorder = TRUE,
  output = NULL,
  title = "Acoustic monitoring report",
  min_confidence = 0.5,
  map = TRUE,
  open = interactive(),
  overwrite_template = FALSE
)
```

## Arguments

- recorders:

  An `audiomoth` object analysed with
  [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
  or a list of them (several recorders).

- by_recorder:

  With several recorders, `TRUE` gives each recorder its own section and
  `FALSE` combines them into a single analysis.

- output:

  Folder of the report. By default, `report/` inside the results folder
  of the recorder; with several recorders it must be given.

- title:

  Title of the report.

- min_confidence:

  Only the detections with at least this confidence are summarised.

- map:

  Include the map of the recorders.

- open:

  Open the PDF at the end.

- overwrite_template:

  Copy the template files again, replacing the edited ones.

## Value

Invisibly, the path of the PDF file.

## Details

The report includes:

- a summary of the sampling and the results;

- a map of the recorders (on OpenStreetMap when `maptiles`, `sf` and
  `terra` are installed and there is an Internet connection; otherwise
  without background) and a table with their configuration;

- the state of the recordings: recordings per day, problems, recordings
  that BirdNET could not analyse, battery and temperature;

- the detected species, with their confidence and their activity by day
  and by hour and, with several recorders, which recorder detected each;

- the spectrograms of the examples created with
  [`extract_examples()`](https://ajcanepa.github.io/AudiomothR/reference/extract_examples.md);

- the records exported with
  [`export_observation()`](https://ajcanepa.github.io/AudiomothR/reference/export_observation.md)
  and the result of the validation by ear
  ([`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md));

- the parameters of the analysis and the versions of the software.

The template files are copied only the first time: later calls keep the
edits made to them (unless `overwrite_template = TRUE`) and only update
the data.

## Examples

``` r
if (FALSE) { # interactive()
# Needs Quarto (included in RStudio and Positron): see check_requirements()
card <- system.file("extdata", "example", "card", package = "AudiomothR")
am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
am$detections <- read_detections(system.file("extdata", "example",
  "birdnet_detections.csv", package = "AudiomothR"))
pdf <- create_report(am)                                  # one recorder

# Several recorders together:
# create_report(list(am1, am2, am3), by_recorder = FALSE, output = "report_river")
}
```
