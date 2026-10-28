test_that("joins the results and marks the windows with doubts", {
  am <- analysed_card()
  d <- am$detections
  expect_equal(nrow(d), 7)
  first <- d[d$file == am$recordings$file[1] & d$start_s == 0, ]
  expect_equal(first$n_labels_window, c(2L, 2L))
  expect_equal(first$other_confidence_max[first$scientific_name == "Cettia cetti"], 0.30)
  expect_false(any(first$no_doubts))
  expect_equal(d$local_time[d$file == am$recordings$file[1] & d$start_s == 3], "08:00:03")
  expect_equal(d$common_name[d$scientific_name == "Cettia cetti"][1], "Cetti's Warbler")
  expect_equal(unique(d$location_prob[d$scientific_name == "Cettia cetti"]), 0.5)
  # Classes that are not species neither count as species nor cause doubts
  hv <- d[d$scientific_name == "Human vocal", ]
  expect_false(hv$is_species)
  expect_true(d$no_doubts[d$file == hv$file & d$start_s == 0 & d$scientific_name == "Cettia cetti"])
  expect_equal(am$recordings$analysis[am$recordings$valid], rep("ok", 4))
  expect_true(file.exists(file.path(am$output, sprintf("AudioMoth_%s_detections.csv", device))))
})

test_that("does not analyse twice and keeps the cache of other parameters", {
  am <- read_card()
  calls <- new.env()
  with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us")), calls = calls)
  expect_equal(calls$n, 4)
  with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us")), calls = calls)
  expect_equal(calls$n, 0)
  # Another language or a higher confidence do not need a new analysis
  with_mock_birdnet(am2 <- suppressMessages(analyze_birdnet(am, language = "en_us", min_confidence = 0.5)), calls = calls)
  expect_equal(calls$n, 0)
  expect_true(all(am2$detections$confidence >= 0.5))
  # A doubt does not disappear when the minimum confidence goes up
  expect_false(am2$detections$no_doubts[am2$detections$start_s == 0 & am2$detections$scientific_name == "Cettia cetti"][1])
  # New parameters: a new cache, the previous one is kept
  with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us", sensitivity = 1.2)), calls = calls)
  expect_equal(calls$n, 4)
  expect_length(list.dirs(file.path(am$output, "birdnet"), recursive = FALSE), 2)
})

test_that("invalid arguments fail before anything is changed", {
  am <- analysed_card()
  before <- list.files(am$output, recursive = TRUE)
  expect_error(analyze_birdnet(am, sensitivity = 3), "sensitivity")
  expect_error(analyze_birdnet(am, min_confidence = 50), "did you mean")
  expect_error(analyze_birdnet(am, language = "pl"), "Polish")
  expect_error(analyze_birdnet(am, language = "xx"), "Unknown")
  expect_equal(list.files(am$output, recursive = TRUE), before)
})

test_that("an incomplete cached result is analysed again", {
  am <- read_card()
  calls <- new.env()
  am <- with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us")), calls = calls)
  cached <- list.files(file.path(am$output, "birdnet"), pattern = "060000\\.csv$", recursive = TRUE, full.names = TRUE)[1]
  writeLines("", cached)
  expect_warning(with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us")), calls = calls), "incomplete")
  expect_equal(calls$n, 1)
})

test_that("recordings that BirdNET cannot analyse are recorded", {
  am <- read_card()
  expect_warning(am2 <- with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us")), fail = "20261011_060500"),
                 "could not analyse 1 recording")
  expect_match(am2$recordings$analysis[am2$recordings$file == sprintf("%s_20261011_060500.WAV", device)], "^error")
  expect_error(with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us", stop_on_error = TRUE)),
                                 fail = "20261011_060500"), "could not analyse")
  # When everything fails, the previous results are not overwritten
  am3 <- read_card()
  expect_error(with_mock_birdnet(suppressMessages(analyze_birdnet(am3, language = "en_us")), fail = "WAV"),
               "could not analyse any recording")
})

test_that("an empty location filter is an error", {
  am <- read_card()
  expect_error(with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us", location_threshold = 0.9))),
               "location filter")
})

test_that("reads the detections with the right types and current paths", {
  am <- analysed_card()
  d <- read_detections(output_csv <- file.path(am$output, sprintf("AudioMoth_%s_detections.csv", device)))
  expect_type(d$device_id, "character")
  expect_type(d$day_folder, "character")
  expect_type(d$no_doubts, "logical")
  am$detections <- NULL
  am$recordings$path <- sub("results", "moved", am$recordings$path, fixed = TRUE)
  expect_true(all(dirname(read_detections(am)$path) %in% dirname(am$recordings$path)))
})

test_that("prepares the audio: converts to 48 kHz only what is needed", {
  skip_if_no_ffmpeg()
  am <- read_card(make_card(rate = 96000))
  am <- suppressMessages(prepare_audio(am))
  ok <- !is.na(am$recordings$birdnet_path)
  expect_equal(sum(ok), 4)
  expect_true(all(grepl("audio_48k", am$recordings$birdnet_path[ok])))
  expect_equal(tuneR::readWave(am$recordings$birdnet_path[ok][1], header = TRUE)$sample.rate, 48000)
  # A truncated copy is converted again
  writeBin(readBin(am$recordings$birdnet_path[ok][1], "raw", 1000), am$recordings$birdnet_path[ok][1])
  expect_false(AudiomothR:::converted_ok(am$recordings, which(ok)[1]))
})
