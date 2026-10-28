columns <- c("date", "time", "scientific name", "lat", "lng", "accuracy", "number", "notes",
             "sex", "is certain", "is escape", "activity", "life stage", "method",
             "counting method", "related species", "external reference", "obscurity", "embargo date")

test_that("the CSV has exactly the columns of the Observation.org example", {
  am <- analysed_card()
  file <- tempfile(fileext = ".csv")
  obs <- suppressWarnings(suppressMessages(export_observation(am, file = file)))
  expect_equal(names(obs), columns)
  read <- utils::read.csv(file, check.names = FALSE, encoding = "UTF-8")
  expect_equal(names(read), columns)
  expect_false(identical(readBin(file, "raw", 3), as.raw(c(0xef, 0xbb, 0xbf)))) # no BOM
  expect_true(file.exists(sub("csv$", "json", file)))

  # Cettia cetti: 3 detections >= 0.8 on 10/10 (exported) and none on 11/10
  expect_equal(obs$`scientific name`, "Cettia cetti")
  expect_equal(obs$date, "2026-10-10")
  expect_equal(obs$time, "08:00")
  expect_equal(obs$lat, 41)
  expect_equal(obs$accuracy, 698)
  expect_equal(obs$method, "Oído")
  expect_equal(obs$`is certain`, "False")
  expect_match(obs$notes, "^Identified with BirdNET v2.4 \\(best detection")
  expect_equal(obs$`external reference`, sprintf("AudioMoth_%s_20261010_Cettia_cetti", device))
  spanish <- suppressWarnings(suppressMessages(export_observation(am, file = tempfile(fileext = ".csv"), language = "es")))
  expect_match(spanish$notes, "^ID mediante BirdNET v2.4")
})

test_that("leaves out what is not a bird and checks the fixed values", {
  am <- analysed_card()
  obs <- suppressWarnings(suppressMessages(export_observation(am, min_confidence = 0.5, min_detections = 1,
                                                              file = tempfile(fileext = ".csv"))))
  expect_setequal(obs$`scientific name`, c("Cettia cetti", "Turdus merula"))
  expect_false(anyDuplicated(obs$`external reference`) > 0)
  expect_error(export_observation(am, method = "Heard"), "not a valid value")
  expect_equal(AudiomothR:::check_observation_value("counting method", "visto/sin contar"), "Visto/Sin contar")
  expect_error(export_observation(am, from = "2026/13/45"), "date")
  only_11 <- suppressMessages(export_observation(am, min_confidence = 0.5, min_detections = 1, from = "11/10/2026",
                                                 file = tempfile(fileext = ".csv")))
  expect_equal(unique(only_11$date), "2026-10-11")
})

test_that("translates BirdNET names into IOC 15.2, with regional splits", {
  tax <- AudiomothR:::ioc_names(c("Corvus monedula", "Bubulcus ibis", "Charadrius dubius", "Apus melba",
                                  "Accipiter gentilis", "Acanthis cabaret", "Human vocal", "Cettia cetti"))
  expect_equal(tax$ioc, c("Coloeus monedula", "Ardea ibis", "Thinornis dubius", "Tachymarptis melba",
                          "Astur gentilis", "Acanthis flammea", NA, "Cettia cetti"))
  expect_equal(tax$match[7], "not_bird")
  spain <- AudiomothR:::ioc_names(c("Cecropis daurica", "Calonectris diomedea", "Fringilla coelebs"), 41, -3)
  expect_equal(spain$ioc, c("Cecropis rufula", "Calonectris diomedea", "Fringilla coelebs"))
  canary <- AudiomothR:::ioc_names(c("Calonectris diomedea", "Fringilla coelebs"), 28.1, -15.4)
  expect_equal(canary$ioc, c("Calonectris borealis", "Fringilla canariensis"))
  # Every bird label of BirdNET v2.4 has an IOC name and a species of Observation.org
  t <- AudiomothR:::taxonomy_table()
  expect_false(any(t$match == "none"))
  expect_true(all(t$ioc_name[t$match != "not_bird"] %in% AudiomothR:::ioc_table()$ioc_name))
  obs <- AudiomothR:::observation_table()
  expect_true(all(t$obs_name[t$match != "not_bird"] %in% obs$species))
  expect_true(all(AudiomothR:::regional_rules()$ioc_name %in% obs$species))
  # Lumps and genera of Observation.org
  lumps <- AudiomothR:::ioc_names(c("Corvus cornix", "Saxicola stejnegeri", "Tumbezia salvini"), 41, -3)
  expect_equal(lumps$obs, c("Corvus corone", "Saxicola maurus", "Ochthoeca salvini"))
  expect_error(AudiomothR:::check_equivalences(c("Corvus monedula" = "Coloeus monedulla")), "not bird species of Observation.org")
  expect_equal(AudiomothR:::ioc_names("Corvus monedula", equivalences = c("Corvus monedula" = "Corvus cornix"))$obs,
               "Corvus corone") # a synonym of Observation.org becomes its species
})

test_that("uses the current location and does not overwrite an edited export", {
  am <- analysed_card()
  # The location of the deployment, as it is now in the inventory
  am$recordings$lat <- 41.5
  obs <- suppressWarnings(suppressMessages(export_observation(am)))
  expect_equal(obs$lat, 41.5)
  file <- file.path(am$output, sprintf("AudioMoth_%s_observation.csv", device))
  cat("edited by hand\n", file = file, append = TRUE)
  expect_warning(suppressMessages(export_observation(am)), "edited")
  expect_true(any(grepl("edited by hand", readLines(file))))
  expect_length(list.files(am$output, pattern = "_observation_[0-9]{8}_[0-9]{6}\\.csv$"), 1)
})

test_that("exports a species lumped by Observation.org under its name, keeping BirdNET's", {
  am <- analysed_card()
  am$detections$scientific_name[am$detections$scientific_name == "Turdus merula"] <- "Corvus cornix"
  obs <- suppressWarnings(suppressMessages(export_observation(am, min_confidence = 0.5, min_detections = 1,
                                                              file = tempfile(fileext = ".csv"))))
  k <- obs$`scientific name` == "Corvus corone"
  expect_true(any(k))
  expect_match(obs$notes[k], "BirdNET: Corvus cornix")
  expect_true(all(obs$`scientific name` %in% AudiomothR:::observation_table()$species))
})
