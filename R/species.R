# Summaries of the detections by species.

#' Summary of the detections by species
#'
#' Counts, for each species, the detections with a confidence of at least
#' `min_confidence`. Detections in overlapping windows of the same song (see
#' the `overlap` argument of [analyze_birdnet()]) count as one event.
#'
#' @param x An `audiomoth` object with detections, a list of them (several
#'   recorders) or a data frame from [read_detections()].
#' @param min_confidence Only detections with at least this confidence.
#' @param example_confidence,no_doubts Criteria of the examples (those of
#'   [select_examples()]), used to count the `example_candidates`.
#' @param species_only Leave out the BirdNET classes that are not species
#'   ("Engine", "Human vocal", "Dog"...).
#' @return A data frame with one row per species: `detections` (events),
#'   `days`, `recordings`, maximum and mean confidence, `location_prob`
#'   (lowest probability of occurrence at the site in the weeks with
#'   detections, from the BirdNET metadata model; `NA` when unknown) and
#'   `example_candidates` (recordings with a detection that meets the
#'   criteria of the examples).
#' @examples
#' d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
#'                                  package = "AudiomothR"))
#' species_summary(d, min_confidence = 0.5)
#' @export
species_summary <- function(x, min_confidence = 0.5, example_confidence = 0.85, no_doubts = TRUE,
                            species_only = TRUE) {
  check_confidence(min_confidence, "min_confidence")
  check_confidence(example_confidence, "example_confidence")
  check_flag(no_doubts, "no_doubts")
  d <- detections_of(x)
  d <- d[d$confidence >= min_confidence & (!species_only | d$is_species), , drop = FALSE]
  if (nrow(d) == 0) {
    return(data.frame(scientific_name = character(), common_name = character(), detections = integer(),
                      days = integer(), recordings = integer(), confidence_max = numeric(),
                      confidence_mean = numeric(), location_prob = numeric(),
                      example_candidates = integer()))
  }
  recording <- paste(d$device_id, d$day_folder, d$file)
  ok <- d$confidence >= example_confidence & (!no_doubts | d$no_doubts)
  by <- split(seq_len(nrow(d)), d$scientific_name)
  out <- do.call(rbind, lapply(by, function(i) data.frame(
    scientific_name = d$scientific_name[i[1]],
    common_name = d$common_name[i[1]],
    detections = length(unique(paste(recording[i], d$event[i]))),
    days = length(unique(d$local_date[i])),
    recordings = length(unique(recording[i])),
    confidence_max = max(d$confidence[i]),
    confidence_mean = round(mean(d$confidence[i]), 3),
    location_prob = suppressWarnings(min(d$location_prob[i], na.rm = TRUE)) %|Inf|% NA_real_,
    example_candidates = length(unique(recording[i][ok[i]])),
    stringsAsFactors = FALSE
  )))
  out <- out[order(-out$detections, -out$confidence_max), , drop = FALSE]
  rownames(out) <- NULL
  out
}

`%|Inf|%` <- function(x, y) if (is.infinite(x)) y else x

#' Detections of an object, a list of objects or a data frame
#' @noRd
detections_of <- function(x) {
  if (is.data.frame(x)) {
    if (is.null(x$is_species)) x$is_species <- !x$scientific_name %in% non_species
    if (is.null(x$event)) x$event <- seq_len(nrow(x))
    if (is.null(x$location_prob)) x$location_prob <- rep(NA_real_, nrow(x))
    x$no_doubts <- as.logical(x$no_doubts)
    return(x)
  }
  parts <- lapply(as_recorders(x), function(am) {
    d <- read_detections(am)
    d$event <- paste(am$config$device_id, d$event)
    d
  })
  do.call(rbind, parts)
}

#' Detected species, ready to choose examples
#'
#' Summarises the detected species (like [species_summary()]) and prints a
#' vector `c("scientific name" = n, ...)` ready to copy, change the `n` and
#' paste into [extract_examples()]. The proposed `n` is the number of examples
#' that meet the criteria of [select_examples()] (confidence of at least
#' `example_confidence`, no doubts and one per recording), at most `n_max`.
#' The same vector is returned (invisibly), so it can also be passed on
#' directly: `extract_examples(am, detected_species(am))`.
#'
#' With several recorders, `n` is the largest number of examples that one
#' recorder can give, since [extract_examples()] works recorder by recorder.
#'
#' BirdNET confidence is a score, not the probability that the identification
#' is right: it helps to sort the detections, but only listening to the
#' examples tells whether they are correct (see [create_validation()]).
#'
#' @param x An `audiomoth` object with detections, a list of them (several
#'   recorders) or a data frame from [read_detections()].
#' @inheritParams species_summary
#' @param n_max Largest number of examples proposed per species.
#' @param print Print the vector.
#' @return Invisibly, a named integer vector (species = number of examples)
#'   with the summary of [species_summary()] (plus the column `n_proposed`)
#'   as attribute `"summary"`.
#' @examples
#' d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
#'                                  package = "AudiomothR"))
#' species <- detected_species(d, example_confidence = 0.5)
#' attr(species, "summary")
#' @export
detected_species <- function(x, min_confidence = 0.5, example_confidence = 0.85, no_doubts = TRUE,
                             n_max = 3, print = TRUE) {
  check_number(n_max, "n_max", 0, integer = TRUE)
  several <- !is.data.frame(x) && !inherits(x, "audiomoth")
  r <- species_summary(x, min_confidence, example_confidence, no_doubts)
  if (nrow(r) == 0) {
    inform(c("!" = "No detection reaches a confidence of {min_confidence}."))
    return(invisible(structure(integer(), names = character(), summary = r)))
  }
  if (several) {
    # Largest number of candidates in a single recorder
    per <- lapply(as_recorders(x), function(am) species_summary(am, min_confidence, example_confidence, no_doubts))
    best <- do.call(rbind, per)
    best <- tapply(best$example_candidates, best$scientific_name, max)
    r$example_candidates <- as.integer(best[r$scientific_name])
  }
  r$n_proposed <- as.integer(pmin(n_max, r$example_candidates))
  species <- stats::setNames(r$n_proposed, r$scientific_name)

  if (print) {
    names_q <- formatC(sprintf("\"%s\"", r$scientific_name), width = -max(nchar(r$scientific_name) + 2))
    comma <- ifelse(seq_len(nrow(r)) < nrow(r), ",", " ")
    note <- sprintf("# %s | %d detection%s | confidence max. %.2f, mean %.2f", r$common_name,
                    r$detections, ifelse(r$detections == 1, "", "s"), r$confidence_max, r$confidence_mean)
    cat(sprintf("# Species with confidence >= %g. n = examples that meet the criteria\n", min_confidence),
        sprintf("# (confidence >= %g%s, one per recording), up to %d%s. Change the n and paste it\n",
                example_confidence, if (no_doubts) ", no doubts" else "", n_max,
                if (several) " per recorder" else ""),
        if (several) "# into extract_examples() for each recorder.\n" else "# into extract_examples(am, species).\n",
        "species <- c(\n",
        sprintf("  %s = %d%s  %s\n", names_q, r$n_proposed, comma, note),
        ")\n", sep = "")
    if (all(r$n_proposed == 0)) {
      inform(c("i" = "No species has examples that meet the criteria: lower {.arg example_confidence} (and use the same value as {.arg min_confidence} in {.fn extract_examples})."))
    }
  }
  invisible(structure(species, summary = r))
}

#' List of audiomoth objects (one recorder or several)
#' @noRd
as_recorders <- function(x) {
  if (inherits(x, "audiomoth")) x <- list(x)
  if (!is.list(x) || length(x) == 0 || !all(vapply(x, inherits, logical(1), "audiomoth"))) {
    abort("Give an {.cls audiomoth} object or a list of them (see {.fn read_audiomoth}).")
  }
  unname(x)
}
