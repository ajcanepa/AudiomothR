# Creates examples of the chosen species: audio, spectrogram and video

For each detection chosen with
[`select_examples()`](https://ajcanepa.github.io/AudiomothR/reference/select_examples.md),
cuts the exact sound of the detection (BirdNET window of 3 s) with a
margin of `margin_s` seconds before and after it, from the original
recording (at its original sample rate). Saves in
`<output>/examples/<species>/`:

- the clip as WAV,

- its spectrogram as PNG (see
  [`spectrogram_image()`](https://ajcanepa.github.io/AudiomothR/reference/spectrogram_image.md)),

- an MP4 video of the spectrogram with the audio (see
  [`spectrogram_video()`](https://ajcanepa.github.io/AudiomothR/reference/spectrogram_video.md)),

## Usage

``` r
extract_examples(
  am,
  species,
  n = 3,
  min_confidence = 0.85,
  no_doubts = TRUE,
  one_per_recording = TRUE,
  margin_s = 1,
  video = TRUE,
  style = c("cursor", "scroll"),
  fps = 25,
  window_s = 3,
  max_freq = 12000,
  db_range = 70,
  width = 1280,
  height = 720
)
```

## Arguments

- am:

  An `audiomoth` object with detections
  ([`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md));
  the examples are saved in its results folder. A list of them extracts
  the examples of each recorder.

- species:

  Names of the species: scientific or common names of BirdNET (case and
  accents do not matter) or IOC names. Also a named vector
  `c("Cettia cetti" = 3, ...)` with the number of examples of each
  species, as printed and returned by
  [`detected_species()`](https://ajcanepa.github.io/AudiomothR/reference/detected_species.md).

- n:

  Largest number of examples per species: one value for all of them or
  one per species. Not used when `species` already has the number of
  each one. Species with `n = 0` are skipped.

- min_confidence:

  Minimum confidence of the examples.

- no_doubts:

  Require that BirdNET proposed no other species in the same window.

- one_per_recording:

  At most one example from each recording.

- margin_s:

  Seconds of audio added before and after the detection.

- video:

  Create the MP4 video (needs ffmpeg).

- style:

  Style of the video: `"cursor"` (a line moves over the whole
  spectrogram) or `"scroll"` (the spectrogram scrolls under a fixed
  line).

- fps, window_s, max_freq, db_range, width, height:

  Settings of the spectrogram and the video (see
  [`spectrogram_video()`](https://ajcanepa.github.io/AudiomothR/reference/spectrogram_video.md)).

## Value

Invisibly, the index of the examples created in this call (data frame
with the paths of the files).

## Details

and keeps an index, `AudioMoth_<ID>_examples.csv`, in
`<output>/examples/`. Successive calls add their examples to the index
(an example extracted again replaces the previous one). The paths of the
index are relative to the `examples/` folder, so the results folder can
be moved.

## Examples

``` r
# \donttest{
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
#> • Results in: /tmp/RtmpoqZwSo/file22a76057792a
am$detections <- read_detections(system.file("extdata", "example",
  "birdnet_detections.csv", package = "AudiomothR"))
extract_examples(am, "Cettia cetti", n = 1, min_confidence = 0.5, video = FALSE)
#> ✔ 1 example of 1 species in /tmp/RtmpoqZwSo/file22a76057792a/examples.
# }
```
