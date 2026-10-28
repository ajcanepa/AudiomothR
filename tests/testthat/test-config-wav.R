test_that("reads CONFIG.TXT with location and sun mode", {
  dir <- make_card(location = TRUE)
  cfg <- read_config(file.path(dir, "CONFIG.TXT"))
  expect_s3_class(cfg, "audiomoth_config")
  expect_equal(cfg$device_id, device)
  expect_equal(cfg$sample_rate, 48000L)
  expect_equal(cfg$gain, "Medium")
  expect_equal(cfg$recording_s, 60)
  expect_equal(cfg$sun_mode, "Sunrise and sunset")
  expect_equal(cfg$utc_offset_h, 0)
  expect_equal(c(cfg$location$lat, cfg$location$lon), c(41, -3))
  expect_true(is.na(cfg$settings$Filter))
  expect_equal(format(cfg$device_time_utc, tz = "UTC"), "2026-10-05 19:46:26")
  expect_message(print(cfg), "AudioMoth")
})

test_that("reads CONFIG.TXT of old firmware, with periods and in Latin-1", {
  dir <- tempfile()
  dir.create(dir)
  lines <- config_txt(location = FALSE, device_time = FALSE)
  writeLines(lines, file.path(dir, "CONFIG.TXT"))
  cfg <- read_config(file.path(dir, "CONFIG.TXT"))
  expect_null(cfg$location)
  expect_equal(cfg$periods$start, "16:00")
  expect_equal(cfg$utc_offset_h, 2) # "Time zone : UTC+2"

  latin1 <- iconv(config_txt(), "UTF-8", "latin1")
  writeLines(latin1, file.path(dir, "CONFIG.TXT"), useBytes = TRUE)
  expect_equal(read_config(file.path(dir, "CONFIG.TXT"))$location$lat, 41)
})

test_that("parses the comment of AudioMoth (vectorised)", {
  com <- AudiomothR:::parse_audiomoth_comment(c(
    "Recorded at 04:20:00 10/10/2026 (UTC) by AudioMoth FACADE0012345678 at medium gain while battery was 4.7V and temperature was 6.7C.",
    "Recorded at 06:20:00 10/10/2026 (UTC+2) during deployment 0123456789ABCDEF at high gain while battery was less than 3.6V and temperature was -1.5C. Amplitude threshold was 1000.",
    "Recorded at 06:20:00 10/10/2026 (UTC) by AudioMoth FACADE0012345678 at low gain while battery state was 4.5V.",
    NA))
  expect_equal(format(com$start_utc, tz = "UTC"), c("2026-10-10 04:20:00", "2026-10-10 04:20:00", "2026-10-10 06:20:00", NA))
  expect_equal(com$device_id, c(device, NA, device, NA))
  expect_equal(com$deployment_id, c(NA, "0123456789ABCDEF", NA, NA))
  expect_equal(com$battery_v, c(4.7, 3.6, 4.5, NA))
  expect_equal(com$battery_limit, c(NA, "<", NA, NA))
  expect_equal(com$temperature_c, c(6.7, -1.5, NA, NA))
  expect_equal(com$threshold, c(FALSE, TRUE, FALSE, FALSE))
})

test_that("parses file names, including triggered recordings and copies", {
  n <- AudiomothR:::parse_audiomoth_name(c("FACADE0012345678_20261010_042000.WAV", "20261010_042000T.WAV",
                                           "20261010_042000 2.wav", "other.wav"))
  expect_equal(n$prefix_id, c(device, NA, NA, NA))
  expect_equal(n$date_text, c("20261010_042000", "20261010_042000", "20261010_042000", NA))
  expect_equal(n$triggered, c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(n$suffix, c("", "", " 2", NA))
})

test_that("reads the INFO comment, GUANO and an unfinished header", {
  f <- tempfile(fileext = ".WAV")
  write_wav(f, duration = 4, comment = "Recorded at 04:20:00 10/10/2026 (UTC)",
            guano = "GUANO|Version:1.0\nTimestamp:2026-10-10T04:20:00Z\nOAD|Battery Voltage:5.0\nTemperature Int:13.6\n")
  h <- AudiomothR:::read_wav_header(f)
  expect_equal(h$duration_s, 4, tolerance = 1e-3)
  expect_equal(h$info$ICMT, "Recorded at 04:20:00 10/10/2026 (UTC)")
  expect_equal(h$guano[["Battery Voltage"]], "5.0")
  expect_equal(h$guano[["Temperature Int"]], "13.6")

  g <- tempfile(fileext = ".WAV")
  write_wav(g, duration = 4, data_size = 0)
  h <- AudiomothR:::read_wav_header(g)
  expect_true(h$incomplete_header)
  expect_equal(h$duration_s, 4, tolerance = 1e-3)
})

test_that("expands triggered recordings (T.WAV)", {
  rate <- 48000
  block <- function(k) c(ifelse(bitwAnd(k, as.integer(2^(0:30))) > 0, 1, -1), -1, rep(0, 224))
  tone <- round(3000 * sin(2 * pi * 2000 * seq_len(256 * 100) / rate))
  f <- tempfile(fileext = "T.WAV")
  write_wav(f, rate = rate, samples = c(tone, block(500), tone))
  h <- AudiomothR:::read_wav_header(f)
  expect_equal(AudiomothR:::triggered_duration(f, h), (100 + 500 + 100) * 256 / rate)
  out <- tempfile(fileext = ".wav")
  AudiomothR:::expand_triggered_wav(f, out)
  expect_equal(AudiomothR:::read_wav_header(out)$duration_s, (100 + 500 + 100) * 256 / rate)
})

test_that("BirdNET weeks follow the eBird convention", {
  week <- AudiomothR:::birdnet_week
  expect_equal(week(c("2026-01-01", "2026-01-07", "2026-01-08", "2026-01-15", "2026-01-22", "2026-01-31")),
               c(1, 1, 2, 3, 4, 4))
  expect_equal(week(c("2026-12-31", "2028-02-29", "2026-10-07", "2026-10-15")), c(48, 8, 37, 39))
})

test_that("chooses the language of the common names from the locale", {
  lang <- function(...) withr_env(c(LANGUAGE = "", LC_ALL = "", LC_MESSAGES = "", ...), AudiomothR:::default_language())
  withr_env <- function(vars, code) {
    old <- Sys.getenv(names(vars), unset = NA)
    on.exit(for (k in names(old)) if (is.na(old[[k]])) Sys.unsetenv(k) else do.call(Sys.setenv, as.list(old[k])))
    do.call(Sys.setenv, as.list(vars))
    code
  }
  expect_equal(lang(LANG = "es_ES.UTF-8"), "es")
  expect_equal(lang(LANG = "en_GB.UTF-8"), "en_uk")
  expect_equal(lang(LANG = "en_US.UTF-8"), "en_us")
  expect_equal(lang(LANG = "pt_BR.UTF-8"), "pt")
  expect_true(lang(LANG = "pl_PL.UTF-8") != "pl")
})
