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
