# Validation by ear of the records before exporting them to Observation.org.
#
# create_validation() writes a self-contained HTML page (no R needed to use
# it, it can be sent to an expert) with one card per species and day, sorted
# from the least to the most plausible, with audio clips and spectrograms of
# the best detections. The decisions (valid, not valid, unsure, another
# species) are downloaded from the page as a CSV file that read_validation()
# and export_observation() apply.

#' Identifier of a record: date and species ("20261007_Cettia_cetti")
#' @noRd
record_id <- function(date, scientific_name) {
  paste(gsub("-", "", date), safe_name(scientific_name), sep = "_")
}

validation_file <- function(am) {
  file.path(am$output, "validation", sprintf("AudioMoth_%s_validation.csv", am$config$device_id))
}

validation_columns <- c("record_id", "date", "scientific_name", "common_name", "detections",
                        "confidence_max", "location_prob", "decision", "new_name", "comment",
                        "reviewed_at")

#' Creates a page to validate the records by ear
#'
#' BirdNET makes mistakes, above all with species that are rare at the site
#' or detected with low confidence. This function prepares a validation page
#' (`<output>/validation/AudioMoth_<ID>_validation.html`) to check the records
#' before exporting them to Observation.org:
#'
#' - one card per species and day (the unit of a record of Observation.org),
#'   sorted from the **least plausible** to the most plausible: the product
#'   of the highest confidence and the probability of occurrence of the
#'   species at the site and week (BirdNET metadata model, when known);
#' - for each card, `n_clips` audio clips of the best detections (from
#'   different recordings) with their spectrograms;
#' - buttons to mark the record as valid, not valid or unsure, a box to
#'   choose another species (with autocompletion among the BirdNET species)
#'   and a comment.
#'
#' The page works offline in any browser, without R (the `validation/` folder
#' can be sent to someone else). Decisions are kept in the browser while
#' working; the button **Download decisions (CSV)** saves them as
#' `AudioMoth_<ID>_validation.csv`. Then [export_observation()] applies them
#' automatically: it looks for that file in the validation folder and in the
#' Downloads folder (see [read_validation()]). A spreadsheet can also be used
#' instead of the page: fill in the columns `decision` (`valid`, `invalid` or
#' `unsure`) and `new_name` of the CSV file of the validation folder.
#'
#' Running the function again (e.g. after analysing more recordings) keeps
#' the decisions already saved in the validation folder.
#'
#' @param am An `audiomoth` object with detections (see [analyze_birdnet()]).
#' @param min_confidence Only detections with at least this confidence are
#'   grouped into records.
#' @param min_detections Minimum number of detections of the species in the
#'   day for the record to be validated.
#' @param n_clips Audio clips per record (the best detections, from different
#'   recordings).
#' @param margin_s Seconds of audio before and after each detection.
#' @param spectrograms Draw the spectrogram of each clip (slower).
#' @param open Open the page in the browser.
#' @return Invisibly, the path of the HTML page.
#' @examples
#' \donttest{
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#' am$detections <- read_detections(system.file("extdata", "example",
#'   "birdnet_detections.csv", package = "AudiomothR"))
#' page <- create_validation(am, open = FALSE)
#' }
#' @export
create_validation <- function(am, min_confidence = 0.5, min_detections = 1, n_clips = 2, margin_s = 1,
                              spectrograms = TRUE, open = interactive()) {
  check_audiomoth(am)
  check_confidence(min_confidence, "min_confidence")
  check_number(min_detections, "min_detections", 1, integer = TRUE)
  check_number(n_clips, "n_clips", 1, 10, integer = TRUE)
  check_number(margin_s, "margin_s", 0, 10)
  check_flag(spectrograms, "spectrograms")
  check_flag(open, "open")

  all <- read_detections(am)
  d <- all[all$is_species & all$confidence >= min_confidence, , drop = FALSE]
  if (nrow(d) == 0) abort("There are no detections with a confidence of at least {min_confidence} to validate.")
  d$record_id <- record_id(d$local_date, d$scientific_name)
  d$recording <- paste(d$day_folder, d$file)
  tax <- ioc_names(unique(d$scientific_name), am$location$lat, am$location$lon)

  groups <- split(d, d$record_id)
  records <- do.call(rbind, lapply(groups, function(x) data.frame(
    record_id = x$record_id[1], date = x$local_date[1], scientific_name = x$scientific_name[1],
    common_name = x$common_name[1], detections = length(unique(paste(x$recording, x$event))),
    recordings = length(unique(x$recording)), confidence_max = max(x$confidence),
    location_prob = suppressWarnings(min(x$location_prob, na.rm = TRUE)) %|Inf|% NA_real_,
    stringsAsFactors = FALSE)))
  records <- records[records$detections >= min_detections, , drop = FALSE]
  if (nrow(records) == 0) abort("No species has {min_detections} or more detections in a day.")
  records$note <- tax$note[match(records$scientific_name, tax$birdnet)]
  # Other species that BirdNET proposed in the same windows (any confidence)
  window_all <- paste(all$day_folder, all$file, all$start_s)
  records$doubts <- vapply(records$record_id, function(id) {
    x <- groups[[id]]
    o <- all[window_all %in% paste(x$day_folder, x$file, x$start_s) & all$is_species &
               all$scientific_name != x$scientific_name[1], , drop = FALSE]
    if (nrow(o) == 0) return(NA_character_)
    best <- tapply(o$confidence, o$common_name, max)
    best <- sort(best, decreasing = TRUE)
    paste(sprintf("%s (%.2f)", names(best), best), collapse = ", ")
  }, character(1))
  plausibility <- records$confidence_max * (records$location_prob %|NA|% 1)
  records <- records[order(plausibility, records$detections, records$confidence_max), , drop = FALSE]
  rownames(records) <- NULL

  # Decisions already taken are kept
  old <- read_validation(am, quiet = TRUE)
  for (col in c("decision", "new_name", "comment", "reviewed_at")) {
    records[[col]] <- if (is.null(old)) NA_character_ else old[[col]][match(records$record_id, old$record_id)]
  }

  folder <- file.path(am$output, "validation")
  clips_dir <- file.path(folder, "clips")
  dir.create(clips_dir, recursive = TRUE, showWarnings = FALSE)
  has_ffmpeg <- !inherits(try(ffmpeg_path(), silent = TRUE), "try-error")
  clips <- list()
  bar <- cli::cli_progress_bar(name = "Preparing the audio clips", total = nrow(records))
  for (i in seq_len(nrow(records))) {
    x <- groups[[records$record_id[i]]]
    x <- x[order(-x$confidence), , drop = FALSE]
    best <- utils::head(x[!duplicated(x$recording), , drop = FALSE], n_clips)
    for (k in seq_len(nrow(best))) {
      b <- best[k, ]
      base <- sprintf("%s_%d", b$record_id, k)
      res <- tryCatch(make_clip(am, b, file.path(clips_dir, base), margin_s, spectrograms, has_ffmpeg),
                      error = function(e) {
                        cli::cli_warn("Clip {base}: {cli_escape(conditionMessage(e))}")
                        NULL
                      })
      if (is.null(res)) next
      clips[[length(clips) + 1]] <- data.frame(
        record_id = b$record_id, audio = file.path("clips", basename(res$audio)),
        image = if (is.na(res$image)) NA_character_ else file.path("clips", basename(res$image)),
        file = b$file, start_s = b$start_s, time = paste(b$local_date, b$local_time),
        confidence = b$confidence, stringsAsFactors = FALSE)
    }
    cli::cli_progress_update(id = bar)
  }
  cli::cli_progress_done(id = bar)
  clips <- do.call(rbind, clips) %||% data.frame(record_id = character())

  write_csv(records[, validation_columns], validation_file(am))
  html <- file.path(folder, sprintf("AudioMoth_%s_validation.html", am$config$device_id))
  dates <- sort(unique(records$date))
  data <- list(device_id = am$config$device_id, site = am$site,
               period = if (length(dates) > 1) paste(dates[1], "to", dates[length(dates)]) else dates,
               created = format(Sys.time(), "%Y-%m-%d %H:%M"), min_confidence = min_confidence,
               records = records, clips = clips, species = species_choices(d))
  template <- readLines(package_file("validation", "validation.html"), encoding = "UTF-8", warn = FALSE)
  parts <- strsplit(paste(template, collapse = "\n"), "__AUDIOMOTHR_DATA__", fixed = TRUE)[[1]]
  con <- file(html, open = "w", encoding = "UTF-8")
  writeLines(paste0(parts[1], to_json(data), parts[2]), con)
  close(con)

  inform(c("v" = "Validation page with {nrow(records)} record{?s} in {.file {html}}.",
           "i" = "Listen and decide, press {.strong Download decisions (CSV)} and run {.code export_observation(am)}: the decisions are applied automatically."))
  if (open) tryCatch(utils::browseURL(html), error = function(e) inform("!" = "Cannot open the browser: {cli_escape(conditionMessage(e))}"))
  invisible(html)
}

#' Audio clip (and spectrogram) of a detection for the validation page
#' @noRd
make_clip <- function(am, b, base, margin_s, spectrogram, has_ffmpeg) {
  path <- audio_source(am, b)
  header <- read_wav_header(path)
  if (is.null(header)) abort("Cannot read {.file {path}}.")
  from <- max(0, b$start_s - margin_s)
  to <- min(header$duration_s, b$end_s + margin_s)
  if (has_ffmpeg) {
    # Compressed audio (AAC) keeps the validation folder small enough to share
    audio <- paste0(base, ".m4a")
    run_ffmpeg(c("-ss", format(from, nsmall = 3), "-t", format(to - from, nsmall = 3), "-i", path,
                 "-ac", "1", "-ar", min(48000L, header$sample_rate), "-c:a", "aac", "-b:a", "128k", audio))
  } else {
    audio <- paste0(base, ".wav")
    tuneR::writeWave(cut_audio(path, from, to)$wave, audio)
  }
  image <- NA_character_
  if (spectrogram) {
    wav <- tempfile(fileext = ".wav")
    on.exit(unlink(wav))
    clip <- cut_audio(path, from, to)
    tuneR::writeWave(clip$wave, wav)
    image <- paste0(base, ".png")
    spectrogram_image(wav, image, title = sprintf("%s \u00b7 %.2f", b$common_name, b$confidence),
                      subtitle = sprintf("%s %s \u00b7 %s, %g-%g s", b$local_date, b$local_time, b$file,
                                         b$start_s, b$end_s),
                      marks = c(b$start_s, b$end_s) - clip$from, width = 960, height = 420)
  }
  list(audio = audio, image = image)
}

#' Audio to cut a detection from: the original recording, or its expanded
#' copy for triggered recordings (the times of BirdNET refer to it)
#' @noRd
audio_source <- function(am, b) {
  g <- set_birdnet_paths(am)$recordings
  k <- match(paste(b$day_folder %|NA|% "", b$file), paste(g$day_folder, g$file))
  if (is.na(k)) return(b$path)
  if (isTRUE(g$triggered[k])) {
    if (!converted_ok(g, k)) convert_recording(g$path[k], g$birdnet_path[k], TRUE)
    return(g$birdnet_path[k])
  }
  g$path[k]
}

#' Species offered when relabelling: the detected ones first, then all the
#' BirdNET birds
#' @noRd
species_choices <- function(d) {
  tax <- taxonomy_table()
  tax <- tax[tax$match != "not_bird", , drop = FALSE]
  detected <- unique(d[, c("scientific_name", "common_name")])
  all <- data.frame(scientific = c(detected$scientific_name, tax$birdnet_name),
                    common = c(detected$common_name, tax$birdnet_english), stringsAsFactors = FALSE)
  all[!duplicated(all$scientific), , drop = FALSE]
}

#' Reads the decisions of the validation by ear
#'
#' Looks for the decisions of [create_validation()]: the file given in
#' `file` or, otherwise, the most recent `AudioMoth_<ID>_validation.csv` with
#' some decision, either in the validation folder of the results or in the
#' Downloads folder (where the browser saves it; set another one with
#' `options(AudiomothR.downloads = "/path")`). A file found in Downloads is
#' copied into the validation folder, so that it stays with the results.
#'
#' @param am An `audiomoth` object.
#' @param file CSV file with the decisions (optional).
#' @param required Error when there are no decisions.
#' @param quiet Do not report which file is used.
#' @return A data frame with one row per record (`record_id`, `date`,
#'   `scientific_name`, `decision`: `"valid"`, `"invalid"`, `"unsure"` or
#'   `NA`, `new_name`, `comment`...), or `NULL` when there is no validation.
#' @examples
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#' read_validation(am)   # NULL: nothing validated yet
#' @export
read_validation <- function(am, file = NULL, required = FALSE, quiet = FALSE) {
  check_audiomoth(am)
  own <- validation_file(am)
  if (is.null(file)) {
    pattern <- sprintf("^AudioMoth_%s_validation.*\\.csv$", am$config$device_id)
    candidates <- c(own, list.files(downloads_folder(), pattern = pattern, full.names = TRUE))
    candidates <- candidates[file.exists(candidates)]
    decided <- vapply(candidates, function(f) {
      x <- tryCatch(read_csv(f), error = function(e) NULL)
      if (is.null(x) || is.null(x$decision)) return(FALSE)
      any(nzchar(x$decision %|NA|% "")) || any(nzchar(x$new_name %|NA|% ""))
    }, logical(1))
    candidates <- candidates[decided]
    if (length(candidates) == 0) {
      if (required) abort("There is no validation for AudioMoth {am$config$device_id}.",
                          "i" = "Create it with {.fn create_validation} and download the decisions from the page.")
      return(NULL)
    }
    file <- candidates[which.max(file.mtime(candidates))]
  } else if (!file.exists(file)) {
    abort("File {.file {file}} does not exist.")
  }
  v <- read_csv(file)
  missing <- setdiff(c("record_id", "decision"), names(v))
  if (length(missing)) abort("{.file {file}} is not a validation file (it has no column{?s} {.field {missing}}).")
  for (col in c("new_name", "comment", "reviewed_at")) if (is.null(v[[col]])) v[[col]] <- NA_character_

  v$decision <- tolower(trimws(v$decision))
  v$decision[!nzchar(v$decision %|NA|% "")] <- NA_character_
  bad <- !is.na(v$decision) & !v$decision %in% c("valid", "invalid", "unsure")
  if (any(bad)) {
    cli::cli_warn("Unknown decisions are ignored: {.val {unique(v$decision[bad])}} (use {.val valid}, {.val invalid} or {.val unsure}).")
    v$decision[bad] <- NA_character_
  }
  v$new_name <- trimws(sub("\\s+\u2014.*$", "", v$new_name))
  v$new_name[!nzchar(v$new_name %|NA|% "")] <- NA_character_
  known <- c(taxonomy_table()$birdnet_name, ioc_table()$ioc_name, observation_table()$scientific_name)
  unknown <- !is.na(v$new_name) & !v$new_name %in% known
  if (any(unknown)) {
    cli::cli_warn("These new names are not BirdNET or IOC species and are ignored: {.val {unique(v$new_name[unknown])}}.")
    v$new_name[unknown] <- NA_character_
  }
  if (normalizePath(file, mustWork = FALSE) != normalizePath(own, mustWork = FALSE)) {
    dir.create(dirname(own), recursive = TRUE, showWarnings = FALSE)
    file.copy(file, own, overwrite = TRUE)
    if (!quiet) inform("i" = "Decisions read from {.file {file}} and copied to {.file {own}}.")
  } else if (!quiet) {
    inform("i" = "Decisions read from {.file {file}}.")
  }
  attr(v, "file") <- own
  v
}

#' Folder where the browser saves downloads
#' @noRd
downloads_folder <- function() {
  option <- getOption("AudiomothR.downloads")
  if (!is.null(option)) return(path.expand(option))
  home <- if (.Platform$OS.type == "windows") Sys.getenv("USERPROFILE", path.expand("~")) else path.expand("~")
  file.path(home, "Downloads")
}
