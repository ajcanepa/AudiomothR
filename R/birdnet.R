# Preparing the audio and analysing it with BirdNET (birdnetR package).
#
# birdnetR installs the Python side of BirdNET (with uv) the first time it is
# used, and downloads the model (~77 MB). Licence of the models: CC BY-NC-SA
# 4.0 (non-commercial use only).
#
# Each recording is analysed only once: its result is cached in
#   <output>/birdnet/<device>_<key>/<day>/<file>.csv
# where <key> identifies the analysis parameters. An interrupted analysis
# continues where it stopped, and changing a parameter starts a new cache
# next to the old one instead of deleting it.

birdnet_rate <- 48000L

# BirdNET v2.4 classes that are not species
non_species <- c("Dog", "Engine", "Environmental", "Fireworks", "Gun", "Human non-vocal",
                 "Human vocal", "Human whistle", "Noise", "Power tools", "Siren")

# Lowest confidence kept in the cache: detections of low confidence are needed
# to know whether BirdNET hesitated between several species in a window
doubt_threshold <- 0.1

# --- birdnetR backend (replaced by mock functions in the tests) -------------

bn_load_model <- function(version, language, threads) {
  birdnetR::birdnet_model_tflite(version = version, language = language,
                                 tflite_num_threads = as.integer(threads))
}

bn_load_meta <- function(version, language) {
  birdnetR::birdnet_model_meta(version = version, language = language)
}

bn_location_scores <- function(meta, lat, lon, week, min_confidence) {
  birdnetR::predict_species_at_location_and_time(meta, lat, lon, week = week,
                                                 min_confidence = min_confidence)
}

bn_predict <- function(model, path, min_confidence, overlap, sensitivity, filter) {
  birdnetR::predict_species_from_audio_file(
    model, path, min_confidence = min_confidence, chunk_overlap_s = overlap,
    sigmoid_sensitivity = sensitivity, filter_species = filter, keep_empty = FALSE)
}

bn_labels <- function(model, language) {
  lines <- readLines(birdnetR::labels_path(model, language), encoding = "UTF-8", warn = FALSE)
  lines <- lines[nzchar(lines)]
  data.frame(label = lines, scientific_name = sub("_.*$", "", lines),
             common_name = sub("^[^_]*_", "", lines), stringsAsFactors = FALSE)
}

# --- Preparing the audio -------------------------------------------------------

#' Prepares the audio for BirdNET
#'
#' BirdNET works with mono audio at 48 kHz. Recordings that already are so
#' are used as they are; the others (e.g. AudioMoth at 250 kHz or stereo) are
#' converted with ffmpeg into `<output>/audio_48k/`. Triggered recordings
#' (`*T.WAV`) are expanded first, restoring their silences, so that the times
#' of the detections are right. Recordings that are not valid (column
#' `problem`) are left out.
#'
#' This step is optional: [analyze_birdnet()] converts by itself, just before
#' analysing them, the recordings that still need it (and only those without
#' a result yet, so the converted copies can be deleted once the analysis is
#' finished).
#'
#' @param am Object created with [read_audiomoth()].
#' @return `am` with the column `birdnet_path` (audio read by BirdNET) in
#'   `am$recordings`.
#' @examples
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#' am <- prepare_audio(am)   # 48 kHz mono already: nothing to convert
#' @export
prepare_audio <- function(am) {
  check_audiomoth(am)
  am <- set_birdnet_paths(am)
  g <- am$recordings
  todo <- which(g$valid & g$birdnet_path != g$path)
  pending <- todo[!converted_ok(g, todo)]
  if (length(todo)) {
    inform("Converting {length(todo)} recording{?s} to 48 kHz mono ({length(pending)} pending).")
    bar <- cli::cli_progress_bar(name = "Converting audio", total = length(pending))
    for (k in pending) {
      convert_recording(g$path[k], g$birdnet_path[k], g$triggered[k])
      cli::cli_progress_update(id = bar)
    }
    cli::cli_progress_done(id = bar)
  } else {
    inform(c("v" = "All valid recordings are already 48 kHz mono: nothing to convert."))
  }
  if (any(!g$valid)) {
    inform(c("!" = "{sum(!g$valid)} recording{?s} with problems {?is/are} left out (see column {.field problem})."))
  }
  am
}

#' Path of the audio that BirdNET reads for each valid recording
#' @noRd
set_birdnet_paths <- function(am) {
  g <- am$recordings
  convert <- g$valid & (g$sample_rate != birdnet_rate | g$channels != 1 | g$triggered)
  dest <- file.path(am$output, "audio_48k", am$config$device_id, g$day_folder, g$file)
  g$birdnet_path <- ifelse(!g$valid, NA_character_, ifelse(convert, dest, g$path))
  # Recordings of cards that are no longer connected cannot be read (their
  # results stay in the cache)
  g$birdnet_path[g$valid & !file.exists(g$path) & !(convert & file.exists(dest))] <- NA_character_
  am$recordings <- g
  am
}

#' TRUE for converted copies that exist and are complete (the duration of the
#' copy matches the original)
#' @noRd
converted_ok <- function(g, k) {
  vapply(k, function(i) {
    if (!file.exists(g$birdnet_path[i])) return(FALSE)
    h <- tryCatch(read_wav_header(g$birdnet_path[i]), error = function(e) NULL)
    !is.null(h) && !h$incomplete_header && abs(h$duration_s - g$duration_s[i]) < 0.1
  }, logical(1))
}

#' Converts a recording to 48 kHz mono (expanding it first if triggered)
#'
#' The copy is written under a temporary name and renamed at the end, so that
#' an interruption never leaves a truncated file that would look converted.
#' @noRd
convert_recording <- function(src, dest, triggered = FALSE) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".part.wav")
  on.exit(unlink(tmp), add = TRUE)
  if (triggered) {
    expanded <- paste0(dest, ".expanded.wav")
    on.exit(unlink(expanded), add = TRUE)
    expand_triggered_wav(src, expanded)
    src <- expanded
  }
  run_ffmpeg(c("-i", src, "-ac", "1", "-ar", birdnet_rate, "-c:a", "pcm_s16le", tmp))
  if (!file.rename(tmp, dest)) abort("Cannot write {.file {dest}}.")
  invisible(dest)
}

# --- Analysis --------------------------------------------------------------------

#' Analyses the recordings with BirdNET
#'
#' Uses the BirdNET v2.4 model through the birdnetR package. With
#' `location_filter`, only the species expected at the location of the
#' recorder in the week of each recording are considered (BirdNET metadata
#' model); without it, BirdNET often proposes species from other continents.
#'
#' **Cache.** Recordings already analysed with the same parameters are not
#' analysed again: an interrupted analysis continues where it stopped. The
#' cache is in `<output>/birdnet/`, in one folder per combination of
#' parameters, so going back to earlier parameters reuses their results.
#' Changing `min_confidence` (above 0.1) or `language` does not require a new
#' analysis.
#'
#' **Doubts.** BirdNET analyses the audio in 3 s windows. A detection has
#' "no doubts" (`no_doubts = TRUE`) when BirdNET proposed no other species in
#' the same window with a confidence of at least 0.1 (only species that pass
#' the location filter count; classes such as "Engine" or "Human vocal" do
#' not).
#'
#' **Overlap.** With `overlap > 0` consecutive windows overlap and the same
#' song is detected in several of them. The column `event` groups the
#' overlapping windows of the same species, and the counts of
#' [species_summary()] and [export_observation()] use events, not windows.
#'
#' At the end, `AudioMoth_<ID>_detections.csv` is saved (see
#' [read_detections()]) and `am$recordings` gains the column `analysis`
#' ("ok", "error: ..." or `NA` for recordings that are not valid).
#'
#' @param am Object created with [read_audiomoth()].
#' @param min_confidence Minimum confidence (0-1) of the detections that are
#'   kept. Values below 0.1 make the cache keep more detections (a new
#'   analysis).
#' @param language Language of the common names. By default, the language of
#'   the operating system (see [check_requirements()]); codes such as `"es"`,
#'   `"en_us"`, `"en_uk"`, `"fr"`, `"de"`, `"pt"`... Polish (`"pl"`) is not
#'   accepted: its label file in BirdNET v2.4 is wrong.
#' @param version Version of the BirdNET model (see
#'   [birdnetR::birdnet_model_tflite()]). It is stored in the column `model`
#'   and quoted by [export_observation()] in the notes.
#' @param location_filter Filter the species by location and week.
#' @param location_threshold Minimum probability of occurrence (metadata
#'   model) for a species to pass the filter.
#' @param overlap Overlap between 3 s windows (seconds, 0 to 2.9).
#' @param sensitivity BirdNET sensitivity (0.5 to 1.5).
#' @param threads Computing threads (by default, all but one).
#' @param reanalyze Analyse every recording again with these parameters.
#' @param stop_on_error Stop with an error when BirdNET cannot analyse some
#'   recording (useful in scripts run with `Rscript`); by default it only
#'   warns, and the recordings are listed in the column `analysis`.
#' @return `am` with `am$detections` (data frame).
#' @examples
#' \dontrun{
#' # The first time it installs Python and downloads the model (a few minutes)
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#' am <- analyze_birdnet(am)
#' }
#' @export
analyze_birdnet <- function(am, min_confidence = 0.1, language = default_language(), version = "v2.4",
                            location_filter = TRUE, location_threshold = 0.03, overlap = 0,
                            sensitivity = 1, threads = NULL, reanalyze = FALSE,
                            stop_on_error = FALSE) {
  # Every argument is checked before anything is loaded or written
  check_audiomoth(am)
  check_confidence(min_confidence, "min_confidence")
  if (min_confidence >= 1) abort("{.arg min_confidence} must be lower than 1.")
  language <- check_language(language)
  if (!is.character(version) || length(version) != 1) abort("{.arg version} must be a text such as {.val v2.4}.")
  check_flag(location_filter, "location_filter")
  check_number(location_threshold, "location_threshold", 0, 0.99)
  check_number(overlap, "overlap", 0, 2.9)
  check_number(sensitivity, "sensitivity", 0.5, 1.5)
  if (!is.null(threads)) check_number(threads, "threads", 1, integer = TRUE)
  check_flag(reanalyze, "reanalyze")
  check_flag(stop_on_error, "stop_on_error")
  threads <- threads %||% max(1L, parallel_cores() - 1L)

  am <- set_birdnet_paths(am)
  g <- am$recordings
  valid <- which(g$valid)
  if (length(valid) == 0) abort("There are no valid recordings to analyse.")

  cache_threshold <- min(min_confidence, doubt_threshold)
  params <- list(version = version, cache_threshold = round(cache_threshold, 4),
                 location_filter = location_filter,
                 location_threshold = if (location_filter) round(location_threshold, 4),
                 overlap = round(overlap, 3), sensitivity = round(sensitivity, 3))
  cache <- cache_folder(am, params)
  if (reanalyze) unlink(cache, recursive = TRUE)
  older <- setdiff(list.dirs(file.path(am$output, "birdnet"), recursive = FALSE), cache)
  older <- older[startsWith(basename(older), paste0(am$config$device_id, "_"))]
  if (length(older) && !dir.exists(cache)) {
    inform("i" = "The parameters differ from the previous analysis: the recordings are analysed with the new ones (the previous results are kept in {.file {older[1]}}).")
  }

  # Each deployment has its own location: the results are kept by place, so
  # that a new location only analyses its own recordings again
  place <- location_tag(g)
  result <- result_file(cache, g, if (location_filter) place else rep("all", nrow(g)))
  cached <- valid[file.exists(result[valid])]
  bad <- cached[!vapply(result[cached], cache_readable, logical(1))]
  if (length(bad)) {
    cli::cli_warn("{length(bad)} incomplete result{?s} {?is/are} analysed again (e.g. {.file {result[bad[1]]}}).")
    unlink(result[bad])
  }
  pending <- valid[!file.exists(result[valid])]
  unavailable <- pending[is.na(g$birdnet_path[pending])]
  pending <- setdiff(pending, unavailable)
  inform("BirdNET: {length(valid)} recording{?s}; {length(pending)} pending.")
  if (length(unavailable)) {
    cli::cli_warn("{length(unavailable)} recording{?s} without results cannot be analysed because {?its/their} card is not connected (deployment{?s} {.val {unique(g$deployment[unavailable])}}).")
  }

  labels <- cached_labels(am, version, language)
  scores_file <- file.path(cache, "location_scores.csv")
  errors <- character()
  if (length(pending) || is.null(labels)) {
    # Quiet TensorFlow and the progress bars of Python (one per recording);
    # must be set before birdnetR starts Python
    if (!nzchar(Sys.getenv("TF_CPP_MIN_LOG_LEVEL"))) Sys.setenv(TF_CPP_MIN_LOG_LEVEL = "3")
    if (!nzchar(Sys.getenv("TQDM_DISABLE"))) Sys.setenv(TQDM_DISABLE = "1")
    bn_prepare(version)
    inform("Loading the BirdNET model...")
    model <- quiet_python(bn_load_model(version, language, threads))
    labels <- bn_labels(model, language)
    if (anyDuplicated(labels$scientific_name)) {
      abort("The {.val {language}} labels of BirdNET {version} have duplicated species: use another {.arg language}.")
    }
    write_csv(labels[, c("scientific_name", "common_name")], labels_file(am, version, language))
  }

  if (length(pending)) {
    dir.create(cache, recursive = TRUE, showWarnings = FALSE)
    saveRDS(params, file.path(cache, "parameters.rds"))
    write_metadata(cache, params, language)

    # Probability of occurrence of each species at the site and week: used as
    # filter and, for every detection, to tell the unusual ones (validation)
    # (for each place and week)
    needed <- unique(data.frame(place = place[valid], lat = g$lat[valid], lon = g$lon[valid],
                                week = birdnet_week(g$local_date[valid])))
    needed <- needed[!is.na(needed$week), , drop = FALSE]
    scores <- if (file.exists(scores_file)) read_csv(scores_file) else NULL
    missing <- needed[!paste(needed$place, needed$week) %in% paste(scores$place, scores$week), , drop = FALSE]
    if (nrow(missing)) {
      meta <- quiet_python(bn_load_meta(version, language))
      new <- do.call(rbind, lapply(seq_len(nrow(missing)), function(i) {
        s <- bn_location_scores(meta, missing$lat[i], missing$lon[i], missing$week[i], 0.001)
        if (nrow(s) == 0) return(NULL)
        data.frame(place = missing$place[i], week = missing$week[i], label = s$label,
                   scientific_name = sub("_.*$", "", s$label),
                   probability = round(s$confidence, 4), stringsAsFactors = FALSE)
      }))
      scores <- rbind(scores, new)
      write_csv(scores, scores_file)
    }
    filters <- NULL
    if (location_filter) {
      keys <- unique(paste(place[pending], birdnet_week(g$local_date[pending])))
      filters <- lapply(keys, function(k) scores$label[paste(scores$place, scores$week) == k &
                                                         scores$probability >= location_threshold])
      names(filters) <- keys
      empty <- names(filters)[lengths(filters) == 0]
      if (length(empty)) {
        abort("The location filter leaves no species in {length(empty)} place{?s} and week{?s} with a location threshold of {location_threshold}.",
              "i" = "Lower {.arg location_threshold} or use {.code location_filter = FALSE}.")
      }
      inform("Location filter: {round(mean(lengths(filters)))} expected species per site and week on average.")
    }

    bar <- cli::cli_progress_bar(name = "Analysing with BirdNET", total = length(pending))
    for (k in pending) {
      res <- tryCatch({
        if (g$birdnet_path[k] != g$path[k] && !converted_ok(g, k)) {
          convert_recording(g$path[k], g$birdnet_path[k], g$triggered[k])
        }
        filter <- if (location_filter) filters[[paste(place[k], birdnet_week(g$local_date[k]))]]
        pred <- quiet_python(bn_predict(model, g$birdnet_path[k], cache_threshold, overlap,
                                        sensitivity, filter))
        if (is.null(pred) || nrow(pred) == 0) {
          pred <- data.frame(start = numeric(), end = numeric(), scientific_name = character(),
                             confidence = numeric())
        }
        write_csv(pred[, c("start", "end", "scientific_name", "confidence")], result[k])
        NULL
      }, error = function(e) conditionMessage(e))
      if (!is.null(res)) errors[g$file[k]] <- gsub("\\s+", " ", res)
      cli::cli_progress_update(id = bar)
    }
    cli::cli_progress_done(id = bar)
    if (length(errors)) {
      write_csv(data.frame(file = names(errors), error = unname(errors)), file.path(cache, "errors.csv"))
      if (length(errors) == length(pending)) {
        abort("BirdNET could not analyse any recording; the previous results have not been changed.",
              stats::setNames(cli_escape(utils::head(paste(names(errors), errors, sep = ": "), 5)), rep("x", min(5, length(errors)))))
      }
    }
  }

  scores <- if (file.exists(scores_file)) read_csv(scores_file) else NULL
  am$detections <- combine_detections(am, g, result, labels, scores, params, min_confidence)
  g$analysis <- ifelse(!g$valid, NA_character_, ifelse(file.exists(result), "ok", "pending"))
  g$analysis[unavailable] <- "card not connected"
  if (length(errors)) {
    k <- match(names(errors), g$file)
    g$analysis[k] <- paste("error:", errors)
  }
  am$recordings <- g
  am$analysis <- list(parameters = params, language = language, cache = cache,
                      min_confidence = min_confidence)
  write_csv(g, output_file(am, "recordings"))
  file <- output_file(am, "detections")
  write_csv(am$detections, file)
  n_species <- length(unique(am$detections$scientific_name[am$detections$is_species]))
  inform(c("v" = "{nrow(am$detections)} detection{?s} of {n_species} species saved in {.file {file}}."))
  if (length(errors)) {
    msg <- c("BirdNET could not analyse {length(errors)} recording{?s} (see the column {.field analysis} and {.file {file.path(cache, 'errors.csv')}}):",
             stats::setNames(cli_escape(utils::head(paste(names(errors), errors, sep = ": "), 5)), rep("x", min(5, length(errors)))))
    if (stop_on_error) abort(msg) else cli::cli_warn(msg)
  }
  am
}

#' Checks the language of the common names
#' @noRd
check_language <- function(language) {
  if (!is.character(language) || length(language) != 1 || is.na(language)) {
    abort("{.arg language} must be a language code such as {.val es} or {.val en_us}.")
  }
  if (language == "pl") {
    abort("The Polish labels of BirdNET v2.4 are wrong (a repeated species shifts the names of more than 3,000 species).",
          "i" = "Use another {.arg language}, e.g. {.val en_us}.")
  }
  if (language == "en") language <- "en_us"
  if (!language %in% birdnet_languages) {
    abort("Unknown {.arg language}: {.val {language}}.", "i" = "Use one of {.val {birdnet_languages}}.")
  }
  language
}

#' Folder of the cache for a set of parameters: <device>_<8 characters>
#' @noRd
cache_folder <- function(am, params) {
  tmp <- tempfile()
  on.exit(unlink(tmp))
  writeLines(paste(deparse(params), collapse = ""), tmp)
  key <- substr(unname(tools::md5sum(tmp)), 1, 8)
  file.path(am$output, "birdnet", paste0(am$config$device_id, "_", key))
}

result_file <- function(cache, g, place) {
  file.path(cache, place, ifelse(nzchar(g$day_folder %|NA|% ""), g$day_folder, "root"),
            sub("\\.wav$", ".csv", g$file, ignore.case = TRUE))
}

#' Place of each recording ("<lat>_<lon>"), the location of its deployment
#' @noRd
location_tag <- function(g) sprintf("%.4f_%.4f", g$lat, g$lon)

#' TRUE when a cached result can be read and has its header
#' @noRd
cache_readable <- function(file) {
  x <- tryCatch(utils::read.csv(file, nrows = 1), error = function(e) NULL)
  !is.null(x) && all(c("start", "end", "scientific_name", "confidence") %in% names(x))
}

labels_file <- function(am, version, language) {
  file.path(am$output, "birdnet", sprintf("labels_%s_%s.csv", version, language))
}

cached_labels <- function(am, version, language) {
  f <- labels_file(am, version, language)
  if (file.exists(f)) tryCatch(read_csv(f), error = function(e) NULL) else NULL
}

#' Software versions and date of the analysis (reproducibility)
#' @noRd
write_metadata <- function(cache, params, language) {
  python <- if (reticulate::py_available(initialize = FALSE)) {
    tryCatch(reticulate::py_eval("__import__('importlib.metadata').metadata.version('birdnet')"),
             error = function(e) NA_character_)
  } else NA_character_
  meta <- c(params, language = language,
            audiomothr = as.character(utils::packageVersion("AudiomothR")),
            birdnetr = tryCatch(as.character(utils::packageVersion("birdnetR")), error = function(e) NA),
            birdnet_python = python, r = R.version.string,
            date = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))
  meta <- meta[!vapply(meta, is.null, logical(1))]
  write.dcf(as.data.frame(lapply(meta, as.character), check.names = FALSE), file.path(cache, "metadata.txt"))
}

#' Joins the results of all the recordings into a table of detections
#'
#' Adds the local date and time of the start of each detection, the
#' indicators of doubt (how many species BirdNET proposed in the same window
#' and the highest confidence of the others), the events of overlapping
#' windows and the probability of occurrence of the species at the site.
#' @noRd
combine_detections <- function(am, g, result, labels, scores, params, min_confidence) {
  done <- which(g$valid & file.exists(result))
  parts <- lapply(done, function(k) {
    d <- tryCatch(utils::read.csv(result[k], stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(d) || nrow(d) == 0) return(NULL)
    d$recording_id <- g$id[k]
    d[, c("recording_id", "start", "end", "scientific_name", "confidence")]
  })
  d <- do.call(rbind, parts)
  if (is.null(d) || nrow(d) == 0) return(empty_detections())

  d$is_species <- !d$scientific_name %in% non_species
  window <- paste(d$recording_id, d$start)
  sp <- d$is_species
  d$n_labels_window <- 0L
  d$n_labels_window[sp] <- as.integer(stats::ave(d$confidence[sp], window[sp], FUN = length))
  d$other_confidence_max <- 0
  d$other_confidence_max[sp] <- stats::ave(d$confidence[sp], window[sp], FUN = function(x) {
    if (length(x) == 1) return(0)
    vapply(seq_along(x), function(i) max(x[-i]), numeric(1))
  })
  # Events: overlapping windows of the same species in the same recording
  d <- d[order(d$recording_id, d$scientific_name, d$start), , drop = FALSE]
  new_event <- c(TRUE, d$recording_id[-1] != d$recording_id[-nrow(d)] |
                   d$scientific_name[-1] != d$scientific_name[-nrow(d)] |
                   d$start[-1] >= d$end[-nrow(d)])
  d$event <- cumsum(new_event)
  d <- d[d$confidence >= min_confidence, , drop = FALSE]
  if (nrow(d) == 0) return(empty_detections())

  gi <- g[match(d$recording_id, g$id), , drop = FALSE]
  start <- as.POSIXct(gi$start_utc, tz = "UTC") + d$start
  week <- birdnet_week(format(start, "%Y-%m-%d", tz = am$time_zone))
  common <- if (is.null(labels)) d$scientific_name else
    labels$common_name[match(d$scientific_name, labels$scientific_name)] %|NA|% d$scientific_name
  prob <- if (is.null(scores) || is.null(scores$place)) rep(NA_real_, nrow(d)) else
    scores$probability[match(paste(location_tag(gi), week, d$scientific_name),
                             paste(scores$place, scores$week, scores$scientific_name))]
  if (!is.null(scores)) prob[is.na(prob) & d$is_species] <- 0

  out <- data.frame(
    device_id = gi$device_id,
    deployment = gi$deployment,
    site = gi$site,
    lat = gi$lat,
    lon = gi$lon,
    precision_m = gi$precision_m,
    day_folder = gi$day_folder,
    file = gi$file,
    path = gi$path,
    recording_start_utc = gi$start_utc,
    local_date = format(start, "%Y-%m-%d", tz = am$time_zone),
    local_time = format(start, "%H:%M:%S", tz = am$time_zone),
    utc_offset = format(start, "%z", tz = am$time_zone),
    time_zone = am$time_zone,
    start_s = d$start,
    end_s = d$end,
    scientific_name = d$scientific_name,
    common_name = common,
    is_species = d$is_species,
    confidence = round(d$confidence, 4),
    n_labels_window = d$n_labels_window,
    other_confidence_max = round(d$other_confidence_max, 4),
    no_doubts = d$is_species & d$n_labels_window == 1,
    event = d$event,
    location_prob = prob,
    birdnet_week = week,
    model = sprintf("BirdNET %s", params$version),
    stringsAsFactors = FALSE
  )
  out <- out[order(out$recording_start_utc, out$start_s, -out$confidence), , drop = FALSE]
  rownames(out) <- NULL
  out
}

empty_detections <- function() {
  data.frame(device_id = character(), deployment = character(), site = character(), lat = numeric(), lon = numeric(),
             precision_m = integer(), day_folder = character(), file = character(),
             path = character(), recording_start_utc = character(), local_date = character(),
             local_time = character(), utc_offset = character(), time_zone = character(),
             start_s = numeric(), end_s = numeric(), scientific_name = character(),
             common_name = character(), is_species = logical(), confidence = numeric(),
             n_labels_window = integer(), other_confidence_max = numeric(), no_doubts = logical(),
             event = integer(), location_prob = numeric(), birdnet_week = integer(),
             model = character(), stringsAsFactors = FALSE)
}

#' Reads the detections of an AudioMoth
#'
#' @param x An `audiomoth` object (its detections, or the CSV of its results
#'   folder) or the path of an `AudioMoth_<ID>_detections.csv` file.
#' @return A data frame with one row per detection (3 s window and species).
#'   When `x` is an `audiomoth` object, the paths of the recordings are taken
#'   from its current inventory (the card may have been moved since the
#'   analysis).
#' @examples
#' d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
#'                                  package = "AudiomothR"))
#' d[, c("local_time", "scientific_name", "confidence", "no_doubts")]
#' @export
read_detections <- function(x) {
  am <- NULL
  if (inherits(x, "audiomoth")) {
    am <- x
    if (!is.null(x$detections)) return(update_paths(x$detections, am))
    x <- output_file(x, "detections")
  }
  if (!is.character(x) || length(x) != 1) abort("{.arg x} must be an {.cls audiomoth} object or the path of a detections CSV.")
  if (!file.exists(x)) abort("File {.file {x}} does not exist.", "i" = "Run {.fn analyze_birdnet} first.")
  d <- read_csv(x)
  for (col in c("is_species", "no_doubts")) if (!is.null(d[[col]])) d[[col]] <- as.logical(d[[col]])
  if (is.null(d$is_species)) d$is_species <- !d$scientific_name %in% non_species
  if (is.null(d$event)) d$event <- seq_len(nrow(d))
  if (is.null(d$location_prob)) d$location_prob <- rep(NA_real_, nrow(d))
  if (is.null(d$deployment)) d$deployment <- rep(NA_character_, nrow(d))
  if (!is.null(am)) d <- update_paths(d, am)
  d
}

#' Paths of the recordings according to the current inventory
#' @noRd
update_paths <- function(d, am) {
  if (nrow(d) == 0) return(d)
  g <- am$recordings
  k <- match(paste(d$day_folder %|NA|% "", d$file), paste(g$day_folder %|NA|% "", g$file))
  d$path <- ifelse(is.na(k), d$path, g$path[k])
  # The deployment and its location (it may have been corrected since)
  for (col in intersect(c("deployment", "site", "lat", "lon", "precision_m"), names(g))) {
    if (is.null(d[[col]])) d[[col]] <- rep(NA, nrow(d))
    d[[col]] <- ifelse(is.na(k), d[[col]], g[[col]][k])
  }
  d
}

#' Runs Python code without the messages that TensorFlow Lite writes directly
#' to the standard error (file descriptor 2) and the progress bars of Python
#' @noRd
quiet_python <- function(expr) {
  # Only once Python is running: starting it here, before birdnetR has set up
  # its environment, would load the wrong Python
  ok <- reticulate::py_available(initialize = FALSE) && tryCatch({
    reticulate::py_run_string(paste(
      "import os, sys",
      "_am_fd = os.dup(2)",
      "_am_null = os.open(os.devnull, os.O_WRONLY)",
      "sys.stderr.flush()",
      "os.dup2(_am_null, 2)",
      "_am_stderr = sys.stderr",
      "sys.stderr = open(os.devnull, 'w')", sep = "\n"))
    TRUE
  }, error = function(e) FALSE)
  if (ok) {
    on.exit(try(reticulate::py_run_string(paste(
      "import os, sys",
      "sys.stderr.close()",
      "sys.stderr = _am_stderr",
      "os.dup2(_am_fd, 2)",
      "os.close(_am_fd)",
      "os.close(_am_null)", sep = "\n")), silent = TRUE))
  }
  expr
}

parallel_cores <- function() {
  n <- tryCatch(parallel::detectCores(), error = function(e) NA)
  if (is.na(n)) 2L else as.integer(n)
}
