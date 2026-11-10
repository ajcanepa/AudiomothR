test_that("reads species lists in all their forms", {
  quiet <- function(x) suppressMessages(suppressWarnings(x))
  # Vector, with authors, subspecies, case and spaces
  sl <- quiet(read_species_list(c("Cettia cetti (Temminck, 1820)", " turdus  merula ", "Parus major major")))
  expect_setequal(sl$scientific_name, c("Cettia cetti", "Turdus merula", "Parus major"))
  expect_true(all(sl$match == "birdnet"))

  # Species list of BirdNET-Analyzer
  f <- tempfile(fileext = ".txt")
  writeLines(c("# my list", "", "Cettia cetti_Cetti's Warbler", "Human vocal_Human vocal"), f)
  sl <- quiet(read_species_list(f))
  expect_setequal(sl$scientific_name, c("Cettia cetti", "Human vocal"))

  # CSV with the column found by its name (not the first one), and the template
  f <- tempfile(fileext = ".csv")
  writeLines(c("n,Scientific Name,notes", "1,Cettia cetti,a", "2,Asio otus,b"), f)
  expect_setequal(quiet(read_species_list(f))$scientific_name, c("Cettia cetti", "Asio otus"))
  template <- system.file("extdata", "example", "species_list.csv", package = "AudiomothR")
  expect_gt(nrow(quiet(read_species_list(template))), 10)

  # Data frame (e.g. the result of gbif_species_list())
  df <- data.frame(scientific_name = c("Cettia cetti", "Asio otus"), records = 1:2)
  expect_equal(nrow(quiet(read_species_list(df))), 2)
})

test_that("translates names of IOC, Observation.org and GBIF into BirdNET names", {
  # Synonym of Observation.org (offline) and names that BirdNET does not know
  sl <- suppressMessages(suppressWarnings(read_species_list(c("Carduelis chloris", "Otis tarda", "Xxx yyy"))))
  expect_equal(sl$scientific_name, "Chloris chloris")
  expect_equal(sl$match, "observation")
  expect_setequal(attr(sl, "not_found"), c("Otis tarda", "Xxx yyy"))
  expect_warning(suppressMessages(read_species_list(c("Cettia cetti", "Xxx yyy"))), "not species of BirdNET")

  # Other synonyms are looked up in GBIF (here a mock), by the key of the accepted species
  op <- options(AudiomothR.gbif_synonyms = TRUE)
  on.exit(options(op), add = TRUE)
  gbif <- AudiomothR:::gbif_table()
  local_mocked_bindings(gbif_get = function(url, attempts = 3) {
    if (grepl("Parus%20caeruleus", url)) {
      return(list(class = "Aves", matchType = "EXACT", status = "SYNONYM",
                  speciesKey = gbif$gbif_key[gbif$birdnet_name == "Cyanistes caeruleus"]))
    }
    list(matchType = "NONE")
  }, .package = "AudiomothR")
  sl <- suppressMessages(suppressWarnings(read_species_list(c("Parus caeruleus", "Xxx yyy"))))
  expect_equal(sl$scientific_name, "Cyanistes caeruleus")
  expect_equal(sl$match, "gbif")
  # Without a connection the names are only reported
  local_mocked_bindings(gbif_get = function(url, attempts = 3) stop("no connection"), .package = "AudiomothR")
  sl <- suppressMessages(suppressWarnings(read_species_list("Parus caeruleus")))
  expect_equal(nrow(sl), 0)
})

test_that("rejects lists that are not lists", {
  expect_error(read_species_list(1:3), "species_list")
  expect_error(read_species_list("/no/such/list.txt"), "does not exist")
  expect_error(suppressWarnings(suppressMessages(read_species_list(character()))), "species_list|empty")
})

test_that("analyze_birdnet() only looks for the species of the list", {
  am <- read_card()
  calls <- new.env()
  am <- with_mock_birdnet(suppressMessages(suppressWarnings(
    analyze_birdnet(am, language = "en_us", species_list = c("Turdus merula", "Troglodytes troglodytes")))),
    calls = calls)
  expect_setequal(sub("_.*$", "", calls$filter), c("Turdus merula", "Troglodytes troglodytes"))
  sp <- function(a) unique(a$detections$scientific_name[a$detections$is_species])
  expect_setequal(sp(am), c("Turdus merula", "Troglodytes troglodytes"))
  expect_false(am$analysis$parameters$location_filter)
  expect_equal(am$analysis$parameters$species_list_n, 2)
  expect_true(file.exists(file.path(am$analysis$cache, "species_list.csv")))
  # The probability of occurrence is still given
  expect_false(all(is.na(am$detections$location_prob)))

  # Another list is another analysis (its own cache)
  calls$n <- 0
  am2 <- with_mock_birdnet(suppressMessages(suppressWarnings(
    analyze_birdnet(am, language = "en_us", species_list = "Cettia cetti"))), calls = calls)
  expect_gt(calls$n, 0)
  expect_false(identical(am2$analysis$cache, am$analysis$cache))
  expect_setequal(sp(am2), "Cettia cetti")
  # The same list again: nothing to analyse
  calls$n <- 0
  with_mock_birdnet(suppressMessages(suppressWarnings(
    analyze_birdnet(am, language = "en_us", species_list = "Cettia cetti"))), calls = calls)
  expect_equal(calls$n, 0)

  expect_error(suppressWarnings(suppressMessages(analyze_birdnet(am, species_list = "Xxx yyy"))),
               "No name")
})

test_that("gbif_species_list() turns the species of GBIF into BirdNET names", {
  gbif <- AudiomothR:::gbif_table()
  key_of <- function(n) as.character(gbif$gbif_key[match(n, gbif$birdnet_name)])
  queries <- character()
  local_mocked_bindings(gbif_get = function(url, attempts = 3) {
    queries <<- c(queries, url)
    if (grepl("/species/", url)) return(list(canonicalName = "Otis tarda"))
    list(count = 30, facets = data.frame(field = "SPECIES_KEY", counts = I(list(data.frame(
      name = c(key_of("Cettia cetti"), key_of("Troglodytes troglodytes"), key_of("Asio otus"), "99999999"),
      count = c(20, 7, 1, 2))))))
  }, .package = "AudiomothR")

  sp <- suppressMessages(gbif_species_list("41.35, -3.70", radius_km = 20, months = c(4, 5)))
  expect_equal(sp$scientific_name, c("Cettia cetti", "Troglodytes troglodytes", "Asio otus"))
  expect_equal(sp$records, c(20, 7, 1))
  expect_equal(attr(sp, "not_in_birdnet"), "Otis tarda")
  q <- queries[1]
  expect_match(q, "taxonKey=212")
  expect_match(q, "geoDistance=41.35000%2C-3.70000%2C20km")
  expect_match(q, "month=4&month=5")
  expect_match(q, "datasetKey=4fa7b334")

  # min_records, a file and its use as species_list
  f <- tempfile(fileext = ".csv")
  sp <- suppressMessages(gbif_species_list("41.35, -3.70", min_records = 5, file = f))
  expect_equal(sp$scientific_name, c("Cettia cetti", "Troglodytes troglodytes"))
  expect_setequal(suppressMessages(read_species_list(f))$scientific_name, sp$scientific_name)

  # An audiomoth object: its site and the months of its recordings (October)
  queries <- character()
  am <- read_card()
  suppressMessages(gbif_species_list(am, datasets = "all"))
  expect_match(queries[1], "month=10")
  expect_false(grepl("datasetKey", queries[1]))

  expect_error(gbif_species_list("41.35, -3.70", datasets = "ebirds"), "datasets")
  expect_error(gbif_species_list("41.35, -3.70", months = 13), "months")
})
