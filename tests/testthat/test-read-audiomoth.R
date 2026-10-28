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
  dup <- am$recordings[grepl("^duplicate", am$recordings$problem), ]
  expect_equal(dup$file, sprintf("%s_20261010_060000 2.WAV", device))
  expect_equal(dup$problem, sprintf("duplicate of %s_20261010_060000.WAV", device))
  expect_equal(sum(am$recordings$valid), 4)   # the same as without the copy
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

test_that("a recording with a deployment ID keeps the device of CONFIG.TXT", {
  # (Case contributed by José Antonio Barbero-Aparicio, pull request #1)
  dir <- make_card()
  write_wav(file.path(dir, "20261010", "0123456789ABCDEF_20261010_070000.WAV"), duration = 5,
            comment = "Recorded at 07:00:00 10/10/2026 (UTC) during deployment 0123456789ABCDEF at medium gain while battery was 4.7V and temperature was 6.7C.")
  g <- read_card(dir)$recordings
  x <- g[g$file == "0123456789ABCDEF_20261010_070000.WAV", ]
  expect_equal(x$device_id, device)
  expect_equal(x$deployment_id, "0123456789ABCDEF")
  expect_equal(c(x$battery_v, x$temperature_c), c(4.7, 6.7))
  expect_equal(x$start_utc, "2026-10-10 07:00:00")
})

test_that("a box gathers its cards, each with its own location", {
  # Two cards of the same box, the second one at another site
  card1 <- make_card()
  card2 <- tempfile("card_")
  dir.create(card2)
  file.copy(file.path(card1, "CONFIG.TXT"), card2)
  for (day in c("20261020", "20261021")) {
    start <- as.POSIXct(paste(day, "060000"), format = "%Y%m%d %H%M%S", tz = "UTC")
    write_wav(file.path(card2, day, sprintf("%s_%s_060000.WAV", device, day)), comment = am_comment(start))
  }
  box <- tempfile("box_")
  am1 <- read_card(card1, output = box, site = "River")
  expect_warning(am2 <- read_card(card2, coordinates = "41.30, -3.40", output = box, site = "Forest"), "km away")
  expect_equal(nrow(am2$recordings), 7)
  expect_equal(am2$deployments$site, c("River", "Forest"))
  expect_equal(unique(am2$recordings$lat), c(41, 41.3))
  # Reading the first card again keeps its location and does not duplicate anything
  am3 <- read_card(card1, coordinates = NULL, output = box)
  expect_equal(nrow(am3$recordings), 7)
  expect_equal(am3$location$lat, 41)
  expect_equal(am3$site, "River")
  expect_equal(nrow(am3$deployments), 2)
  # Another box cannot share the folder
  writeLines("x", file.path(box, "AudioMoth_0123456789ABCDEF_recordings.csv"))
  expect_error(read_card(make_card(), output = box), "another AudioMoth")
})

test_that("BirdNET and Observation.org use the location of each deployment", {
  card1 <- make_card()
  card2 <- tempfile("card_")
  dir.create(card2)
  file.copy(file.path(card1, "CONFIG.TXT"), card2)
  start <- as.POSIXct("2026-10-20 06:00:00", tz = "UTC")
  write_wav(file.path(card2, "20261020", sprintf("%s_20261020_060000.WAV", device)), comment = am_comment(start))
  box <- tempfile("box_")
  calls <- new.env()
  am <- read_card(card1, output = box)
  with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us")), calls = calls)
  expect_equal(calls$n, 4)
  am <- suppressWarnings(read_card(card2, coordinates = "41.30, -3.40", output = box))
  extra <- data.frame(file = "20261020_060000", start = 0, end = 3, scientific_name = "Cettia cetti", confidence = 0.95)
  helper <- environment(with_mock_birdnet)
  old <- get("mock_predictions", helper)
  assign("mock_predictions", rbind(old, extra), envir = helper)
  on.exit(assign("mock_predictions", old, envir = helper))
  am <- with_mock_birdnet(suppressWarnings(suppressMessages(analyze_birdnet(am, language = "en_us"))), calls = calls)
  expect_equal(calls$n, 1)   # only the new card
  d <- am$detections
  expect_equal(sort(unique(d$lat)), c(41, 41.3))
  obs <- suppressWarnings(suppressMessages(export_observation(am, min_confidence = 0.5, min_detections = 1,
                                                              file = tempfile(fileext = ".csv"))))
  expect_equal(obs$lat[obs$date == "2026-10-20"], 41.3)
  expect_equal(unique(obs$lat[obs$date == "2026-10-10"]), 41)
  # A card that is no longer connected keeps its results
  unlink(card1, recursive = TRUE)
  am <- with_mock_birdnet(suppressWarnings(suppressMessages(analyze_birdnet(am, language = "en_us"))), calls = calls)
  expect_equal(calls$n, 0)
  expect_true(any(am$detections$lat == 41))
})
