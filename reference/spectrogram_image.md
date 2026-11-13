# Saves the spectrogram of a WAV file as a PNG image

Saves the spectrogram of a WAV file as a PNG image

## Usage

``` r
spectrogram_image(
  wav,
  file,
  title = basename(wav),
  subtitle = "",
  marks = NULL,
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

  Output PNG file.

- title, subtitle:

  Texts of the heading.

- marks:

  Start and end (s) of the detection, marked with dashed lines.

- max_freq:

  Highest frequency shown (Hz).

- db_range:

  Dynamic range (dB) of the colour scale.

- width, height:

  Size in pixels.

## Value

Invisibly, the path of the PNG file.

## Examples

``` r
wav <- tempfile(fileext = ".wav")
t <- seq(0, 2, length.out = 2 * 48000)
tuneR::writeWave(tuneR::Wave(round(8000 * sin(2 * pi * (2000 + 1000 * t) * t)),
                             samp.rate = 48000, bit = 16), wav)
spectrogram_image(wav, tempfile(fileext = ".png"), title = "Chirp")
#> ✔ Spectrogram in /tmp/RtmpoqZwSo/file22a7495746b6.png.
```
