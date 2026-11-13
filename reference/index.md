# Package index

## Before you start

- [`check_requirements()`](https://ajcanepa.github.io/AudiomothR/reference/check_requirements.md)
  : Checks what AudiomothR needs and what is installed
- [`setup_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/setup_birdnet.md)
  : Installs and checks BirdNET

## Everything in one call

- [`process_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/process_audiomoth.md)
  : Processes an AudioMoth card from start to end

## Step 1: Reading the card

- [`read_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/read_audiomoth.md)
  : Reads an AudioMoth card: configuration, location and inventory
- [`read_config()`](https://ajcanepa.github.io/AudiomothR/reference/read_config.md)
  : Reads the CONFIG.TXT file of an AudioMoth
- [`parse_coordinates()`](https://ajcanepa.github.io/AudiomothR/reference/parse_coordinates.md)
  : Reads coordinates in any of the usual formats
- [`choose_folder()`](https://ajcanepa.github.io/AudiomothR/reference/choose_folder.md)
  : Chooses the folder of an AudioMoth card with a dialog
- [`choose_output()`](https://ajcanepa.github.io/AudiomothR/reference/choose_output.md)
  : Asks for the results folder

## Steps 2-3: Preparing the audio and analysing with BirdNET

- [`prepare_audio()`](https://ajcanepa.github.io/AudiomothR/reference/prepare_audio.md)
  : Prepares the audio for BirdNET
- [`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
  : Analyses the recordings with BirdNET
- [`read_detections()`](https://ajcanepa.github.io/AudiomothR/reference/read_detections.md)
  : Reads the detections of an AudioMoth

## Which species BirdNET looks for

- [`read_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/read_species_list.md)
  : Reads a list of species for BirdNET
- [`gbif_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/gbif_species_list.md)
  : Builds a list of species from GBIF around a site

## Step 4: Summary by species

- [`species_summary()`](https://ajcanepa.github.io/AudiomothR/reference/species_summary.md)
  : Summary of the detections by species
- [`detected_species()`](https://ajcanepa.github.io/AudiomothR/reference/detected_species.md)
  : Detected species, ready to choose examples

## Step 5: Examples, spectrograms and videos

- [`select_examples()`](https://ajcanepa.github.io/AudiomothR/reference/select_examples.md)
  : Chooses the best detections of each species
- [`extract_examples()`](https://ajcanepa.github.io/AudiomothR/reference/extract_examples.md)
  : Creates examples of the chosen species: audio, spectrogram and video
- [`spectrogram_image()`](https://ajcanepa.github.io/AudiomothR/reference/spectrogram_image.md)
  : Saves the spectrogram of a WAV file as a PNG image
- [`spectrogram_video()`](https://ajcanepa.github.io/AudiomothR/reference/spectrogram_video.md)
  : Video of the spectrogram of a WAV file, in sync with its audio

## Step 6: Validating the records by ear

- [`create_validation()`](https://ajcanepa.github.io/AudiomothR/reference/create_validation.md)
  : Creates a page to validate the records by ear
- [`read_validation()`](https://ajcanepa.github.io/AudiomothR/reference/read_validation.md)
  : Reads the decisions of the validation by ear

## Steps 7-8: Observation.org and the PDF report

- [`export_observation()`](https://ajcanepa.github.io/AudiomothR/reference/export_observation.md)
  : Exports the detections in the format of Observation.org
- [`create_report()`](https://ajcanepa.github.io/AudiomothR/reference/create_report.md)
  : Creates a PDF report of one or several AudioMoth recorders

## The package

- [`AudiomothR`](https://ajcanepa.github.io/AudiomothR/reference/AudiomothR-package.md)
  [`AudiomothR-package`](https://ajcanepa.github.io/AudiomothR/reference/AudiomothR-package.md)
  : AudiomothR: Acoustic Processing of 'AudioMoth' Recordings with
  'BirdNET'
