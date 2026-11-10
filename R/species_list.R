# Own lists of species for BirdNET: reading them (vector, CSV, data frame or
# the species list of BirdNET-Analyzer) and building them from the
# occurrences of GBIF around the recorder (eBird, Observation.org and
# iNaturalist), without an account or a key.

#' Reads a list of species for BirdNET
#'
#' Translates a list of species into the names of BirdNET v2.4, so that it
#' can be given to [analyze_birdnet()] with `species_list`. It is called by
#' [analyze_birdnet()]; use it directly to check a list before the analysis.
#'
#' **Accepted forms of the list:**
#' - A vector of scientific names: `c("Burhinus oedicnemus", "Asio otus")`.
#' - The path of a text file (`.txt`) with one species per line, such as the
#'   species list of BirdNET-Analyzer (`Burhinus oedicnemus_Eurasian
#'   Thick-knee`; the part after `_` is ignored) or just scientific names.
#'   Empty lines and lines starting with `#` are ignored.
#' - The path of a CSV file, or a data frame, with a column of scientific
#'   names. The column is found by its name (`scientific_name`, `scientific
#'   name`, `Scientific Name`, `species`, `taxon`... any case); otherwise the
#'   first column is used. Other columns (common name, number of records,
#'   notes...) are ignored. The result of [gbif_species_list()] is such a
#'   table.
#'
#' **Names.** Each name is looked up as a name of BirdNET v2.4 (eBird/Clements
#' taxonomy of about 2021), then as a name of the IOC World Bird List v15.2,
#' of Observation.org (with its synonyms) and of the GBIF Backbone Taxonomy,
#' so lists taken from eBird, Observation.org, iNaturalist or GBIF work as
#' they are. Names that are still not found (e.g. old synonyms such as
#' *Parus caeruleus*) are looked up in the name matching service of GBIF
#' when there is an internet connection (`options(AudiomothR.gbif_synonyms =
#' FALSE)` turns it off). A name of a species that IOC or Observation.org split or lump may
#' stand for several BirdNET species, and all of them are kept. Subspecies are
#' reduced to their species and the authors of the names are ignored. The
#' non-species classes of BirdNET (`"Human vocal"`, `"Dog"`, `"Engine"`...)
#' are accepted by their exact name. Names that are not found are reported:
#' BirdNET cannot detect them.
#'
#' @param species_list The list: a vector of names, the path of a `.txt` or
#'   `.csv` file, or a data frame.
#' @return A data frame with one row per BirdNET species: `scientific_name`
#'   (BirdNET name), `english_name` (BirdNET), `input` (the name of the list)
#'   and `match` (`"birdnet"`, `"ioc"`, `"observation"` or `"gbif"`). The
#'   names that were not found are in the attribute `"not_found"`.
#' @seealso [gbif_species_list()] to build a list from GBIF, and
#'   `vignette("audiomothr-2-species")`.
#' @examples
#' # "Carduelis chloris" is a synonym (Observation.org) of Chloris chloris
#' read_species_list(c("Burhinus oedicnemus", "Asio otus", "Carduelis chloris"))
#'
#' # The species list of BirdNET-Analyzer
#' f <- tempfile(fileext = ".txt")
#' writeLines(c("Burhinus oedicnemus_Eurasian Thick-knee", "Asio otus_Long-eared Owl"), f)
#' read_species_list(f)
#'
#' # A CSV file with a column of scientific names (template in the package)
#' read_species_list(system.file("extdata", "example", "species_list.csv",
#'                               package = "AudiomothR"))
#' @export
read_species_list <- function(species_list) {
  input <- species_list_names(species_list)
  if (length(input) == 0) abort("The species list is empty.")
  out <- match_species_list(input)
  not_found <- attr(out, "not_found")
  inform(c("v" = "Species list: {length(unique(out$scientific_name))} species of BirdNET from {length(input)} name{?s}."))
  if (length(not_found)) {
    cli::cli_warn(c("{length(not_found)} name{?s} of the species list {?is/are} not species of BirdNET v2.4 and {?is/are} ignored: {.val {utils::head(not_found, 10)}}{if (length(not_found) > 10) ', ...' else ''}.",
                    "i" = "Check the spelling. Species without a model in BirdNET (e.g. {.emph Otis tarda}) cannot be detected."))
  }
  out
}

#' Names of a species list given in any of its forms
#' @noRd
species_list_names <- function(x) {
  if (is.data.frame(x)) return(clean_species_names(species_column(x)))
  if (!is.character(x) || length(x) == 0 || anyNA(x)) {
    abort("{.arg species_list} must be a vector of scientific names, the path of a {.file .txt} or {.file .csv} file, or a data frame.")
  }
  if (length(x) == 1 && grepl("\\.(csv|txt|tsv)$", x, ignore.case = TRUE)) {
    path <- normalizePath(path.expand(x), mustWork = FALSE)
    if (!file.exists(path)) abort("The species list {.file {path}} does not exist.")
    if (grepl("\\.txt$", path, ignore.case = TRUE)) {
      lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
      lines <- sub("^\ufeff", "", lines)
      lines <- trimws(lines)
      lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
      # BirdNET-Analyzer: "Scientific name_Common name"
      return(clean_species_names(sub("_.*$", "", lines)))
    }
    table <- if (grepl("\\.tsv$", path, ignore.case = TRUE)) {
      utils::read.delim(path, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8-BOM")
    } else read_csv(path)
    return(clean_species_names(species_column(table)))
  }
  clean_species_names(x)
}

#' The column of scientific names of a table (by its name, or the first one)
#' @noRd
species_column <- function(x) {
  if (ncol(x) == 0 || nrow(x) == 0) abort("The species list has no rows.")
  key <- gsub("[^a-z]", "", tolower(safe_name(names(x))))
  wanted <- c("scientificname", "scientific", "sciname", "latinname", "nombrecientifico",
              "species", "speciesname", "taxon", "taxonname", "name")
  hit <- match(wanted, key)
  col <- hit[!is.na(hit)][1] %|NA|% 1L
  as.character(x[[col]])
}

#' Scientific names without authors, subspecies or BirdNET common names
#' @noRd
clean_species_names <- function(x) {
  x <- gsub("\\s+", " ", trimws(as.character(x)))
  x <- sub("_.*$", "", x)
  x <- x[!is.na(x) & nzchar(x)]
  # The non-species classes of BirdNET are kept as they are
  keep <- x %in% non_species
  words <- strsplit(x, " ", fixed = TRUE)
  binomial <- vapply(words, function(w) {
    if (length(w) < 2) return(w[1] %||% "")
    paste(w[1], tolower(w[2]))
  }, character(1))
  binomial <- paste0(toupper(substr(binomial, 1, 1)), tolower(substring(binomial, 2)))
  out <- ifelse(keep, x, binomial)
  unique(out[nzchar(out)])
}

#' BirdNET v2.4 names of each name of a list (in this order: BirdNET, IOC,
#' Observation.org, GBIF)
#' @noRd
match_species_list <- function(names) {
  tax <- taxonomy_table()
  birds <- tax[tax$match != "not_bird", , drop = FALSE]
  gbif <- gbif_table()
  obs <- observation_table()
  rows <- lapply(names, function(n) {
    hit <- function(sci, how) {
      sci <- unique(sci[!is.na(sci)])
      if (length(sci)) data.frame(input = n, scientific_name = sci, match = how, stringsAsFactors = FALSE)
    }
    if (n %in% non_species) return(hit(n, "birdnet"))
    hit(tax$birdnet_name[tolower(tax$birdnet_name) == tolower(n)], "birdnet") %||%
      hit(birds$birdnet_name[birds$ioc_name %in% n], "ioc") %||%
      hit(birds$birdnet_name[birds$obs_name %in% obs$species[obs$scientific_name %in% n]], "observation") %||%
      hit(gbif$birdnet_name[gbif$gbif_species %in% n], "gbif")
  })
  out <- do.call(rbind, rows)
  # Other synonyms (e.g. "Parus caeruleus"): GBIF resolves them, when there
  # is a connection; the accepted species is then found by its key
  missing <- setdiff(names, out$input)
  missing <- missing[!missing %in% non_species]
  if (length(missing)) out <- rbind(out, gbif_synonyms(missing, gbif))
  if (is.null(out)) {
    out <- data.frame(input = character(), scientific_name = character(), match = character(),
                      stringsAsFactors = FALSE)
  }
  out <- out[!duplicated(out$scientific_name), , drop = FALSE]
  out$english_name <- tax$birdnet_english[match(out$scientific_name, tax$birdnet_name)] %|NA|% out$scientific_name
  out <- out[, c("scientific_name", "english_name", "input", "match")]
  rownames(out) <- NULL
  attr(out, "not_found") <- setdiff(names, out$input)
  out
}

#' BirdNET names of names that are synonyms in GBIF (asks the name matching
#' service of GBIF; without a connection, nothing is found and the names are
#' reported as not found)
#' @noRd
gbif_synonyms <- function(names, gbif) {
  if (isFALSE(getOption("AudiomothR.gbif_synonyms", TRUE))) return(NULL)
  if (length(names) > 100) names <- names[1:100]
  inform("Looking up {length(names)} name{?s} in GBIF (synonyms)...")
  rows <- list()
  for (n in names) {
    url <- paste0("https://api.gbif.org/v1/species/match?kingdom=Animalia&verbose=true&name=",
                  utils::URLencode(n, reserved = TRUE))
    res <- tryCatch(gbif_get(url, attempts = 1), error = function(e) NULL)
    if (is.null(res)) {
      inform("i" = "GBIF cannot be reached: synonyms are not looked up.")
      break
    }
    candidates <- c(list(res[setdiff(names(res), "alternatives")]),
                    if (is.data.frame(res$alternatives)) split(res$alternatives, seq_len(nrow(res$alternatives))))
    key <- NULL
    for (a in candidates) {
      if (identical(as.character(a$class), "Aves") && length(a$speciesKey) && !is.na(a$speciesKey[1]) &&
          identical(as.character(a$matchType), "EXACT")) {
        key <- as.character(a$speciesKey[1])
        break
      }
    }
    sci <- if (!is.null(key)) gbif$birdnet_name[as.character(gbif$gbif_key) %in% key]
    if (length(sci)) {
      rows[[n]] <- data.frame(input = n, scientific_name = sci, match = "gbif", stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}

#' GBIF species of each bird of BirdNET v2.4 (built by
#' data-raw/build_gbif_keys.R)
#' @noRd
gbif_table <- function() {
  if (is.null(cache$gbif)) {
    cache$gbif <- read_csv(package_file("extdata", "taxonomy", "birdnet_v2.4_to_gbif.csv.gz"))
  }
  cache$gbif
}

# --- Species lists from GBIF ---------------------------------------------------

# Datasets of GBIF with most of the bird observations of citizen science
gbif_datasets <- c(
  ebird = "4fa7b334-ce0d-4e88-aaae-2e0c138d049e",       # EOD - eBird Observation Dataset
  observation = "8a863029-f435-446a-821e-275f4f641165", # Observation.org, Nature data from around the World
  inaturalist = "50c9509d-22c7-4a22-a47d-8c48425ef4a7"  # iNaturalist Research-grade Observations
)

#' Builds a list of species from GBIF around a site
#'
#' Asks GBIF (<https://www.gbif.org>) which bird species have been observed
#' within `radius_km` of the recorder, in the months of the recordings, in the
#' datasets of eBird, Observation.org and iNaturalist that GBIF publishes. No
#' account or key is needed (it uses the public occurrence search of the GBIF
#' API), but it does need an internet connection. The result can be given
#' directly to [analyze_birdnet()] with `species_list`, saved with `file` to
#' be reviewed or edited (e.g. in a spreadsheet), or merged with an own list.
#'
#' **Why.** The location filter of BirdNET (see [analyze_birdnet()]) predicts
#' the species expected at a site from the eBird checklists, so it may leave
#' out species that are present but rarely recorded there: nocturnal or
#' secretive species (owls, Stone-curlew...), steppe birds in little visited
#' areas, scarce migrants. A list of the species actually observed around the
#' site, in a wide enough radius, keeps them, while still leaving out the
#' species of other continents.
#'
#' **How.** One query per site (the different locations of the deployments of
#' the box) with the GBIF occurrence search, counting the occurrences of each
#' species (`facet=speciesKey`) of the class Aves, present (not absences),
#' without geospatial issues. GBIF resolves the synonyms, and the species are
#' translated into BirdNET v2.4 names with a table of the package (GBIF
#' Backbone Taxonomy). Species of GBIF that BirdNET cannot detect are
#' reported in the attribute `"not_in_birdnet"`.
#'
#' **Citation.** The data belong to the observers and to the publishers of
#' each dataset. When the list is used in a publication, cite GBIF and the
#' datasets (e.g. "GBIF.org (2026) GBIF Occurrence Search, <query>, accessed
#' on <date>"; the queries are in the attribute `"queries"`). The result is
#' a summary (counts per species), not a GBIF download with a DOI.
#'
#' @param x An `audiomoth` object (the locations of its deployments and, by
#'   default, the months of its recordings) or coordinates in any format
#'   accepted by [parse_coordinates()].
#' @param radius_km Radius around each site, in km. Larger radii (25-50 km)
#'   give a more complete list in little visited areas; very large ones bring
#'   species of other habitats.
#' @param months Months (1 to 12) of the observations. By default, the months
#'   of the recordings of `x` (all the year for plain coordinates); `1:12` for
#'   all the year.
#' @param years Years of the observations: two values, from and to. By
#'   default the last ten years.
#' @param datasets Sources: any of `"ebird"`, `"observation"` and
#'   `"inaturalist"` (default, all three), or `"all"` for every dataset of
#'   GBIF (also museum collections and other surveys).
#' @param min_records Minimum number of occurrences for a species to enter the
#'   list (e.g. 2 or 3 to leave out single, perhaps wrong, records).
#' @param file Optional path of a CSV file where the list is saved.
#' @return A data frame with one row per BirdNET species, sorted by the number
#'   of occurrences: `scientific_name` (BirdNET), `english_name`,
#'   `gbif_name`, `records` and `match`. It can be given to
#'   [analyze_birdnet()] as `species_list`.
#' @seealso [read_species_list()] for the accepted formats of a list.
#' @examples
#' \dontrun{
#' # Around a site, all the year
#' sp <- gbif_species_list("41.35, -3.70", radius_km = 25)
#' head(sp)
#'
#' # Around the deployments of a box, in the months of its recordings, saved
#' # to be reviewed and then used in the analysis
#' sp <- gbif_species_list(am, radius_km = 30, file = "~/species_box_01.csv")
#' am <- analyze_birdnet(am, species_list = "~/species_box_01.csv")
#' }
#' @export
gbif_species_list <- function(x, radius_km = 25, months = NULL, years = NULL,
                              datasets = c("ebird", "observation", "inaturalist"),
                              min_records = 1, file = NULL) {
  check_number(radius_km, "radius_km", 0.1, 500)
  check_number(min_records, "min_records", 1, integer = TRUE)
  sites <- gbif_sites(x)
  if (is.null(months)) {
    months <- if (inherits(x, "audiomoth")) {
      sort(unique(as.integer(format(as.Date(stats::na.omit(x$recordings$local_date[x$recordings$valid])), "%m"))))
    }
    if (length(months) == 0) months <- 1:12
  }
  if (!is.numeric(months) || anyNA(months) || any(!months %in% 1:12)) abort("{.arg months} must be months from 1 to 12.")
  this_year <- as.integer(format(Sys.Date(), "%Y"))
  years <- years %||% c(this_year - 10L, this_year)
  if (!is.numeric(years) || length(years) != 2 || anyNA(years) || years[1] > years[2]) {
    abort("{.arg years} must be two years, from and to, e.g. {.code c(2015, 2026)}.")
  }
  if (identical(datasets, "all")) {
    keys <- character()
  } else {
    if (!is.character(datasets) || length(datasets) == 0 || any(!datasets %in% names(gbif_datasets))) {
      abort("{.arg datasets} must be any of {.val {names(gbif_datasets)}}, or {.val all}.")
    }
    keys <- gbif_datasets[unique(datasets)]
  }
  if (!is.null(file) && (!is.character(file) || length(file) != 1)) abort("{.arg file} must be the path of a CSV file.")

  queries <- vapply(seq_len(nrow(sites)), function(i) {
    params <- c(taxonKey = "212", occurrenceStatus = "PRESENT", hasGeospatialIssue = "false",
                geoDistance = sprintf("%.5f,%.5f,%gkm", sites$lat[i], sites$lon[i], radius_km),
                year = sprintf("%d,%d", as.integer(years[1]), as.integer(years[2])),
                stats::setNames(as.character(sort(unique(months))), rep("month", length(unique(months)))),
                stats::setNames(unname(keys), rep("datasetKey", length(keys))),
                limit = "0", facet = "speciesKey", facetLimit = "5000")
    paste0("https://api.gbif.org/v1/occurrence/search?",
           paste(names(params), vapply(params, utils::URLencode, "", reserved = TRUE), sep = "=", collapse = "&"))
  }, character(1))

  inform("Asking GBIF for the bird species within {radius_km} km of {nrow(sites)} site{?s} (months {paste(sort(unique(months)), collapse = ', ')}; {years[1]}-{years[2]})...")
  counts <- do.call(rbind, lapply(queries, function(q) {
    res <- gbif_get(q)
    f <- res$facets
    if (is.null(f) || length(f$counts) == 0) return(NULL)
    f <- f$counts[[1]]
    if (is.null(f) || nrow(f) == 0) return(NULL)
    data.frame(key = as.character(f$name), records = as.integer(f$count), stringsAsFactors = FALSE)
  }))
  if (is.null(counts) || nrow(counts) == 0) {
    abort("GBIF has no bird observations within {radius_km} km of the site{?s} with these criteria.",
          "i" = "Use a larger {.arg radius_km}, more {.arg months} or {.code datasets = \"all\"}.")
  }
  counts <- stats::aggregate(records ~ key, data = counts, FUN = sum)
  counts <- counts[counts$records >= min_records, , drop = FALSE]

  gbif <- gbif_table()
  gbif <- gbif[!is.na(gbif$gbif_key), , drop = FALSE]
  gbif$gbif_key <- as.character(gbif$gbif_key)
  hit <- counts$key %in% gbif$gbif_key
  out <- merge(counts[hit, , drop = FALSE], gbif[, c("birdnet_name", "gbif_species", "gbif_key")],
               by.x = "key", by.y = "gbif_key")
  out$match <- rep("gbif", nrow(out))

  # Keys that are not in the table: their names, matched to BirdNET when they
  # only differ in the spelling of the epithet (same genus)
  missing <- counts[!hit, , drop = FALSE]
  not_in_birdnet <- character()
  if (nrow(missing)) {
    tax <- taxonomy_table()
    birds <- tax$birdnet_name[tax$match != "not_bird"]
    for (i in seq_len(nrow(missing))) {
      name <- tryCatch(gbif_get(paste0("https://api.gbif.org/v1/species/", missing$key[i]))$canonicalName,
                       error = function(e) NULL) %||% paste("GBIF species", missing$key[i])
      same_genus <- birds[startsWith(birds, paste0(sub(" .*$", "", name), " "))]
      d <- if (length(same_genus)) utils::adist(name, same_genus)[1, ] else integer()
      if (length(d) && min(d) <= 2) {
        out <- rbind(out, data.frame(key = missing$key[i], records = missing$records[i],
                                     birdnet_name = same_genus[which.min(d)], gbif_species = name,
                                     match = "gbif (spelling)", stringsAsFactors = FALSE))
      } else {
        not_in_birdnet <- c(not_in_birdnet, name)
      }
    }
  }
  # One row per BirdNET species (a GBIF species lumped by GBIF may stand for
  # several BirdNET species, and several GBIF species for one BirdNET species)
  by_species <- split(out, out$birdnet_name)
  result <- data.frame(
    scientific_name = names(by_species),
    gbif_name = vapply(by_species, function(s) paste(unique(s$gbif_species), collapse = "; "), character(1)),
    records = vapply(by_species, function(s) sum(s$records), numeric(1)),
    match = vapply(by_species, function(s) s$match[1], character(1)),
    stringsAsFactors = FALSE)
  tax <- taxonomy_table()
  result$english_name <- tax$birdnet_english[match(result$scientific_name, tax$birdnet_name)]
  result <- result[order(-result$records, result$scientific_name),
                   c("scientific_name", "english_name", "gbif_name", "records", "match"), drop = FALSE]
  rownames(result) <- NULL
  attr(result, "not_in_birdnet") <- sort(unique(not_in_birdnet))
  attr(result, "queries") <- queries
  attr(result, "date") <- format(Sys.Date())
  inform(c("v" = "{nrow(result)} species of BirdNET observed in GBIF (with \u2265 {min_records} occurrence{?s}).",
           "i" = if (length(not_in_birdnet)) "{length(not_in_birdnet)} other species of GBIF cannot be detected by BirdNET (attribute {.code not_in_birdnet})."))
  if (!is.null(file)) {
    write_csv(result, path.expand(file))
    inform(c("v" = "List saved in {.file {path.expand(file)}}: review it and give it to {.fn analyze_birdnet} with {.arg species_list}."))
  }
  result
}

#' Sites of the query: the locations of the deployments of a box, or some
#' coordinates
#' @noRd
gbif_sites <- function(x) {
  if (inherits(x, "audiomoth")) {
    g <- x$recordings
    s <- unique(data.frame(lat = round(g$lat, 4), lon = round(g$lon, 4)))
    s <- s[!is.na(s$lat) & !is.na(s$lon), , drop = FALSE]
    if (nrow(s) == 0) s <- data.frame(lat = x$location$lat, lon = x$location$lon)
    return(s)
  }
  u <- parse_coordinates(x)
  data.frame(lat = u$lat, lon = u$lon)
}

#' A request to the GBIF API (JSON), with retries (replaced by a mock in the
#' tests)
#' @noRd
gbif_get <- function(url, attempts = 3) {
  old <- options(timeout = max(120, getOption("timeout")))
  on.exit(options(old))
  for (attempt in seq_len(attempts)) {
    res <- tryCatch(jsonlite::fromJSON(url), error = function(e) e)
    if (!inherits(res, "error")) return(res)
    if (attempt < attempts) Sys.sleep(2 * attempt)
  }
  abort("GBIF does not answer.", "x" = cli_escape(conditionMessage(res)),
        "i" = "Check the internet connection and try again later.")
}
