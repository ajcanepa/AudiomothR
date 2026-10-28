test_that("takes the inventory and converts UTC into local time", {
  dir <- make_card()
  am <- read_card(dir, site = "Test")
  g <- am$recordings
  expect_equal(nrow(g), 5)
  expect_equal(sum(g$valid), 4)
  expect_equal(g$problem[!g$valid], "unreadable or empty WAV")
  expect_equal(g$start_utc[1], "2026-10-10 06:00:00")
  expect_equal(g$start_local[1], "2026-10-10 08:00:00") # CEST = UTC+2
  expect_equal(g$utc_offset[1], "+0200")
  expect_equal(g$start_source[1], "comment")
  expect_equal(g$battery_v[1], 4.7)
  expect_equal(g$duration_s[1], 8)
  expect_equal(am$location$source, "argument")
  expect_equal(am$site, "Test")
  expect_true(file.exists(file.path(dir, "results", sprintf("AudioMoth_%s_recordings.csv", device))))
  expect_message(print(am), "openstreetmap")
})

test_that("reads time, battery and temperature of the example card (ICMT)", {
  am <- suppressMessages(read_audiomoth(example_card(), coordinates = "41.00, -3.00", output = tempfile()))
  g <- am$recordings[am$recordings$file == "FACADE0012345678_20261007_064000.WAV", ]
  expect_equal(g$start_utc, "2026-10-07 06:40:09")
  expect_equal(g$battery_v, 4.9)
  expect_equal(g$temperature_c, 13.6)
  expect_equal(sum(am$recordings$valid), 6)
  expect_equal(unique(am$recordings$problem[!am$recordings$valid]), "duration < 3 s")
})

test_that("uses the location of CONFIG.TXT and checks the one given", {
  am <- suppressMessages(read_audiomoth(make_card(location = TRUE), output = tempfile()))
  expect_equal(am$location$source, "CONFIG.TXT")
  expect_error(read_card(make_card(location = FALSE), coordinates = NULL), "coordinates")
  expect_error(read_card(coordinates = "-3.00, 41.00"), "swapped")
  expect_warning(read_card(coordinates = "42.00, -3.00"), "km away")
})

test_that("the start time falls back on the file name", {
  dir <- make_card(comments = FALSE)
  expect_warning(am <- read_card(dir), "file name")
  expect_equal(am$recordings$start_utc[1], "2026-10-10 06:00:00")
  expect_equal(am$recordings$start_source[1], "file name")
})

test_that("finds duplicated recordings and ignores other folders with a warning", {
  dir <- make_card()
  day <- file.path(dir, "20261010")
  file.copy(file.path(day, sprintf("%s_20261010_060000.WAV", device)),
            file.path(day, sprintf("%s_20261010_060000 2.WAV", device)))
  dir.create(file.path(dir, "other"))
  file.copy(file.path(day, sprintf("%s_20261010_060500.WAV", device)), file.path(dir, "other"))
  expect_warning(expect_warning(am <- read_card(dir), "duplicated"), "outside the root")
  dup <- am$recordings[am$recordings$problem %in% "duplicate", ]
  expect_equal(dup$file, sprintf("%s_20261010_060000 2.WAV", device))
})

test_that("reads a copy of the recordings without CONFIG.TXT", {
  dir <- make_card()
  unlink(file.path(dir, "CONFIG.TXT"))
  expect_warning(am <- read_card(dir), "CONFIG.TXT")
  expect_equal(am$config$device_id, device)
  expect_equal(am$recordings$start_utc[1], "2026-10-10 06:00:00")
})

test_that("checks the arguments and the results folder", {
  dir <- make_card()
  expect_error(read_card(dir, precision_m = "10 m"), "precision_m")
  expect_error(read_card(dir, precision_m = -5), "precision_m")
  expect_equal(read_card(dir, precision_m = 9.2)$location$precision_m, 10L)
  expect_error(read_card(dir, time_zone = "CEST"), "Unknown time zone")
  expect_equal(suppressMessages(read_card(dir, time_zone = "UTC+2"))$time_zone, "Etc/GMT-2")
  expect_warning(read_card(make_card(location = FALSE), coordinates = "28.10, -15.40"), "Canary")

  # A results folder belongs to a single card
  other <- make_card()
  writeLines("x", file.path(dir, "results", "AudioMoth_0123456789ABCDEF_recordings.csv"))
  expect_error(read_card(other, output = file.path(dir, "results")), "another AudioMoth")
})

test_that("keeps the metadata of the recordings in a cache", {
  dir <- make_card()
  am <- read_card(dir)
  cache <- file.path(dir, "results", ".inventory_cache.rds")
  expect_true(file.exists(cache))
  expect_equal(nrow(readRDS(cache)), 5)
  # A file that changes is read again; the rest come from the cache
  f <- file.path(dir, "20261010", sprintf("%s_20261010_060000.WAV", device))
  write_wav(f, duration = 5, comment = am_comment(as.POSIXct("2026-10-10 06:00:00", tz = "UTC")))
  Sys.setFileTime(f, Sys.time() + 60)
  am2 <- read_card(dir)
  expect_equal(am2$recordings$duration_s[am2$recordings$file == basename(f)], 5)
  expect_equal(am2$recordings[-1, c("file", "start_utc", "battery_v")], am$recordings[-1, c("file", "start_utc", "battery_v")],
               ignore_attr = TRUE)
})

test_that("asks for the results folder, which is required in scripts", {
  dir <- make_card()
  expect_error(suppressMessages(read_audiomoth(dir, coordinates = "41.00, -3.00")), "results folder")
  expect_error(choose_output(), "interactive")
})
