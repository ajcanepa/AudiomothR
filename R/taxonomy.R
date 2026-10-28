# Species names: from BirdNET v2.4 labels (eBird/Clements taxonomy of about
# 2021) to the IOC World Bird List v15.2 and then to the names of
# Observation.org (which follows IOC with its own lumps, genera and synonyms,
# and only accepts its own names), and matching of the names typed by the
# user. The tables in inst/extdata/taxonomy/ are
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

#' Bird species of Observation.org (`species`) and their synonyms
#' (`scientific_name` -> `species`)
#' @noRd
observation_table <- function() {
  if (is.null(cache$obs)) cache$obs <- read_csv(package_file("extdata", "taxonomy", "observation_birds.csv.gz"))
  cache$obs
}

#' Species of Observation.org for a name (itself, or the species of which it
#' is a synonym); NA when Observation.org does not know it
#' @noRd
observation_species <- function(names) {
  obs <- observation_table()
  obs$species[match(names, obs$scientific_name)]
}

#' Splits that depend on the region (e.g. Cecropis daurica in Europe is the
#' IOC species Cecropis rufula)
#' @noRd
regional_rules <- function() {
  if (is.null(cache$rules)) cache$rules <- read_csv(package_file("extdata", "taxonomy", "regional_rules.csv"))
  cache$rules
}

#' IOC and Observation.org names of each BirdNET scientific name
#'
#' Order: own equivalences > regional rule for the location > table of
#' BirdNET v2.4 -> IOC 15.2 -> Observation.org > the name itself when it
#' already is a name of Observation.org or of IOC.
#' @return Data frame with `birdnet`, `ioc`, `obs` (the name exported to
#'   Observation.org), `match` ("not_bird" for classes and animals that are
#'   not birds, "none" for birds without a name in Observation.org) and `note`
#'   (regional rule, split or lump of Observation.org).
#' @noRd
ioc_names <- function(names, lat = NA, lon = NA, equivalences = NULL) {
  names <- unique(names)
  tax <- taxonomy_table()
  k <- match(names, tax$birdnet_name)
  out <- data.frame(birdnet = names, ioc = tax$ioc_name[k], obs = tax$obs_name[k],
                    match = tax$match[k], note = NA_character_, stringsAsFactors = FALSE)
  lumped <- !is.na(k) & tax$obs_match[k] %in% c("lumped", "manual")
  out$note[lumped] <- sprintf("Observation.org includes %s in %s", out$birdnet[lumped], out$obs[lumped])
  # Names that are not BirdNET labels (relabelled during the validation) may
  # already be names of Observation.org or of IOC
  direct <- is.na(k)
  out$obs[direct] <- observation_species(names[direct])
  by_ioc <- direct & is.na(out$obs)
  out$obs[by_ioc] <- tax$obs_name[match(names[by_ioc], tax$ioc_name)]
  out$ioc[direct] <- ifelse(names[direct] %in% ioc_table()$ioc_name, names[direct], NA_character_)
  out$match[direct & !is.na(out$obs)] <- "same"
  out$match[is.na(out$match) | (out$match != "not_bird" & is.na(out$obs))] <- "none"
  out$ioc[out$match == "not_bird"] <- out$obs[out$match == "not_bird"] <- NA_character_

  rules <- regional_rules()
  if (!is.na(lat) && !is.na(lon)) {
    hit <- rules[rules$lat_min <= lat & lat <= rules$lat_max & rules$lon_min <= lon & lon <= rules$lon_max, , drop = FALSE]
    k <- match(out$birdnet, hit$birdnet_name)
    use <- !is.na(k)
    out$ioc[use] <- out$obs[use] <- hit$ioc_name[k[use]]
    out$match[use] <- "regional"
    out$note[use] <- sprintf("%s in IOC and Observation.org for %s", hit$ioc_name[k[use]], hit$region[k[use]])
  }
  split <- out$match == "split"
  out$note[split] <- sprintf("IOC has split %s: check the population", out$birdnet[split])

  if (length(equivalences)) {
    own <- out$birdnet %in% names(equivalences)
    out$ioc[own] <- out$obs[own] <- observation_species(unname(equivalences[out$birdnet[own]]))
    out$match[own] <- "own"
    out$note[own] <- NA_character_
  }
  out
}

#' Checks the own equivalences "BirdNET name" = "name of Observation.org"
#' @noRd
check_equivalences <- function(equivalences) {
  if (is.null(equivalences)) return(NULL)
  equivalences <- unlist(equivalences)
  if (!is.character(equivalences) || is.null(names(equivalences)) || any(!nzchar(names(equivalences)))) {
    abort("{.arg equivalences} must be a named vector: {.code c(\"BirdNET name\" = \"Observation.org name\")}.")
  }
  names(equivalences) <- gsub("\\s+", " ", trimws(names(equivalences)))
  equivalences <- stats::setNames(gsub("\\s+", " ", trimws(equivalences)), names(equivalences))
  bad <- equivalences[is.na(observation_species(equivalences))]
  if (length(bad)) {
    abort("{cli::qty(bad)}{?This name/These names} of {.arg equivalences} {?is/are} not bird species of Observation.org: {.val {bad}}.")
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
  obs_of <- tax$obs_name[match(sci, tax$birdnet_name)] %|NA|% sci
  k <- match(ioc_of, ioc$ioc_name)
  keys <- data.frame(sci = sci, a = normalize_name(sci), b = normalize_name(common),
                     c = normalize_name(ioc_of), d = normalize_name(ioc$english[k] %|NA|% ""),
                     e = normalize_name(ioc$spanish[k] %|NA|% ""), f = normalize_name(obs_of),
                     stringsAsFactors = FALSE)
  lapply(normalize_name(requested), function(r) {
    unique(keys$sci[keys$a == r | keys$b == r | keys$c == r | keys$d == r | keys$e == r | keys$f == r])
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
