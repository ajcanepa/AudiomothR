# High-confidence examples: selection, audio clip, spectrogram and video of
# the spectrogram with its audio.

#' Chooses the best detections of each species
#'
#' Only detections with a confidence of at least `min_confidence` are
#' accepted and, with `no_doubts = TRUE`, only those in which BirdNET proposed
#' no other species in the same 3 s window. The ones with the highest
#' confidence are taken, at most one per recording, so that the examples are
#' varied.
#'
#' @param x An `audiomoth` object with detections, or a data frame from
#'   [read_detections()].
#' @param species Names of the species: scientific or common names of BirdNET
#'   (case and accents do not matter) or IOC names. Also a named vector
#'   `c("Cettia cetti" = 3, ...)` with the number of examples of each species,
#'   as printed and returned by [detected_species()].
#' @param n Largest number of examples per species: one value for all of them
#'   or one per species. Not used when `species` already has the number of
#'   each one. Species with `n = 0` are skipped.
#' @param min_confidence Minimum confidence of the examples.
#' @param no_doubts Require that BirdNET proposed no other species in the
#'   same window.
#' @param one_per_recording At most one example from each recording.
#' @return A data frame with the chosen detections (column `example`: order
#'   within its species).
#' @examples
#' d <- read_detections(system.file("extdata", "example", "birdnet_detections.csv",
#'                                  package = "AudiomothR"))
#' select_examples(d, "Cettia cetti", n = 1, min_confidence = 0.5)
#' @export
select_examples <- function(x, species, n = 3, min_confidence = 0.85, no_doubts = TRUE,
                            one_per_recording = TRUE) {
  check_confidence(min_confidence, "min_confidence")
  check_flag(no_doubts, "no_doubts")
  check_flag(one_per_recording, "one_per_recording")
  d <- if (inherits(x, "audiomoth")) read_detections(x) else detections_of(x)
  if (missing(species) || length(species) == 0) abort("Give at least one species in {.arg species}.")
  requested <- examples_per_species(species, n)

  # Each requested name is translated into the scientific names of BirdNET:
  # the same species asked twice (by its scientific and common names) is
  # chosen only once, with the largest n
  found <- match_species(names(requested), d)
  warn_unknown_species(names(requested)[lengths(found) == 0], d)
  wanted <- unlist(lapply(seq_along(found), function(i) stats::setNames(rep(requested[[i]], length(found[[i]])), found[[i]])))
  if (length(wanted) == 0) return(data.frame())
  if (anyDuplicated(names(wanted))) {
    inform("i" = "Some species were requested more than once: the largest number of examples is used.")
    wanted <- tapply(wanted, names(wanted), max)
  }

  chosen <- list()
  for (e in names(wanted)) {
    n_e <- wanted[[e]]
    de <- d[d$scientific_name == e, , drop = FALSE]
    ok <- de$confidence >= min_confidence & (!no_doubts | de$no_doubts)
    cand <- de[ok, , drop = FALSE]
    cand <- cand[order(-cand$confidence), , drop = FALSE]
    if (one_per_recording) cand <- cand[!duplicated(paste(cand$day_folder, cand$file)), , drop = FALSE]
    cand <- utils::head(cand, n_e)
    if (nrow(cand) < n_e) {
      cli::cli_warn(c(
        "{.val {de$common_name[1]}} ({e}): {nrow(cand)} of the {n_e} requested examples meet the criteria.",
        "i" = "Highest confidence detected: {max(de$confidence)}; without another species in the window: {max(c(0, de$confidence[de$no_doubts]))}."
      ))
    }
    if (nrow(cand)) {
      cand$example <- seq_len(nrow(cand))
      chosen[[e]] <- cand
    }
  }
  out <- do.call(rbind, chosen)
  if (is.null(out)) return(data.frame())
  out <- out[!duplicated(paste(out$file, out$start_s, out$scientific_name)), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Number of examples of each species
#'
#' `species` may be a named vector `c("Cettia cetti" = 2, ...)`; otherwise
#' `n` is one value for all or one per species. Returns a named vector
#' (species = n) without the species with n = 0.
#' @noRd
examples_per_species <- function(species, n) {
  if (is.numeric(species)) {
    if (is.null(names(species)) || any(!nzchar(names(species)))) {
      abort("If {.arg species} is numeric, each value must be named after its species.",
            "i" = "For example: {.code c(\"Cettia cetti\" = 3, \"Turdus merula\" = 1)}.")
    }
    n <- unname(species)
    species <- names(species)
  } else if (!is.character(species)) {
    abort("{.arg species} must be names of species or a named vector of numbers.")
  } else if (!length(n) %in% c(1L, length(species))) {
    abort("{.arg n} must have one value or one per species ({length(species)}), not {length(n)}.")
  }
  if (anyNA(species) || any(!nzchar(trimws(species)))) abort("Some species names are empty or {.code NA}.")
  n <- rep_len(n, length(species))
  if (!is.numeric(n) || anyNA(n) || any(n < 0) || any(n != round(n))) {
    abort("The number of examples must be a whole number >= 0.")
  }
  requested <- stats::setNames(as.integer(n), species)
  requested[requested > 0]
}

#' Creates examples of the chosen species: audio, spectrogram and video
#'
#' For each detection chosen with [select_examples()], cuts the exact sound
#' of the detection (BirdNET window of 3 s) with a margin of `margin_s`
#' seconds before and after it, from the original recording (at its original
#' sample rate). Saves in `<output>/examples/<species>/`:
#' - the clip as WAV,
#' - its spectrogram as PNG (see [spectrogram_image()]),
#' - an MP4 video of the spectrogram with the audio (see
#'   [spectrogram_video()]),
#'
#' and keeps an index, `AudioMoth_<ID>_examples.csv`, in `<output>/examples/`.
#' Successive calls add their examples to the index (an example extracted
#' again replaces the previous one). The paths of the index are relative to
#' the `examples/` folder, so the results folder can be moved.
#'
#' @param am An `audiomoth` object with detections ([analyze_birdnet()]); the
#'   examples are saved in its results folder. A list of them extracts the
#'   examples of each recorder.
#' @inheritParams select_examples
#' @param margin_s Seconds of audio added before and after the detection.
#' @param video Create the MP4 video (needs ffmpeg).
#' @param style Style of the video: `"cursor"` (a line moves over the whole
#'   spectrogram) or `"scroll"` (the spectrogram scrolls under a fixed line).
#' @param fps,window_s,max_freq,db_range,width,height Settings of the
#'   spectrogram and the video (see [spectrogram_video()]).
#' @return Invisibly, the index of the examples created in this call (data
#'   frame with the paths of the files).
#' @examples
#' \donttest{
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#' am$detections <- read_detections(system.file("extdata", "example",
#'   "birdnet_detections.csv", package = "AudiomothR"))
#' extract_examples(am, "Cettia cetti", n = 1, min_confidence = 0.5, video = FALSE)
#' }
#' @export
extract_examples <- function(am, species, n = 3, min_confidence = 0.85, no_doubts = TRUE,
                             one_per_recording = TRUE, margin_s = 1, video = TRUE,
                             style = c("cursor", "scroll"), fps = 25, window_s = 3,
                             max_freq = 12000, db_range = 70, width = 1280, height = 720) {
  if (is.list(am) && !inherits(am, "audiomoth")) {
    out <- lapply(as_recorders(am), extract_examples, species = species, n = n,
                  min_confidence = min_confidence, no_doubts = no_doubts,
                  one_per_recording = one_per_recording, margin_s = margin_s, video = video,
                  style = style, fps = fps, window_s = window_s, max_freq = max_freq,
                  db_range = db_range, width = width, height = height)
    return(invisible(do.call(rbind, out)))
  }
  check_audiomoth(am)
  style <- check_choice(style, c("cursor", "scroll"), "style")
  check_number(margin_s, "margin_s", 0, 60)
  check_flag(video, "video")
  if (video) ffmpeg_path()   # fail before creating anything
  sel <- select_examples(am, species, n = n, min_confidence = min_confidence, no_doubts = no_doubts,
                         one_per_recording = one_per_recording)
  if (nrow(sel) == 0) {
    cli::cli_warn("No detection meets the criteria: no example has been created.")
    return(invisible(sel))
  }
  dir_ex <- file.path(am$output, "examples")
  sel$wav <- sel$png <- sel$mp4 <- NA_character_
  failed <- character()
  bar <- cli::cli_progress_bar(name = "Creating examples", total = nrow(sel))
  for (i in seq_len(nrow(sel))) {
    x <- sel[i, ]
    folder <- safe_name(x$scientific_name)
    base <- sprintf("%s_%02d_conf%02d_%s_%s", folder, x$example, round(100 * x$confidence),
                    gsub("-", "", x$local_date), gsub(":", "", x$local_time))
    res <- tryCatch({
      dir.create(file.path(dir_ex, folder), recursive = TRUE, showWarnings = FALSE)
      clip <- cut_audio(x$path, x$start_s - margin_s, x$end_s + margin_s)
      wav <- file.path(folder, paste0(base, ".wav"))
      tuneR::writeWave(clip$wave, file.path(dir_ex, wav))
      title <- sprintf("%s (%s) \u2014 confidence %.0f %%", x$common_name, x$scientific_name, 100 * x$confidence)
      subtitle <- sprintf("AudioMoth %s \u00b7 %s %s (%s) \u00b7 %s, %g-%g s", x$device_id, x$local_date,
                          x$local_time, x$time_zone, x$file, x$start_s, x$end_s)
      marks <- c(x$start_s, x$end_s) - clip$from
      png <- file.path(folder, paste0(base, ".png"))
      spectrogram_image(file.path(dir_ex, wav), file.path(dir_ex, png), title = title, subtitle = subtitle,
                        marks = marks, max_freq = max_freq, db_range = db_range, width = width,
                        height = height)
      mp4 <- NA_character_
      if (video) {
        # The style is part of the name: both videos of a detection can coexist
        mp4 <- file.path(folder, paste0(base, if (style == "cursor") "" else "_scroll", ".mp4"))
        spectrogram_video(file.path(dir_ex, wav), file.path(dir_ex, mp4), title = title,
                          subtitle = subtitle, marks = marks, style = style, fps = fps,
                          window_s = window_s, max_freq = max_freq, db_range = db_range,
                          width = width, height = height)
      }
      c(wav = wav, png = png, mp4 = mp4)
    }, error = function(e) conditionMessage(e))
    if (length(res) == 3) {
      sel[i, c("wav", "png", "mp4")] <- res
    } else {
      failed[base] <- res
    }
    cli::cli_progress_update(id = bar)
  }
  cli::cli_progress_done(id = bar)

  index <- sel[!is.na(sel$wav), c("device_id", "scientific_name", "common_name", "example", "confidence",
                                   "local_date", "local_time", "time_zone", "day_folder", "file",
                                   "start_s", "end_s", "wav", "png", "mp4"), drop = FALSE]
  file <- file.path(dir_ex, sprintf("AudioMoth_%s_examples.csv", am$config$device_id))
  all <- index
  if (file.exists(file)) {
    old <- tryCatch(read_csv(file), error = function(e) NULL)
    if (!is.null(old) && all(names(index) %in% names(old))) {
      old <- old[!old$wav %in% index$wav & file.exists(file.path(dir_ex, old$wav)), names(index), drop = FALSE]
      all <- rbind(old, index)
    }
  }
  if (nrow(all)) write_csv(all, file)
  if (length(failed)) {
    cli::cli_warn(c("{length(failed)} example{?s} could not be created:",
                    stats::setNames(cli_escape(paste(names(failed), failed, sep = ": ")), rep("x", length(failed)))))
  }
  inform(c("v" = "{nrow(index)} example{?s} of {length(unique(index$scientific_name))} species in {.file {dir_ex}}."))
  index$wav <- file.path(dir_ex, index$wav)
  index$png <- file.path(dir_ex, index$png)
  index$mp4 <- ifelse(is.na(index$mp4), NA_character_, file.path(dir_ex, index$mp4))
  invisible(index)
}

#' Cuts a fragment of a WAV file (limits adjusted to its real duration)
#' @noRd
cut_audio <- function(path, from, to) {
  if (!file.exists(path)) abort("Recording {.file {path}} does not exist (has the card been moved? Read it again with {.fn read_audiomoth}).")
  header <- read_wav_header(path)
  if (is.null(header)) abort("Cannot read {.file {path}}.")
  from <- max(0, from)
  to <- min(header$duration_s, to)
  if (to <= from) abort("The clip of {.file {basename(path)}} is empty ({from}-{to} s).")
  wave <- mono_wave(tuneR::readWave(path, from = from, to = to, units = "seconds"))
  list(wave = wave, from = from, to = to)
}

#' Mono `Wave` object from whatever tuneR returns (stereo or WaveMC, which
#' tuneR uses for 24 and 32-bit integer files)
#' @noRd
mono_wave <- function(wave) {
  if (inherits(wave, "WaveMC")) {
    return(tuneR::Wave(left = wave@.Data[, 1], samp.rate = wave@samp.rate, bit = wave@bit, pcm = wave@pcm))
  }
  if (wave@stereo) wave <- tuneR::mono(wave, "left")
  wave
}
