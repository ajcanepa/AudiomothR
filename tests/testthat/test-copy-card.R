test_that("copy_to = TRUE copies the card into the results folder and works on the copy", {
  card <- make_card()
  out <- tempfile("results_")
  am <- read_card(card, output = out, copy_to = TRUE)
  copy <- file.path(normalizePath(out), "recordings", "20261010-20261011")
  expect_equal(am$folder, normalizePath(copy))
  expect_equal(am$card_folder, normalizePath(card))
  # Same structure and files as the card (the empty WAV too)
  expect_true(file.exists(file.path(copy, "CONFIG.TXT")))
  card_files <- sort(list.files(card, recursive = TRUE))
  expect_equal(sort(list.files(copy, recursive = TRUE)), card_files)
  expect_equal(unname(file.size(file.path(copy, card_files))), unname(file.size(file.path(card, card_files))))
  # The inventory points to the copy, and the deployment keeps the card
  expect_true(all(startsWith(am$recordings$path, normalizePath(copy))))
  expect_equal(am$deployments$folder, normalizePath(copy))
  expect_equal(am$deployments$card_folder, normalizePath(card))

  # The card can now be removed: the analysis works with the copy
  unlink(card, recursive = TRUE)
  am <- with_mock_birdnet(suppressMessages(suppressWarnings(analyze_birdnet(am, language = "en_us"))))
  expect_gt(nrow(am$detections), 0)
  expect_true(all(file.exists(am$detections$path)))
})

test_that("a copy into a backup folder goes by box, and is resumed", {
  card <- make_card()
  backup <- tempfile("backup_")
  am <- read_card(card, output = tempfile(), copy_to = backup)
  copy <- normalizePath(file.path(backup, paste0("AudioMoth_", device), "20261010-20261011"))
  expect_equal(am$folder, copy)

  # A file lost in the copy (or an interrupted copy) is copied again; the rest is kept
  f <- file.path(copy, "20261010", sprintf("%s_20261010_060000.WAV", device))
  unlink(f)
  kept <- file.path(copy, "CONFIG.TXT")
  time_kept <- file.mtime(kept)
  expect_message(am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = am$output, copy_to = backup),
                 "Copying the card")
  expect_true(file.exists(f))
  expect_equal(file.mtime(kept), time_kept)

  # Everything copied: nothing to do
  expect_message(read_audiomoth(card, coordinates = "41.00, -3.00", output = am$output, copy_to = backup),
                 "already complete")
  # Reading the copy again later needs no copy_to, and keeps the same deployment
  # (with copy_to it is recognised as the copy itself)
  expect_message(read_audiomoth(copy, output = am$output, copy_to = backup), "already the copy")
  out_true <- tempfile()
  am_true <- read_card(card, output = out_true, copy_to = TRUE)
  expect_message(read_audiomoth(am_true$folder, output = out_true, copy_to = TRUE), "already the copy")
  am2 <- read_card(copy, output = am$output)
  expect_equal(am2$deployment, am$deployment)
  expect_equal(nrow(am2$deployments), 1)
  expect_equal(am2$deployments$card_folder, normalizePath(card))
})

test_that("copy_to is checked", {
  card <- make_card()
  expect_error(read_card(card, output = tempfile(), copy_to = 3), "copy_to")
  # The copy cannot be made inside the card
  expect_error(read_card(card, output = file.path(card, "results"), copy_to = TRUE), "inside the card")
})

test_that("process_audiomoth() passes copy_to", {
  card <- make_card()
  out <- tempfile()
  am <- with_mock_birdnet(suppressMessages(suppressWarnings(
    process_audiomoth(card, coordinates = "41.00, -3.00", output = out, copy_to = TRUE,
                      export = FALSE, language = "en_us"))))
  expect_equal(am$folder, normalizePath(file.path(out, "recordings", "20261010-20261011")))
})

test_that("paths inside a folder are recognised with any separator (Windows)", {
  under <- AudiomothR:::path_under
  expect_true(under("C:\\Users\\me\\card\\results\\x.wav", "C:\\Users\\me\\card"))
  expect_true(under("C:/Users/me/card/results", "C:\\Users\\me\\card\\"))
  expect_false(under("C:\\Users\\me\\card2\\x.wav", "C:\\Users\\me\\card"))
  expect_false(under("C:\\Users\\me\\card", "C:\\Users\\me\\card"))
  expect_true(under("/media/SD/results/a.csv", "/media/SD"))
  expect_false(under("/media/SDX/a.csv", "/media/SD"))
})
