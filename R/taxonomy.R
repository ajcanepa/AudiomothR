# Species names: from BirdNET v2.4 labels (eBird/Clements taxonomy of about
# 2021) to the IOC World Bird List v15.2 used by Observation.org, and matching
# of the names typed by the user. The tables in inst/extdata/taxonomy/ are
# built by data-raw/build_taxonomy.R.

cache <- new.env(parent = emptyenv())

#' BirdNET v2.4 label -> IOC 15.2 name (match: same, split, synonym, english,
#' manual, not_bird)
#' @noRd
taxonomy_table <- function() {
  if (is.null(cache$taxonomy)) {
    cache$taxonomy <- read_csv(package_file("extdata", "taxonomy", "birdnet_v2.4_to_ioc_15.2.csv.gz"))
  }
  cache$taxonomy
}

#' IOC 15.2 species with English and Spanish names
#' @noRd
ioc_table <- function() {
  if (is.null(cache$ioc)) cache$ioc <- read_csv(package_file("extdata", "taxonomy", "ioc_15.2_birds.csv.gz"))
  cache$ioc
}

#' Splits that depend on the region (e.g. Cecropis daurica in Europe is the
#' IOC species Cecropis rufula)
#' @noRd
regional_rules <- function() {
  if (is.null(cache$rules)) cache$rules <- read_csv(package_file("extdata", "taxonomy", "regional_rules.csv"))
  cache$rules
}

#' IOC name of each BirdNET scientific name
#'
#' Order: own equivalences > regional rule for the location > table of
#' BirdNET v2.4 -> IOC 15.2 > the name itself when it already is an IOC name.
#' @return Data frame with `birdnet`, `ioc`, `match` ("not_bird" for classes
#'   and animals that are not birds, "none" for birds without IOC name) and
#'   `note` (regional rule or split).
#' @noRd
ioc_names <- function(names, lat = NA, lon = NA, equivalences = NULL) {
  names <- unique(names)
  tax <- taxonomy_table()
  k <- match(names, tax$birdnet_name)
  out <- data.frame(birdnet = names, ioc = tax$ioc_name[k], match = tax$match[k],
                    note = NA_character_, stringsAsFactors = FALSE)
  # Names that are not BirdNET labels (relabelled during the validation) may
  # already be IOC names
  ioc <- ioc_table()
  direct <- is.na(k) & names %in% ioc$ioc_name
  out$ioc[direct] <- names[direct]
  out$match[direct] <- "same"
  out$match[is.na(out$match)] <- "none"
  out$ioc[out$match == "not_bird"] <- NA_character_

  rules <- regional_rules()
  if (!is.na(lat) && !is.na(lon)) {
    hit <- rules[rules$lat_min <= lat & lat <= rules$lat_max & rules$lon_min <= lon & lon <= rules$lon_max, , drop = FALSE]
    k <- match(out$birdnet, hit$birdnet_name)
    use <- !is.na(k)
    out$ioc[use] <- hit$ioc_name[k[use]]
    out$match[use] <- "regional"
    out$note[use] <- sprintf("%s in IOC 15.2 for %s", hit$ioc_name[k[use]], hit$region[k[use]])
  }
  split <- out$match == "split"
  out$note[split] <- sprintf("IOC has split %s: check the population", out$birdnet[split])

  if (length(equivalences)) {
    own <- out$birdnet %in% names(equivalences)
    out$ioc[own] <- unname(equivalences[out$birdnet[own]])
    out$match[own] <- "own"
    out$note[own] <- NA_character_
  }
  out
}

#' Checks the own equivalences "BirdNET name" = "IOC name"
#' @noRd
check_equivalences <- function(equivalences) {
  if (is.null(equivalences)) return(NULL)
  equivalences <- unlist(equivalences)
  if (!is.character(equivalences) || is.null(names(equivalences)) || any(!nzchar(names(equivalences)))) {
    abort("{.arg equivalences} must be a named vector: {.code c(\"BirdNET name\" = \"IOC name\")}.")
  }
  names(equivalences) <- gsub("\\s+", " ", trimws(names(equivalences)))
  equivalences <- stats::setNames(gsub("\\s+", " ", trimws(equivalences)), names(equivalences))
  bad <- setdiff(equivalences, ioc_table()$ioc_name)
  if (length(bad)) {
    abort("{cli::qty(bad)}{?This name/These names} of {.arg equivalences} {?is/are} not in the IOC World Bird List 15.2: {.val {bad}}.")
  }
  equivalences
}

#' Lower case without accents, single spaces
#' @noRd
normalize_name <- function(x) {
  x <- tolower(safe_name(gsub("\\s+", " ", trimws(x))))
  gsub("_", " ", x, fixed = TRUE)
}

#' Scientific names of the detections that a name typed by the user refers to
#'
#' The name may be the scientific or the common name of BirdNET (any case,
#' with or without accents) or the IOC name (scientific, English or Spanish).
#' @return A list with one character vector per requested name.
#' @noRd
match_species <- function(requested, d) {
  sci <- unique(d$scientific_name)
  common <- d$common_name[match(sci, d$scientific_name)]
  tax <- taxonomy_table()
  ioc <- ioc_table()
  ioc_of <- tax$ioc_name[match(sci, tax$birdnet_name)] %|NA|% sci
  k <- match(ioc_of, ioc$ioc_name)
  keys <- data.frame(sci = sci, a = normalize_name(sci), b = normalize_name(common),
                     c = normalize_name(ioc_of), d = normalize_name(ioc$english[k] %|NA|% ""),
                     e = normalize_name(ioc$spanish[k] %|NA|% ""), stringsAsFactors = FALSE)
  lapply(normalize_name(requested), function(r) {
    unique(keys$sci[keys$a == r | keys$b == r | keys$c == r | keys$d == r | keys$e == r])
  })
}

#' Warns about requested names without detections, suggesting similar ones
#' @noRd
warn_unknown_species <- function(requested, d) {
  if (length(requested) == 0) return(invisible())
  pool <- unique(c(d$scientific_name, d$common_name))
  for (r in requested) {
    similar <- utils::head(agrep(r, pool, ignore.case = TRUE, value = TRUE, max.distance = 0.2), 3)
    cli::cli_warn(c("There are no detections named {.val {r}}.",
                    "i" = if (length(similar)) "Did you mean {.or {.val {similar}}}?"))
  }
}
