test_that("summarises the species with the criteria of the examples", {
  am <- analysed_card()
  r <- species_summary(am, 0.5)
  expect_equal(r$scientific_name[1], "Cettia cetti")
  expect_equal(r$detections[1], 4)
  expect_false("Human vocal" %in% r$scientific_name)
  # 0.90 and 0.88 without doubts in 2 recordings (0.95 has doubts)
  expect_equal(r$example_candidates[1], 2)
  expect_equal(species_summary(example_detections(), 0.4)$detections, c(2, 1, 1))
})

test_that("lists the detected species as a vector ready to copy and to use", {
  am <- analysed_card()
  out <- capture.output(species <- detected_species(am, min_confidence = 0.5))
  code <- paste(out[!startsWith(out, "#")], collapse = "\n")
  pasted <- eval(parse(text = code), envir = new.env())
  expect_equal(pasted, c(species), ignore_attr = TRUE)
  expect_equal(unname(species[c("Cettia cetti", "Turdus merula")]), c(2L, 0L))
  expect_s3_class(attr(species, "summary"), "data.frame")
  # Several recorders: the largest number of examples of a single recorder
  capture.output(several <- detected_species(list(am, am)))
  expect_equal(unname(several["Cettia cetti"]), 2L)
  expect_equal(attr(several, "summary")$detections[1], 4) # the same recorder twice
})

test_that("accepts a number of examples per species", {
  f <- AudiomothR:::examples_per_species
  expect_equal(f(c("Cettia cetti", "Turdus merula"), 2), c("Cettia cetti" = 2L, "Turdus merula" = 2L))
  expect_equal(f(c("Cettia cetti", "Turdus merula"), c(3, 1)), c("Cettia cetti" = 3L, "Turdus merula" = 1L))
  expect_equal(f(c("Cettia cetti" = 2, "Turdus merula" = 0), 5), c("Cettia cetti" = 2L))
  expect_error(f(c("Cettia cetti", "Turdus merula"), c(1, 2, 3)), "one per species")
  expect_error(f(c(2, 3), 1), "named after its species")
  expect_error(f(c("Cettia cetti", NA), 1), "empty")
})

test_that("chooses the examples by any name, without accents and only once", {
  am <- analysed_card()
  expect_warning(ex <- select_examples(am, "cetti's warbler", n = 5), "2 of the 5")
  expect_equal(ex$confidence, c(0.90, 0.88))
  expect_true(all(ex$no_doubts))
  # Scientific and common names of the same species: chosen once
  ex2 <- suppressMessages(select_examples(am, c("Cettia cetti" = 1, "CETTI'S WARBLER" = 2)))
  expect_equal(nrow(ex2), 2)
  expect_warning(select_examples(am, "Pica pica"), "no detections named")
  # The examples of the vignette, with the example detections
  ex3 <- select_examples(example_detections(), detected_species(example_detections(), example_confidence = 0.5, print = FALSE),
                         min_confidence = 0.5)
  expect_equal(ex3$scientific_name, c("Cettia cetti", "Troglodytes troglodytes"))
})

test_that("cuts the audio with a margin and creates the spectrogram and the video", {
  skip_if_no_ffmpeg()
  am <- analysed_card()
  ex <- suppressMessages(extract_examples(am, "Cettia cetti", n = 1))
  expect_equal(nrow(ex), 1)
  expect_true(all(file.exists(c(ex$wav, ex$png, ex$mp4))))
  # Detection 0-3 s... with 1 s of margin: at most 4 s from the start
  expect_lte(length(tuneR::readWave(ex$wav)@left) / 48000, 5.01)
  # A second call with another style keeps both videos and the index grows
  ex2 <- suppressMessages(extract_examples(am, "Cettia cetti", n = 1, style = "scroll"))
  expect_true(file.exists(ex$mp4) && file.exists(ex2$mp4))
  index <- AudiomothR:::read_csv(file.path(am$output, "examples", sprintf("AudioMoth_%s_examples.csv", device)))
  expect_equal(nrow(index), 1)
  expect_false(any(grepl("^/", index$png)))
  suppressMessages(extract_examples(am, "Troglodytes troglodytes", n = 1, min_confidence = 0.2,
                                    no_doubts = FALSE, video = FALSE))
  index <- AudiomothR:::read_csv(file.path(am$output, "examples", sprintf("AudioMoth_%s_examples.csv", device)))
  expect_setequal(index$scientific_name, c("Cettia cetti", "Troglodytes troglodytes"))
})

test_that("the margin stays within the recording and 24-bit files are read", {
  w <- tempfile(fileext = ".wav")
  write_wav(w, duration = 8)
  r <- AudiomothR:::cut_audio(w, -1, 9)
  expect_equal(c(r$from, r$to), c(0, 8))
  skip_if_no_ffmpeg()
  w24 <- tempfile(fileext = ".wav")
  AudiomothR:::run_ffmpeg(c("-i", w, "-c:a", "pcm_s24le", w24))
  png <- tempfile(fileext = ".png")
  spectrogram_image(w24, png)
  expect_true(file.exists(png))
})

test_that("checks the arguments of the examples", {
  am <- analysed_card()
  expect_error(extract_examples(am, "Cettia cetti", margin_s = -1), "margin_s")
  expect_error(extract_examples(am, "Cettia cetti", style = "desplazamiento"), "style")
  expect_error(extract_examples(am, "Cettia cetti", frecuencia_maxima = 4000), "unused argument")
})
