test_that("a results folder in tempdir() is noted once per session", {
  rm(list = ls(notes_shown), envir = notes_shown)
  op <- options(AudiomothR.quiet = FALSE)
  on.exit({ options(op); rm(list = ls(notes_shown), envir = notes_shown) }, add = TRUE)
  out <- normalizePath(file.path(tempdir(), "results_box"), mustWork = FALSE)
  expect_message(expect_true(note_temporary_output(out)), "temporary folder of R")
  expect_false(note_temporary_output(out))
  rm(list = ls(notes_shown), envir = notes_shown)
  elsewhere <- if (.Platform$OS.type == "windows") "C:/AudiomothR_results/box_01" else "/srv/AudiomothR_results/box_01"
  expect_false(note_temporary_output(elsewhere))
})

test_that("the hint for snap browsers only concerns /tmp on Linux", {
  expect_null(snap_browser_hint("/home/user/AudiomothR_results/validation/page.html"))
  skip_if_not(Sys.info()[["sysname"]] == "Linux")
  hint <- snap_browser_hint("/tmp/RtmpX/validation/page.html")
  if (any(file.exists(c("/snap/bin/firefox", "/snap/bin/chromium")))) {
    expect_match(hint, "snap")
  } else {
    expect_null(hint)
  }
})

test_that("spectrogram_image() says where it saved the image, unless quiet", {
  wav <- tempfile(fileext = ".wav")
  tuneR::writeWave(tuneR::Wave(round(8000 * sin(2 * pi * 2000 * seq(0, 1, length.out = 48000))),
                               samp.rate = 48000, bit = 16), wav)
  png <- tempfile(fileext = ".png")
  op <- options(AudiomothR.quiet = FALSE)
  on.exit(options(op), add = TRUE)
  expect_message(spectrogram_image(wav, png), "Spectrogram in")
  expect_no_message(quietly(spectrogram_image(wav, png)))
  expect_false(isTRUE(getOption("AudiomothR.quiet")))
})

test_that("load_problem() says which package is missing or cannot be loaded", {
  expect_null(load_problem(c("stats", "utils")))
  expect_match(load_problem(c("stats", "notAPackage123")), "notAPackage123 is not installed")
})

test_that("check_requirements() returns what is available", {
  ok <- suppressMessages(check_requirements())
  expect_named(ok, c("ffmpeg", "birdnetR", "quarto", "knitr_rmarkdown", "map"))
  expect_type(ok, "logical")
})
