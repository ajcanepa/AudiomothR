test_that("creates the validation page sorted from the least plausible record", {
  am <- analysed_card()
  html <- suppressMessages(create_validation(am, spectrograms = FALSE, open = FALSE))
  expect_true(file.exists(html))
  page <- paste(readLines(html, encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("__AUDIOMOTHR_DATA__", page, fixed = TRUE))
  expect_match(page, "\"record_id\":\"20261010_Cettia_cetti\"", fixed = TRUE)
  v <- AudiomothR:::read_csv(file.path(am$output, "validation", sprintf("AudioMoth_%s_validation.csv", device)))
  expect_equal(v$scientific_name[nrow(v)], "Cettia cetti") # the most plausible, last
  expect_true(all(is.na(v$decision)))
  expect_gt(length(list.files(file.path(am$output, "validation", "clips"))), 0)
  expect_null(read_validation(am))
})

test_that("applies the decisions downloaded from the page", {
  am <- analysed_card()
  suppressMessages(create_validation(am, spectrograms = FALSE, open = FALSE))
  v <- AudiomothR:::read_csv(file.path(am$output, "validation", sprintf("AudioMoth_%s_validation.csv", device)))
  # The browser saves the decisions in the Downloads folder
  downloads <- tempfile("Downloads")
  dir.create(downloads)
  old <- options(AudiomothR.downloads = downloads)
  on.exit(options(old))
  v$decision[v$record_id == "20261011_Turdus_merula"] <- "valid"
  v$decision[v$record_id == "20261010_Cettia_cetti"] <- "invalid"
  v$new_name[v$record_id == "20261011_Cettia_cetti"] <- "Corvus monedula — Eurasian Jackdaw"
  AudiomothR:::write_csv(v, file.path(downloads, sprintf("AudioMoth_%s_validation (1).csv", device)))

  val <- suppressMessages(read_validation(am))
  expect_equal(sum(val$decision == "valid", na.rm = TRUE), 1)
  expect_equal(val$new_name[val$record_id == "20261011_Cettia_cetti"], "Corvus monedula")
  expect_true(file.exists(attr(val, "file")))

  obs <- suppressWarnings(suppressMessages(export_observation(am, file = tempfile(fileext = ".csv"))))
  # Turdus merula: a single detection of 0.60, exported because it was validated
  expect_true("Turdus merula" %in% obs$`scientific name`)
  expect_equal(obs$`is certain`[obs$`scientific name` == "Turdus merula"], "True")
  # Relabelled, and translated into its IOC name
  expect_true("Coloeus monedula" %in% obs$`scientific name`)
  # Marked as not valid
  expect_false(any(obs$date == "2026-10-10" & obs$`scientific name` == "Cettia cetti"))
  expect_match(obs$notes[obs$`scientific name` == "Turdus merula"], "checked by listening")

  only <- suppressWarnings(suppressMessages(export_observation(am, validated_only = TRUE, file = tempfile(fileext = ".csv"))))
  expect_setequal(only$`scientific name`, c("Turdus merula", "Coloeus monedula"))
  ignored <- suppressWarnings(suppressMessages(export_observation(am, validation = FALSE, file = tempfile(fileext = ".csv"))))
  expect_equal(ignored$`scientific name`, "Cettia cetti")

  # Creating the page again keeps the decisions
  suppressMessages(create_validation(am, spectrograms = FALSE, open = FALSE))
  expect_equal(suppressMessages(read_validation(am))$decision, val$decision)
})

test_that("checks the decisions and requires them when asked", {
  am <- analysed_card()
  expect_error(read_validation(am, required = TRUE), "no validation")
  f <- tempfile(fileext = ".csv")
  AudiomothR:::write_csv(data.frame(record_id = "20261010_Cettia_cetti", scientific_name = "Cettia cetti",
                                    decision = "maybe", new_name = "Avis inventada"), f)
  expect_warning(expect_warning(v <- suppressMessages(read_validation(am, file = f)), "Unknown decisions"), "not BirdNET")
  expect_true(is.na(v$decision) && is.na(v$new_name))
})
