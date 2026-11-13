# Analyses the recordings with BirdNET

Uses the BirdNET v2.4 model through the birdnetR package.

## Usage

``` r
analyze_birdnet(
  am,
  min_confidence = 0.1,
  language = default_language(),
  version = "v2.4",
  location_filter = TRUE,
  location_threshold = 0.03,
  species_list = NULL,
  overlap = 0,
  sensitivity = 1,
  threads = NULL,
  reanalyze = FALSE,
  stop_on_error = FALSE
)
```

## Arguments

- am:

  Object created with
  [`read_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/read_audiomoth.md).

- min_confidence:

  Minimum confidence (0-1) of the detections that are kept. Values below
  0.1 make the cache keep more detections (a new analysis).

- language:

  Language of the common names. By default, the language of the
  operating system (see
  [`check_requirements()`](https://ajcanepa.github.io/AudiomothR/reference/check_requirements.md));
  codes such as `"es"`, `"en_us"`, `"en_uk"`, `"fr"`, `"de"`, `"pt"`...
  Polish (`"pl"`) is not accepted: its label file in BirdNET v2.4 is
  wrong.

- version:

  Version of the BirdNET model (see
  [`birdnetR::birdnet_model_tflite()`](https://birdnet-team.github.io/birdnetR/reference/birdnet_model_load.html)).
  It is stored in the column `model` and quoted by
  [`export_observation()`](https://ajcanepa.github.io/AudiomothR/reference/export_observation.md)
  in the notes.

- location_filter:

  Filter the species by location and week (see "Which species BirdNET
  looks for"). Not applied when `species_list` is given.

- location_threshold:

  Minimum probability of occurrence (metadata model, 0 to 1) for a
  species to pass the location filter.

- species_list:

  Own list of the species to look for, instead of the location filter: a
  vector of scientific names, the path of a `.txt` file (e.g. the
  species list of BirdNET-Analyzer) or of a `.csv` file, or a data frame
  such as the result of
  [`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md).
  See
  [`read_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/read_species_list.md).
  `NULL` (default): no list.

- overlap:

  Overlap between 3 s windows (seconds, 0 to 2.9).

- sensitivity:

  BirdNET sensitivity (0.5 to 1.5).

- threads:

  Computing threads (by default, all but one).

- reanalyze:

  Analyse every recording again with these parameters.

- stop_on_error:

  Stop with an error when BirdNET cannot analyse some recording (useful
  in scripts run with `Rscript`); by default it only warns, and the
  recordings are listed in the column `analysis`.

## Value

`am` with `am$detections` (data frame).

## Details

**Which species BirdNET looks for.** BirdNET v2.4 knows about 6,500
classes, most of them birds from all over the world. Without a filter it
often proposes species from other continents, so by default only the
species expected at the site are considered:

- **Location filter** (default, `location_filter = TRUE`): the metadata
  (geographic) model of BirdNET, trained with the eBird checklists,
  gives for each species a probability of occurrence at the location of
  the deployment and in the week of the year of each recording (48
  weeks, four per month). Only the species with a probability of at
  least `location_threshold` (0.03, the value of BirdNET) are analysed;
  the others are never proposed. It works well for common species, but
  in little visited areas, or for species that are seldom reported to
  eBird (nocturnal, secretive or scarce species: owls, Stone-curlew,
  sandgrouse...), the probability may be underestimated and the species
  left out. In such cases lower `location_threshold` (e.g. 0.01), use a
  `species_list` or turn the filter off.

- **Own list** (`species_list`): only the species of the list are
  analysed, wherever the recorder is (the location filter is then not
  applied). It may be a vector of scientific names, a file such as the
  species list of BirdNET-Analyzer or a CSV file, or a table built from
  the observations around the site with
  [`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md);
  see
  [`read_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/read_species_list.md)
  for the accepted formats.

- **No filter** (`location_filter = FALSE`): all the classes of BirdNET.
  Rare species are not lost, but there are more mistakes with species
  from elsewhere: check the records by ear
  ([`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md)).

In every case the probability of occurrence of the metadata model is
kept in the column `location_prob` of the detections, and the validation
page shows first the least plausible records (low confidence and low
`location_prob`).

**Cache.** Recordings already analysed with the same parameters are not
analysed again: an interrupted analysis continues where it stopped. The
cache is in `<output>/birdnet/`, in one folder per combination of
parameters, so going back to earlier parameters reuses their results.
Changing `min_confidence` (above 0.1) or `language` does not require a
new analysis.

**Doubts.** BirdNET analyses the audio in 3 s windows. A detection has
"no doubts" (`no_doubts = TRUE`) when BirdNET proposed no other species
in the same window with a confidence of at least 0.1 (only species that
pass the location filter, or that are in the `species_list`, count;
classes such as "Engine" or "Human vocal" do not).

**Overlap.** With `overlap > 0` consecutive windows overlap and the same
song is detected in several of them. The column `event` groups the
overlapping windows of the same species, and the counts of
[`species_summary()`](https://ajcanepa.github.io/AudiomothR/reference/species_summary.md)
and
[`export_observation()`](https://ajcanepa.github.io/AudiomothR/reference/export_observation.md)
use events, not windows.

At the end, `AudioMoth_<ID>_detections.csv` is saved (see
[`read_detections()`](https://ajcanepa.github.io/AudiomothR/reference/read_detections.md))
and `am$recordings` gains the column `analysis` ("ok", "error: ..." or
`NA` for recordings that are not valid).

## Examples

``` r
if (FALSE) { # \dontrun{
# Not run: the first time it installs Python, TensorFlow and the BirdNET
# model (about 3 GB, a few minutes)
card <- system.file("extdata", "example", "card", package = "AudiomothR")
am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
am <- analyze_birdnet(am)

# Only the species of an own list (e.g. that of BirdNET-Analyzer)
am <- analyze_birdnet(am, species_list = "~/species_list.txt")

# The species observed within 30 km in GBIF (eBird, Observation.org, iNaturalist)
am <- analyze_birdnet(am, species_list = gbif_species_list(am, radius_km = 30))
} # }
```
