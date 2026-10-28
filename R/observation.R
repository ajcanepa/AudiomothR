# Export of the detections in the import format of Observation.org.
#
#   - Exact columns, order and encoding of observations-import-example.xlsx
#     (Observation.org) and translation of BirdNET names (eBird/Clements) into
#     the names of Observation.org, through the IOC list (tables rebuilt in
#     data-raw/build_taxonomy.R from the species list of Observation.org).
#   - One record per species and day (local time), only with detections of
#     confidence >= 0.8 and at least 2 detections that day, unless the record
#     was validated by ear (create_validation()).
#   - CSV in UTF-8 without BOM, comma separated, dates YYYY-MM-DD, times HH:MM
#     and coordinates in decimal degrees with a decimal point.

# Exact columns of the Observation.org example, in their order
observation_columns <- c(
  "date", "time", "scientific name", "lat", "lng", "accuracy", "number", "notes",
  "sex", "is certain", "is escape", "activity", "life stage", "method",
  "counting method", "related species", "external reference", "obscurity", "embargo date"
)

#' Exports the detections in the format of Observation.org
#'
#' Groups the detections into one record per species and day. BirdNET names
#' are translated into the names of the bird species of Observation.org,
#' which follows the IOC World Bird List with its own lumps and genera (e.g.
#' *Corvus cornix* is exported as *Corvus corone*, with the BirdNET name in
#' the notes): every bird of BirdNET v2.4 has a valid name of Observation.org.
#' Classes that are not birds (noise, human voice, frogs, insects...) are left
#' out. Species that IOC has split are translated according to the location
#' when the rule is clear (e.g. *Cecropis daurica* is *Cecropis rufula* in
#' Europe) and are reported otherwise.
#'
#' **Validation.** When the records have been checked by ear with
#' [create_validation()], the decisions are applied: records marked as not
#' valid are left out, relabelled ones are exported under their new name, and
#' records marked as valid are exported even if they do not meet
#' `min_confidence` or `min_detections` (and, by default, with `is certain =
#' True`).
#'
#' **Hand-edited files.** If `AudioMoth_<ID>_observation.csv` has been edited
#' since it was exported, it is not overwritten (unless `overwrite = TRUE`):
#' the new export is saved with the date and time in its name. The criteria
#' used are saved next to it, in `AudioMoth_<ID>_observation.json`.
#'
#' @param am An `audiomoth` object with detections (see [analyze_birdnet()]).
#'   The location (`lat`, `lng`, `accuracy`) is that of `am`.
#' @param min_confidence Minimum confidence of the detections that count.
#' @param min_detections Minimum number of detections (events) of the
#'   species in the day.
#' @param no_doubts_only Count only the detections without another species in
#'   the same window.
#' @param species Only these species (scientific or common name of BirdNET,
#'   or name of Observation.org).
#' @param from,to Local dates (`"2026-10-07"` or `"07/10/2026"`) that limit
#'   the period.
#' @param validation Use the validation of [create_validation()]: `NULL`
#'   (default) when there is one, `TRUE` to require it, `FALSE` to ignore it.
#' @param validated_only Export only the records validated as correct.
#' @param method,counting_method,activity Fixed values of those columns,
#'   checked against the values that Observation.org accepts for birds (in
#'   Spanish, as in its import example).
#' @param is_certain `"auto"` (default: `"True"` for the records validated by
#'   ear and `"False"` for the rest, since the identification is automatic),
#'   `"True"` or `"False"`.
#' @param notes Text of the column `notes`. By default `"Identified with
#'   BirdNET <version>"` (`"ID mediante BirdNET <version>"` when `language`
#'   is Spanish), followed by the best detection of the record.
#' @param language Language of the default notes.
#' @param equivalences Named vector of own equivalences
#'   `c("BirdNET name" = "Observation.org name")`, which take priority. The
#'   names must be bird species of Observation.org (or their synonyms).
#' @param file Output CSV. By default `<output>/AudioMoth_<ID>_observation.csv`.
#' @param overwrite Overwrite the CSV even if it has been edited by hand.
#' @return Invisibly, the exported data frame (columns of Observation.org).
#' @examples
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#' am$detections <- read_detections(system.file("extdata", "example",
#'   "birdnet_detections.csv", package = "AudiomothR"))
#' obs <- export_observation(am, min_confidence = 0.5, min_detections = 1)
#' obs[, c("date", "time", "scientific name", "is certain")]
#' @export
export_observation <- function(am, min_confidence = 0.8, min_detections = 2, no_doubts_only = FALSE,
                               species = NULL, from = NULL, to = NULL, validation = NULL,
                               validated_only = FALSE, method = "O\u00eddo",
                               counting_method = "Sin especificar", activity = "",
                               is_certain = c("auto", "True", "False"), notes = NULL,
                               language = default_language(), equivalences = NULL,
                               file = NULL, overwrite = FALSE) {
  check_audiomoth(am)
  check_confidence(min_confidence, "min_confidence")
  check_number(min_detections, "min_detections", 1, integer = TRUE)
  check_flag(no_doubts_only, "no_doubts_only")
  check_flag(validated_only, "validated_only")
  check_flag(overwrite, "overwrite")
  if (!is.null(validation)) check_flag(validation, "validation")
  method <- check_observation_value("method", method)
  counting_method <- check_observation_value("counting method", counting_method)
  activity <- check_observation_value("activity", activity)
  is_certain <- check_choice(is_certain, c("auto", "True", "False"), "is_certain")
  equivalences <- check_equivalences(equivalences)
  from <- parse_date_arg(from, "from")
  to <- parse_date_arg(to, "to")

  d <- read_detections(am)
  d <- d[d$is_species, , drop = FALSE]
  u <- am$location
  moved <- nrow(d) && (any(abs(d$lat - u$lat) > 1e-6) || any(abs(d$lon - u$lon) > 1e-6))
  if (moved) inform("i" = "The current location of {.arg am} ({u$lat}, {u$lon}) is used, not the one of the analysis.")
  if (u$precision_m > 1000) {
    cli::cli_warn("The precision of the location (\u00b1{u$precision_m} m) is above 1000 m, the largest accuracy of Observation.org: 1000 is exported.")
  }

  # Validation decisions: invalid records out, relabelled ones renamed
  d$validated <- FALSE
  val <- if (isFALSE(validation)) NULL else read_validation(am, required = isTRUE(validation), quiet = TRUE)
  if (!is.null(val)) {
    d$record_id <- record_id(d$local_date, d$scientific_name)
    k <- match(d$record_id, val$record_id)
    decision <- val$decision[k]
    renamed <- !is.na(val$new_name[k])
    d$scientific_name[renamed] <- val$new_name[k][renamed]
    d$validated <- decision %in% "valid" | renamed
    d <- d[!decision %in% "invalid", , drop = FALSE]
    inform("i" = "Validation applied ({.file {attr(val, 'file')}}): {sum(val$decision == 'valid', na.rm = TRUE)} valid, {sum(val$decision == 'invalid', na.rm = TRUE)} not valid, {sum(!is.na(val$new_name))} relabelled.")
  }

  keep <- d$validated | (d$confidence >= min_confidence & (!no_doubts_only | d$no_doubts))
  if (validated_only) keep <- d$validated
  d <- d[keep, , drop = FALSE]
  if (!is.null(species)) {
    found <- match_species(species, d)
    warn_unknown_species(species[lengths(found) == 0], d)
    d <- d[d$scientific_name %in% unlist(found), , drop = FALSE]
  }
  if (!is.null(from)) d <- d[as.Date(d$local_date) >= from, , drop = FALSE]
  if (!is.null(to)) d <- d[as.Date(d$local_date) <= to, , drop = FALSE]

  tax <- ioc_names(unique(d$scientific_name), u$lat, u$lon, equivalences)
  report_taxonomy(tax)
  d$obs <- tax$obs[match(d$scientific_name, tax$birdnet)]
  d <- d[!is.na(d$obs), , drop = FALSE]

  d$instant <- as.POSIXct(d$recording_start_utc, tz = "UTC") + d$start_s
  groups <- split(d, list(d$obs, d$local_date), drop = TRUE)
  groups <- groups[vapply(groups, function(x) {
    any(x$validated) || length(unique(paste(x$file, x$event))) >= min_detections
  }, logical(1))]
  model <- unique(d$model)[1] %||% "BirdNET v2.4"
  spanish <- startsWith(language, "es")
  rows <- lapply(groups, function(x) {
    x <- x[order(x$instant), , drop = FALSE]
    best <- x[which.max(x$confidence), ]
    validated <- any(x$validated)
    note <- notes %||% paste0(
      if (spanish) "ID mediante " else "Identified with ", model,
      if (validated) (if (spanish) ", validado escuchando la grabaci\u00f3n" else ", checked by listening to the recording") else "",
      sprintf(if (spanish) " (mejor detecci\u00f3n: %s, %g s, confianza %.2f)" else " (best detection: %s, %g s, confidence %.2f)",
              best$file, best$start_s, best$confidence),
      # When Observation.org groups several BirdNET species, keep the original names
      if (any(unique(x$scientific_name) != x$obs[1])) paste0("; BirdNET: ", paste(unique(x$scientific_name), collapse = ", ")) else "")
    data.frame(
      date = x$local_date[1],
      time = format(x$instant[1], "%H:%M", tz = am$time_zone),
      scientific_name = x$obs[1],
      lat = round(u$lat, 6),
      lng = round(u$lon, 6),
      accuracy = min(1000L, max(1L, as.integer(u$precision_m))),
      number = 1L,
      notes = note,
      sex = NA_character_,
      is_certain = if (is_certain == "auto") (if (validated) "True" else "False") else is_certain,
      is_escape = "False",
      activity = if (nzchar(activity)) activity else NA_character_,
      life_stage = NA_character_,
      method = method,
      counting_method = counting_method,
      related_species = NA_character_,
      external_reference = sprintf("AudioMoth_%s_%s_%s", am$config$device_id,
                                   gsub("-", "", x$local_date[1]), safe_name(x$obs[1])),
      obscurity = NA_character_,
      embargo_date = NA_character_,
      stringsAsFactors = FALSE
    )
  })
  out <- if (length(rows)) do.call(rbind, rows) else
    as.data.frame(matrix(character(), ncol = length(observation_columns)))
  names(out) <- observation_columns
  if (nrow(out)) out <- out[order(out$date, out$time, out$`scientific name`), , drop = FALSE]
  rownames(out) <- NULL

  file <- file %||% output_file(am, "observation")
  file <- protect_edited(file, overwrite)
  write_csv(out, file)
  criteria <- list(file = basename(file), exported = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                   min_confidence = min_confidence, min_detections = min_detections,
                   no_doubts_only = no_doubts_only, validation = !is.null(val),
                   validated_records = sum(out$`is certain` == "True"), records = nrow(out),
                   md5 = unname(tools::md5sum(file)))
  writeLines(to_json(criteria), sub("\\.csv$", ".json", file))
  inform(c("v" = "{nrow(out)} record{?s} ({length(unique(out$`scientific name`))} species) for Observation.org in {.file {file}}.",
           "i" = "Criteria: confidence \u2265 {min_confidence}, \u2265 {min_detections} detection{?s} per species and day{if (no_doubts_only) ', only detections without doubts' else ''}{if (!is.null(val)) '; records validated by ear always included' else ''}."))
  invisible(out)
}

#' Does not overwrite an export that has been edited by hand
#' @noRd
protect_edited <- function(file, overwrite) {
  json <- sub("\\.csv$", ".json", file)
  if (overwrite || !file.exists(file) || !file.exists(json)) return(file)
  old <- tryCatch(from_json_md5(readLines(json, warn = FALSE)), error = function(e) NA)
  if (!is.na(old) && identical(old, unname(tools::md5sum(file)))) return(file)
  new <- sub("\\.csv$", format(Sys.time(), "_%Y%m%d_%H%M%S.csv"), file)
  cli::cli_warn(c("{.file {basename(file)}} has been edited since it was exported: it is kept, and the new export is saved as {.file {basename(new)}}.",
                  "i" = "Use {.code overwrite = TRUE} to replace it."))
  new
}

from_json_md5 <- function(lines) {
  m <- regmatches(paste(lines, collapse = ""), regexec("\"md5\"\\s*:\\s*\"([0-9a-f]+)\"", paste(lines, collapse = "")))[[1]]
  if (length(m)) m[2] else NA_character_
}

#' Messages about the names that do not reach Observation.org
#' @noRd
report_taxonomy <- function(tax) {
  not_bird <- tax$birdnet[tax$match == "not_bird"]
  if (length(not_bird)) inform("i" = "Left out because they are not birds: {.val {not_bird}}.")
  none <- tax$birdnet[tax$match == "none"]
  if (length(none)) {
    cli::cli_warn(c("{length(none)} name{?s} without a bird species in Observation.org {?is/are} left out: {.val {none}}.",
                    "i" = "Give its name in Observation.org with {.arg equivalences}, e.g. {.code equivalences = c(\"{none[1]}\" = \"Observation.org name\")}."))
  }
  noted <- tax[!is.na(tax$note), , drop = FALSE]
  if (nrow(noted)) {
    cli::cli_warn(c("Check these species, whose concept differs between BirdNET, IOC and Observation.org:",
                    stats::setNames(sprintf("%s \u2192 %s: %s", noted$birdnet, noted$obs, noted$note),
                                    rep("*", nrow(noted)))))
  }
}

#' A date given as "YYYY-MM-DD" or "DD/MM/YYYY"
#' @noRd
parse_date_arg <- function(x, name) {
  if (is.null(x)) return(NULL)
  if (inherits(x, "Date") && length(x) == 1) return(x)
  date <- if (is.character(x) && length(x) == 1) {
    tryCatch(as.Date(x, tryFormats = c("%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d")), error = function(e) NA)
  } else NA
  if (is.na(date)) abort("{.arg {name}} must be a date such as {.val 2026-10-07} or {.val 07/10/2026}.")
  date
}

#' Checks a fixed value against the ones Observation.org accepts for birds
#' @noRd
check_observation_value <- function(column, value) {
  if (is.null(value) || length(value) == 0 || is.na(value) || !nzchar(value)) return("")
  v <- read_csv(package_file("extdata", "observation_values.csv"))
  allowed <- v$value[v$column == column]
  hit <- allowed[tolower(allowed) == tolower(value)]
  if (length(hit) == 0) {
    abort("{.val {value}} is not a valid value of {.field {column}} in Observation.org.",
          "i" = "Allowed values: {.val {sort(allowed)}}.")
  }
  hit[1]
}

#' Minimal JSON encoder (lists of scalars and data frames of scalars)
#' @noRd
to_json <- function(x) {
  esc <- function(s) {
    s <- gsub("\\\\", "\\\\\\\\", s)
    s <- gsub("\"", "\\\\\"", s)
    s <- gsub("\n", "\\\\n", s)
    s <- gsub("\r", "\\\\r", s)
    s <- gsub("\t", "\\\\t", s)
    s <- gsub("</", "<\\\\/", s, fixed = TRUE)
    paste0("\"", s, "\"")
  }
  value <- function(v) {
    if (is.null(v) || length(v) == 0) return("null")
    if (is.data.frame(v)) return(to_json(v))
    if (is.list(v)) return(to_json(v))
    if (length(v) > 1) return(paste0("[", paste(vapply(v, value, ""), collapse = ","), "]"))
    if (is.na(v)) return("null")
    if (is.logical(v)) return(if (v) "true" else "false")
    if (is.numeric(v)) return(format(v, digits = 15, scientific = FALSE, trim = TRUE))
    esc(enc2utf8(as.character(v)))
  }
  if (is.data.frame(x)) {
    rows <- vapply(seq_len(nrow(x)), function(i) {
      paste0("{", paste(esc(names(x)), vapply(x, function(col) value(col[[i]]), ""), sep = ":", collapse = ","), "}")
    }, "")
    return(paste0("[", paste(rows, collapse = ",\n"), "]"))
  }
  if (is.list(x) && !is.null(names(x))) {
    return(paste0("{", paste(esc(names(x)), vapply(x, value, ""), sep = ":", collapse = ",\n"), "}"))
  }
  value(x)
}
