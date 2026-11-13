# Video of the spectrogram of a WAV file, in sync with its audio

R draws the spectrogram once and ffmpeg animates it and adds the audio
(H.264 + AAC, playable in any player and on social media). Two styles:

- `"cursor"`: the whole spectrogram, with a line that moves at the pace
  of the sound.

- `"scroll"`: the spectrogram scrolls from right to left under a fixed
  line in the centre (`window_s` seconds are visible).

## Usage

``` r
spectrogram_video(
  wav,
  file,
  title = basename(wav),
  subtitle = "",
  marks = NULL,
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

- wav:

  Path of the WAV file (any sample rate; 8 to 32 bits).

- file:

  Output MP4 file.

- title, subtitle:

  Texts of the heading.

- marks:

  Start and end (s) of the detection, marked with dashed lines.

- style:

  `"cursor"` or `"scroll"`.

- fps:

  Frames per second.

- window_s:

  Seconds visible in the `"scroll"` style.

- max_freq:

  Highest frequency shown (Hz).

- db_range:

  Dynamic range (dB) of the colour scale.

- width, height:

  Size in pixels.

## Value

Invisibly, the path of the MP4 file.

## Examples

``` r
wav <- tempfile(fileext = ".wav")
t <- seq(0, 2, length.out = 2 * 48000)
tuneR::writeWave(tuneR::Wave(round(8000 * sin(2 * pi * (2000 + 1000 * t) * t)),
                             samp.rate = 48000, bit = 16), wav)
spectrogram_video(wav, tempfile(fileext = ".mp4"), title = "Chirp")
#> ✔ Video in /tmp/RtmpoqZwSo/file22a715e88d53.mp4.
```
