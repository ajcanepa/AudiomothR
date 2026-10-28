skip_if_no_quarto <- function() {
  testthat::skip_on_cran()
  testthat::skip_if(inherits(try(AudiomothR:::quarto_path(), silent = TRUE), "try-error"),
                    "Quarto is not installed")
  testthat::skip_if_not_installed("knitr")
  testthat::skip_if_not_installed("rmarkdown")
}

test_that("prepares the data of the report and protects the results folder", {
  am <- analysed_card()
  d <- AudiomothR:::report_data(list(am), tempfile(), 0.5)
  expect_equal(nrow(d$recorders), 1)
  expect_true(d$recorders$analysed)
  expect_equal(sum(d$recordings$analysed), 4)
  expect_false("Human vocal" %in% d$detections$scientific_name)
  # A recorder without analysis is reported, not shown as "0 species"
  am2 <- read_card()
  expect_warning(d2 <- AudiomothR:::report_data(list(am2), tempfile(), 0.5), "not been analysed")
  expect_false(d2$recorders$analysed)
  expect_error(create_report(am, output = am$output), "cannot be the results folder")
  expect_equal(AudiomothR:::yaml_string("A \"quoted\" site\\"), "\"A \\\"quoted\\\" site\\\\\"")
})

test_that("creates the PDF report of one recorder and of several", {
  skip_if_no_quarto()
  am <- analysed_card()
  am$site <- "River \"old bridge\" @site"
  pdf <- suppressMessages(create_report(am, map = FALSE, open = FALSE))
  expect_true(file.exists(pdf))
  folder <- dirname(pdf)
  expect_true(all(file.exists(file.path(folder, c("report.qmd", "report_data.rds", "_metadata.yml")))))
  # An edited template is kept
  cat("\nEdited by the user.\n", file = file.path(folder, "report.qmd"), append = TRUE)
  expect_message(create_report(am, map = FALSE, open = FALSE), "edited")
  expect_true(any(grepl("Edited by the user", readLines(file.path(folder, "report.qmd")))))

  # Several recorders, one without temperature and with a recording without date
  am2 <- analysed_card()
  am2$site <- "Other"
  am2$recordings$temperature_c <- NA
  am2$recordings$start_local[5] <- NA
  am2$recordings$local_date[5] <- NA
  expect_error(create_report(list(am, am2)), "output")
  for (by in c(TRUE, FALSE)) {
    pdf <- suppressMessages(create_report(list(am, am2), by_recorder = by, output = tempfile(), map = FALSE,
                                          open = FALSE))
    expect_true(file.exists(pdf))
  }
})

test_that("reports a box moved between two sites", {
  skip_if_no_quarto()
  card1 <- make_card()
  card2 <- tempfile("card_")
  dir.create(card2)
  file.copy(file.path(card1, "CONFIG.TXT"), card2)
  start <- as.POSIXct("2026-10-20 06:00:00", tz = "UTC")
  write_wav(file.path(card2, "20261020", sprintf("%s_20261020_060000.WAV", device)), comment = am_comment(start))
  box <- tempfile("box_")
  am <- read_card(card1, output = box, site = "River")
  am <- with_mock_birdnet(suppressMessages(analyze_birdnet(am, language = "en_us")))
  am <- suppressWarnings(read_card(card2, coordinates = "41.30, -3.40", output = box, site = "Forest"))
  am <- with_mock_birdnet(suppressWarnings(suppressMessages(analyze_birdnet(am, language = "en_us"))))
  d <- AudiomothR:::report_data(list(am), tempfile(), 0.5)
  expect_equal(d$deployments$site, c("River", "Forest"))
  expect_equal(d$recorders$recorder, sprintf("AudioMoth %s", device))
  pdf <- suppressMessages(create_report(am, map = TRUE, open = FALSE))
  expect_true(file.exists(pdf))
})
