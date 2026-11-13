# Prepares the audio for BirdNET

BirdNET works with mono audio at 48 kHz. Recordings that already are so
are used as they are; the others (e.g. AudioMoth at 250 kHz or stereo)
are converted with ffmpeg into `<output>/audio_48k/`. Triggered
recordings (`*T.WAV`) are expanded first, restoring their silences, so
that the times of the detections are right. Recordings that are not
valid (column `problem`) are left out.

## Usage

``` r
prepare_audio(am)
```

## Arguments

- am:

  Object created with
  [`read_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/read_audiomoth.md).

## Value

`am` with the column `birdnet_path` (audio read by BirdNET) in
`am$recordings`.

## Details

This step is optional:
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
converts by itself, just before analysing them, the recordings that
still need it (and only those without a result yet, so the converted
copies can be deleted once the analysis is finished).

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
#> • Results in: /tmp/RtmpXUCCMs/file23374b57c821
am <- prepare_audio(am)   # 48 kHz mono already: nothing to convert
#> ✔ All valid recordings are already 48 kHz mono: nothing to convert.
#> ! 10 recordings with problems are left out (see column problem).
```
