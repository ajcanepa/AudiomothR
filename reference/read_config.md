# Reads the CONFIG.TXT file of an AudioMoth

Format: one line per setting, `Key<spaces>: value`. Keys contain no ":"
but values do (times), so each line is split at the first one. A value
of "-" means "not applicable". Unknown keys are kept (other firmware
versions add fields).

## Usage

``` r
read_config(file)
```

## Arguments

- file:

  Path to the CONFIG.TXT file.

## Value

A list of class `audiomoth_config` with `settings` (all the key/value
pairs as text) and the interpreted fields: `device_id`, `firmware`,
`device_time_utc`, `sample_rate`, `gain`, `sleep_s`, `recording_s`,
`periods` (data frame), `sun_mode`, `trigger`, `first_date`,
`last_date`, `utc_offset_h` and `location` (list with `lat`, `lon` and
`precision_m`, or `NULL` when the file has no location).

## Examples

``` r
card <- system.file("extdata", "example", "card", package = "AudiomothR")
read_config(file.path(card, "CONFIG.TXT"))
#> 
#> ── AudioMoth FACADE0012345678 ──
#> 
#> • Firmware: AudioMoth-Firmware-Basic (1.12.1)
#> • Sample rate: 48,000 Hz, gain Medium
#> • Cycle: 60 s recording / 240 s sleeping
#> • Sun recording mode: Sunrise and sunset
#> • Dates: 2026-10-06 to 2026-10-30
#> • Location: 41, -3 (±698 m)
```
