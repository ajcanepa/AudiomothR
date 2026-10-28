# Choosing the folder of an AudioMoth card and taking the inventory of its
# recordings.
#
# Expected structure ("Use daily folder for WAV files" enabled):
#   <folder>/CONFIG.TXT
#   <folder>/20261006/FACADE0012345678_20261006_042000.WAV
#   <folder>/20261007/...
# WAV files directly next to CONFIG.TXT are also accepted, and so is a copy
# of the recordings without CONFIG.TXT (everything needed is in the WAVs).

#' Chooses the folder of an AudioMoth card with a dialog
#'
#' Opens the folder chooser of RStudio or, when it is not available, the
#' Tcl/Tk one. Without a graphical interface it asks for the path in the
#' console (a folder dragged from the file manager into the terminal is
#' accepted, with its escaped spaces).
#'
#' @param start Folder where the dialog opens.
#' @return Path of the chosen folder (the one that contains CONFIG.TXT).
#' @examples
#' if (interactive()) choose_folder()
#' @export
choose_folder <- function(start = getwd()) {
  if (!interactive()) {
    abort("{.fn choose_folder} only works in an interactive session.",
          "i" = "Give the folder directly, e.g. {.code read_audiomoth(\"/path/to/card\")}.")
  }
  title <- "AudioMoth folder (the one that contains CONFIG.TXT)"
  path <- NULL
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    path <- rstudioapi::selectDirectory(caption = title, path = start)
  } else if (suppressMessages(requireNamespace("tcltk", quietly = TRUE)) && capabilities("tcltk")) {
    path <- tryCatch(tcltk::tk_choose.dir(default = start, caption = title), error = function(e) NULL)
  } else {
    path <- readline(paste0(title, ": "))
    path <- trimws(path, whitespace = "[\\s\"']")
    # A folder dragged into a macOS or Linux terminal comes with "\ " escapes
    if (.Platform$OS.type != "windows") path <- gsub("\\\\(.)", "\\1", path)
  }
  if (is.null(path) || is.na(path) || !nzchar(path)) abort("No folder was chosen.")
  path <- normalizePath(path.expand(trimws(path, whitespace = "[\\s\"']")), mustWork = FALSE)
  if (!dir.exists(path)) abort("Folder {.file {path}} does not exist.")
  if (!file.exists(file.path(path, "CONFIG.TXT"))) {
    cli::cli_warn("Folder {.file {path}} does not contain {.file CONFIG.TXT}.")
  }
  path
}

#' Reads an AudioMoth card: configuration, location and inventory
#'
#' Identifies the recordings of each daily folder with the data of the
#' `CONFIG.TXT` file (device, sample rate, gain...) and with the metadata that
#' AudioMoth writes in each WAV file (start time in UTC, gain, battery and
#' temperature, from the comment or the GUANO block). The inventory is saved
#' as `AudioMoth_<ID>_recordings.csv` in the `output` folder. The audio is not
#' loaded.
#'
#' **Location.** Taken from `coordinates` when given; otherwise from the
#' `Location` field of `CONFIG.TXT`. If there is none and the session is
#' interactive, it is asked for in the console: just copy and paste the
#' position of a point from Google Earth or Google Maps (see
#' [parse_coordinates()]). `CONFIG.TXT` keeps the location with two decimals
#' only (about 700 m), so giving `coordinates` is recommended. When both
#' exist and are more than 10 km apart, a warning is given (and an error when
#' latitude and longitude look swapped).
#'
#' **Recordings that are not valid** (column `problem`): unreadable or empty
#' files, interrupted recordings, recordings shorter than 3 s, recordings
#' without a date and duplicated copies of the same recording. Triggered
#' recordings (`*T.WAV`, amplitude or frequency threshold) are recognised and
#' their real duration, with the silences, is used.
#'
#' **Output folder.** Each card (each deployment) needs its own `output`
#' folder: the BirdNET cache and the results of two different cards must not
#' be mixed. It is better outside the card, which is usually formatted for
#' the next deployment. When `output` is not given, it is asked for in the
#' console (see [choose_output()]), suggesting a folder in
#' `~/AudiomothR_results/` or the one chosen last time for the same card; in
#' a non-interactive session (`Rscript`) it must be given.
#'
#' @param folder Folder with `CONFIG.TXT` and the daily folders. By default it
#'   is chosen with a dialog ([choose_folder()]). A copy of the recordings
#'   without `CONFIG.TXT` is also accepted (then `coordinates` is required).
#' @param coordinates Coordinates of the site in any format accepted by
#'   [parse_coordinates()]. They take priority over those of `CONFIG.TXT`.
#' @param site Name of the sampling site (optional).
#' @param precision_m Precision of the location in metres (the `accuracy` of
#'   Observation.org). By default, the one implied by the number of decimals.
#' @param time_zone Time zone of the local dates and times, as a name of
#'   [OlsonNames()] (`"Europe/Madrid"`, `"Atlantic/Canary"`...). `"UTC+2"` is
#'   accepted and translated into the fixed zone `"Etc/GMT-2"`.
#' @param output Results folder (it is created if needed). By default it is
#'   asked for with [choose_output()].
#' @return An object of class `audiomoth`: a list with `folder`, `config`,
#'   `location`, `site`, `time_zone`, `output` and `recordings` (data frame
#'   with one row per WAV file).
#' @examples
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
#' head(am$recordings[, c("file", "start_local", "duration_s", "valid", "problem")])
#' @export
read_audiomoth <- function(folder = choose_folder(), coordinates = NULL, site = NULL,
                           precision_m = NULL, time_zone = "Europe/Madrid", output = NULL) {
  if (!is.character(folder) || length(folder) != 1 || is.na(folder)) abort("{.arg folder} must be the path of a folder.")
  folder <- normalizePath(folder, mustWork = FALSE)
  if (!dir.exists(folder)) abort("Folder {.file {folder}} does not exist.")
  time_zone <- check_time_zone(time_zone)
  if (!is.null(precision_m)) check_number(precision_m, "precision_m", min = 1e-9, hint = "For example {.code precision_m = 10}.")
  if (!is.null(site) && (!is.character(site) || length(site) != 1)) abort("{.arg site} must be a text.")
  config_file <- list.files(folder, pattern = "^CONFIG\\.TXT$", ignore.case = TRUE, full.names = TRUE)
  config <- if (length(config_file)) read_config(config_file[1]) else NULL
  output <- resolve_output(output, folder, config)
  check_writable(output)
  recordings <- inventory_wav(folder, config, time_zone, output)
  if (is.null(config)) {
    if (is.null(coordinates) && !interactive()) {
      abort("There is no {.file CONFIG.TXT} in {.file {folder}}.",
            "i" = "Choose the root folder of the card (the one with CONFIG.TXT and the daily folders) or give {.arg coordinates} to read a copy of the recordings.")
    }
    cli::cli_warn(c("There is no {.file CONFIG.TXT} in {.file {folder}}: the configuration is taken from the WAV files."))
    config <- config_from_recordings(recordings)
  }
  if (anyNA(recordings$device_id)) recordings$device_id[is.na(recordings$device_id)] <- config$device_id
  check_card_consistency(recordings, config)

  location <- resolve_location(coordinates, config)
  if (!is.null(precision_m)) location$precision_m <- as.integer(ceiling(precision_m))
  check_time_zone_location(time_zone, location)
  check_output_card(output, config$device_id, recordings)

  am <- structure(list(
    folder = folder,
    config = config,
    location = location,
    site = site %||% paste("AudioMoth", config$device_id),
    time_zone = time_zone,
    output = output,
    recordings = recordings
  ), class = "audiomoth")
  write_csv(recordings, output_file(am, "recordings"))
  if (!isTRUE(getOption("AudiomothR.quiet"))) print(am)
  invisible(am)
}

#' Asks for the results folder
#'
#' Asks in the console for the folder where the results of a card are saved
#' (a path can be typed, pasted or dragged from the file manager). Pressing
#' Enter accepts the suggested folder. The folder does not need to exist.
#' [read_audiomoth()] and [process_audiomoth()] call it when `output` is not
#' given.
#'
#' @param suggested Folder proposed by default.
#' @return The path of the chosen folder.
#' @examples
#' if (interactive()) choose_output("~/AudiomothR_results/card_01")
#' @export
choose_output <- function(suggested = file.path("~", "AudiomothR_results")) {
  if (!interactive()) {
    abort("{.fn choose_output} only works in an interactive session.",
          "i" = "Give the results folder directly with {.arg output}.")
  }
  cli::cli_inform(c("i" = "Results folder (better outside the card; one per card).",
                    " " = "Press Enter to use {.file {suggested}}, or type another path."))
  path <- readline("Results folder: ")
  path <- trimws(path, whitespace = "[\\s\"']")
  if (.Platform$OS.type != "windows") path <- gsub("\\\\(.)", "\\1", path)
  if (!nzchar(path)) path <- suggested
  normalizePath(path.expand(path), mustWork = FALSE)
}

#' Results folder: the argument, or the one asked for (suggesting the folder
#' used last time for this card)
#' @noRd
resolve_output <- function(output, folder, config) {
  if (!is.null(output)) {
    if (!is.character(output) || length(output) != 1 || is.na(output) || !nzchar(output)) {
      abort("{.arg output} must be the path of a folder.")
    }
    return(normalizePath(path.expand(output), mustWork = FALSE))
  }
  device <- config$device_id
  if (is.null(device)) {
    first <- list.files(folder, pattern = "\\.wav$", ignore.case = TRUE, recursive = TRUE)[1]
    device <- parse_audiomoth_name(basename(first %|NA|% ""))$prefix_id %|NA|% basename(folder)
  }
  remembered <- remembered_output(folder)
  date <- if (!is.null(config) && !is.na(config$first_date)) paste0("_", gsub("-", "", config$first_date)) else ""
  suggested <- remembered %||% file.path("~", "AudiomothR_results", paste0("AudioMoth_", device, date))
  if (!interactive()) {
    if (!is.null(remembered)) {
      inform("i" = "Results in {.file {remembered}} (the folder used last time for this card).")
      return(normalizePath(remembered, mustWork = FALSE))
    }
    abort("Give the results folder with {.arg output}.",
          "i" = "For example {.code output = \"{suggested}\"} (better outside the card; one folder per card).")
  }
  output <- choose_output(suggested)
  remember_output(folder, output)
  output
}

#' File where the results folder of each card is remembered (only written in
#' interactive sessions)
#' @noRd
outputs_file <- function() file.path(tools::R_user_dir("AudiomothR", "config"), "outputs.csv")

remembered_output <- function(folder) {
  f <- outputs_file()
  if (!file.exists(f)) return(NULL)
  x <- tryCatch(utils::read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)
  hit <- x$output[x$folder == folder]
  if (length(hit)) hit[length(hit)] else NULL
}

remember_output <- function(folder, output) {
  f <- outputs_file()
  x <- if (file.exists(f)) tryCatch(utils::read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)
  x <- rbind(x[x$folder != folder, c("folder", "output"), drop = FALSE],
             data.frame(folder = folder, output = output, stringsAsFactors = FALSE))
  try(write_csv(x, f), silent = TRUE)
}

#' Checks a time zone; translates "UTC+2" into "Etc/GMT-2"
#' @noRd
check_time_zone <- function(time_zone) {
  if (!is.character(time_zone) || length(time_zone) != 1 || is.na(time_zone)) {
    abort("{.arg time_zone} must be a single name, e.g. {.val Europe/Madrid}.")
  }
  m <- regmatches(time_zone, regexec("^(?:UTC|GMT)\\s*([+-])\\s*([0-9]{1,2})$", toupper(time_zone)))[[1]]
  if (length(m)) {
    # The sign of the Etc/GMT zones is reversed: UTC+2 is "Etc/GMT-2"
    olson <- sprintf("Etc/GMT%s%d", if (m[2] == "+") "-" else "+", as.integer(m[3]))
    inform("i" = "Time zone {.val {time_zone}} is used as {.val {olson}} (fixed offset, no daylight saving time).")
    return(olson)
  }
  if (toupper(time_zone) %in% c("UTC", "GMT")) return("UTC")
  if (!time_zone %in% OlsonNames()) {
    abort("Unknown time zone: {.val {time_zone}}.",
          "i" = "Use a name of {.fn OlsonNames}, e.g. {.val Europe/Madrid} (with daylight saving time) or {.val UTC+2} (fixed offset).")
  }
  time_zone
}

#' Errors early when the results folder cannot be written
#' @noRd
check_writable <- function(output) {
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  probe <- file.path(output, ".audiomothr_write_test")
  ok <- dir.exists(output) && isTRUE(tryCatch(file.create(probe), warning = function(w) FALSE,
                                              error = function(e) FALSE))
  unlink(probe)
  if (!ok) {
    abort("Cannot write in {.file {output}} (write-protected card or read-only folder?).",
          "i" = "Give another results folder with {.arg output}, e.g. {.code output = \"~/AudiomothR_results/card_01\"}.")
  }
}

#' Chooses the location: argument > CONFIG.TXT > console
#' @noRd
resolve_location <- function(coordinates, config) {
  if (!is.null(coordinates)) {
    u <- parse_coordinates(coordinates)
    u$source <- "argument"
    if (!is.null(config$location)) {
      d <- distance_km(u, config$location)
      d_swapped <- distance_km(list(lat = u$lon, lon = u$lat), config$location)
      if (d > 10 && d_swapped < 10) {
        abort("The latitude and longitude of {.arg coordinates} look swapped: the point is {round(d)} km away from the location of the CONFIG.TXT ({config$location$lat}, {config$location$lon}).",
              "i" = "Without hemisphere letters the latitude goes first, e.g. {.val {config$location$lat}, {config$location$lon}}.")
      }
      if (d > 10) {
        cli::cli_warn(c("The coordinates are {round(d)} km away from the location of the CONFIG.TXT ({config$location$lat}, {config$location$lon}).",
                        "i" = "Check them: {.url {map_link(u$lat, u$lon)}}"))
      }
    }
    return(u)
  }
  if (!is.null(config$location)) {
    u <- config$location
    u$source <- "CONFIG.TXT"
    if (u$precision_m > 100) {
      inform(
        "i" = "The location of the CONFIG.TXT ({u$lat}, {u$lon}) has few decimals (\u00b1{u$precision_m} m).",
        " " = "For more precision, copy the position from Google Earth and give it with {.arg coordinates}."
      )
    }
    return(u)
  }
  if (interactive()) {
    cli::cli_inform(c("!" = "The CONFIG.TXT does not include the location of the recorder.",
                      "i" = "Copy the position of the site in Google Earth (or Google Maps) and paste it here."))
    for (attempt in 1:3) {
      u <- tryCatch(parse_coordinates(readline("Coordinates: ")), error = function(e) {
        cli::cli_alert_danger(cli_escape(conditionMessage(e)))
        NULL
      })
      if (is.null(u)) next
      cli::cli_inform(c("i" = "Read as {u$lat}, {u$lon} (\u00b1{u$precision_m} m): {.url {map_link(u$lat, u$lon)}}"))
      if (tolower(substr(readline("Is it right? (y/n): "), 1, 1)) %in% c("y", "s")) {
        u$source <- "console"
        return(u)
      }
    }
    abort("No valid location was given.")
  }
  abort("The CONFIG.TXT does not include the location of the recorder.",
        "i" = "Give it with {.arg coordinates}, e.g. {.code coordinates = \"41.123456, -3.123456\"} (copied from Google Earth).")
}

#' Warns when the local time zone does not fit the location
#' @noRd
check_time_zone_location <- function(time_zone, location) {
  if (time_zone == "Europe/Madrid" && location$lat > 27 && location$lat < 29.5 &&
      location$lon > -18.5 && location$lon < -13) {
    cli::cli_warn(c("The recorder is in the Canary Islands but {.arg time_zone} is {.val Europe/Madrid}: local times would be 1 h ahead.",
                    "i" = "Use {.code time_zone = \"Atlantic/Canary\"}."))
    return(invisible())
  }
  offset <- as.numeric(format(as.POSIXct("2026-01-15 12:00", tz = time_zone), "%z")) %/% 100
  if (abs(offset - location$lon / 15) > 3) {
    cli::cli_warn("The time zone {.val {time_zone}} (UTC{sprintf('%+d', offset)}) does not seem to fit the longitude of the recorder ({location$lon}); check {.arg time_zone}.")
  }
}

#' Inventory of the WAV files of the card (the audio is not loaded)
#' @noRd
inventory_wav <- function(folder, config, time_zone, output) {
  paths <- list.files(folder, pattern = "\\.wav$", ignore.case = TRUE, full.names = TRUE, recursive = TRUE)
  paths <- normalizePath(paths, mustWork = FALSE)
  paths <- paths[!startsWith(paths, paste0(output, .Platform$file.sep)) & !startsWith(paths, paste0(output, "/"))]
  relative <- substring(paths, nchar(folder) + 2)
  in_day <- grepl("^[0-9]{8}[/\\\\][^/\\\\]+$", relative) | !grepl("[/\\\\]", relative)
  if (any(!in_day)) {
    outside <- relative[!in_day]
    if (all(!in_day)) {
      abort("There are no WAV files in {.file {folder}} nor in its daily folders (YYYYMMDD).",
            "i" = "{length(outside)} WAV file{?s} were found in other subfolders, e.g. {.file {outside[1]}}: choose the folder that contains them.")
    }
    cli::cli_warn("{length(outside)} WAV file{?s} outside the root and the daily folders {?is/are} ignored (e.g. {.file {outside[1]}}).")
  }
  paths <- sort(paths[in_day])
  if (length(paths) == 0) abort("No WAV files were found in {.file {folder}}.")
  relative <- substring(paths, nchar(folder) + 2)
  in_root <- !grepl("[/\\\\]", relative)

  meta <- wav_metadata(paths, output)
  comment <- parse_audiomoth_comment(meta$comment)
  name <- parse_audiomoth_name(basename(paths))
  duration <- meta$duration_s
  triggered <- meta$triggered & !is.na(duration)
  duration[triggered] <- meta$real_duration_s[triggered]
  guano <- function(key) meta[[paste0("guano_", key)]]

  # Start time: comment (it states its time zone), GUANO, and the file name
  # in the time zone of the CONFIG.TXT as a last resort
  start <- comment$start_utc
  source <- ifelse(is.na(start), NA_character_, "comment")
  guano_start <- parse_iso_time(guano("timestamp"))
  use <- is.na(start) & !is.na(guano_start)
  start[use] <- guano_start[use]
  source[use] <- "GUANO"
  offset <- if (is.null(config)) NA_real_ else config$utc_offset_h
  name_start <- date_with_offset(name$date_text, "%Y%m%d_%H%M%S", offset)
  use <- is.na(start) & !is.na(name_start)
  start[use] <- name_start[use]
  source[use] <- "file name"
  use <- use & !is.na(duration)   # unreadable files are not worth a warning
  if (any(use)) {
    cli::cli_warn(c("The start time of {sum(use)} recording{?s} is taken from the file name.",
                    "i" = if (is.na(offset)) "The time zone of the device clock is unknown: UTC is assumed." else
                      "The device clock is assumed to be at UTC{sprintf('%+g', offset)} (CONFIG.TXT)."))
  }

  # Device: comment, GUANO, CONFIG.TXT, and the file name prefix only when it
  # is not a deployment ID
  device <- comment$device_id
  device[is.na(device)] <- toupper(guano("serial"))[is.na(device)]
  if (!is.null(config)) device[is.na(device)] <- config$device_id
  use_prefix <- is.na(device) & is.na(comment$deployment_id)
  device[use_prefix] <- name$prefix_id[use_prefix]

  battery <- suppressWarnings(as.numeric(guano("battery")))
  battery_limit <- ifelse(is.na(battery), comment$battery_limit, NA_character_)
  battery[is.na(battery)] <- comment$battery_v[is.na(battery)]
  temperature <- suppressWarnings(as.numeric(guano("temperature")))
  temperature[is.na(temperature)] <- comment$temperature_c[is.na(temperature)]

  problem <- rep(NA_character_, length(paths))
  problem[is.na(duration)] <- "unreadable or empty WAV"
  problem[is.na(problem) & meta$incomplete_header] <- "incomplete header (interrupted recording)"
  problem[is.na(problem) & duration < 3] <- "duration < 3 s"
  problem[is.na(problem) & is.na(start)] <- "no date"

  # Duplicated copies of the same recording ("..._071500 2.WAV", the same file
  # in the root and in its daily folder): the original in its daily folder is kept
  key <- paste(device, format(start, tz = "UTC"), round(duration, 1))
  prefer <- order(nzchar(name$suffix %|NA|% ""), in_root)
  duplicate <- logical(length(paths))
  duplicate[prefer] <- duplicated(key[prefer]) & !is.na(start[prefer])
  problem[is.na(problem) & duplicate] <- "duplicate"
  if (any(duplicate)) cli::cli_warn("{sum(duplicate)} duplicated recording{?s} {?is/are} ignored (column {.field problem}).")

  rec <- data.frame(
    id = seq_along(paths),
    file = basename(paths),
    day_folder = ifelse(in_root, "", basename(dirname(paths))),
    path = paths,
    device_id = device,
    deployment_id = comment$deployment_id,
    start_utc = format(start, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    start_local = format(start, "%Y-%m-%d %H:%M:%S", tz = time_zone),
    local_date = format(start, "%Y-%m-%d", tz = time_zone),
    utc_offset = format(start, "%z", tz = time_zone),
    time_zone = time_zone,
    start_source = source,
    duration_s = round(duration, 3),
    sample_rate = meta$sample_rate,
    channels = meta$channels,
    bits = meta$bits,
    gain = comment$gain %|NA|% (if (is.null(config)) NA_character_ else tolower(config$gain)),
    battery_v = battery,
    battery_limit = battery_limit,
    temperature_c = temperature,
    triggered = triggered,
    valid = is.na(problem),
    problem = problem,
    stringsAsFactors = FALSE
  )
  rec <- rec[order(rec$start_utc, rec$file), , drop = FALSE]
  rec$id <- seq_len(nrow(rec))
  rownames(rec) <- NULL
  rec
}

#' Metadata of the WAV files, read from their headers or from the cache
#'
#' Reading the headers of a whole card takes a while (thousands of files), so
#' the result for each file is kept in `<output>/.inventory_cache.rds` and
#' reused while the file keeps its path, size and modification time.
#' @noRd
wav_metadata <- function(paths, output) {
  info <- file.info(paths, extra_cols = FALSE)
  key <- paste(paths, info$size, as.numeric(info$mtime), sep = "|")
  cache_file <- file.path(output, ".inventory_cache.rds")
  cached <- if (file.exists(cache_file)) tryCatch(readRDS(cache_file), error = function(e) NULL) else NULL
  if (!is.data.frame(cached) || !identical(names(cached), wav_metadata_columns)) cached <- NULL
  todo <- if (is.null(cached)) seq_along(paths) else which(!key %in% cached$key)
  new <- NULL
  if (length(todo)) {
    bar <- cli::cli_progress_bar(name = sprintf("Reading the metadata of %d recordings", length(todo)),
                                 total = length(todo))
    rows <- lapply(todo, function(k) {
      cli::cli_progress_update(id = bar)
      one_wav_metadata(paths[k], key[k])
    })
    cli::cli_progress_done(id = bar)
    new <- do.call(rbind, rows)
  }
  all <- rbind(cached[cached$key %in% key, , drop = FALSE], new)
  if (length(todo)) try(saveRDS(all, cache_file), silent = TRUE)
  all[match(key, all$key), , drop = FALSE]
}

wav_metadata_columns <- c("key", "duration_s", "real_duration_s", "sample_rate", "channels", "bits",
                          "incomplete_header", "triggered", "comment", "guano_timestamp",
                          "guano_serial", "guano_battery", "guano_temperature")

one_wav_metadata <- function(path, key) {
  h <- tryCatch(read_wav_header(path), error = function(e) NULL)
  g <- function(k) if (is.null(h)) NA_character_ else h$guano[[k]] %||% NA_character_
  comment <- if (is.null(h)) NA_character_ else h$info$ICMT %||% NA_character_
  triggered <- !is.null(h) && (isTRUE(parse_audiomoth_name(basename(path))$triggered) ||
                                 isTRUE(parse_audiomoth_comment(comment)$threshold))
  data.frame(
    key = key,
    duration_s = if (is.null(h)) NA_real_ else h$duration_s,
    real_duration_s = if (triggered) triggered_duration(path, h) else NA_real_,
    sample_rate = if (is.null(h)) NA_integer_ else h$sample_rate,
    channels = if (is.null(h)) NA_integer_ else h$channels,
    bits = if (is.null(h)) NA_integer_ else h$bits,
    incomplete_header = !is.null(h) && h$incomplete_header,
    triggered = triggered,
    comment = comment,
    guano_timestamp = g("Timestamp"), guano_serial = g("Serial"),
    guano_battery = g("Battery Voltage"), guano_temperature = g("Temperature Int"),
    stringsAsFactors = FALSE
  )
}

`%|NA|%` <- function(x, y) {
  y <- rep_len(y, length(x))
  x[is.na(x)] <- y[is.na(x)]
  x
}

#' ISO 8601 times of GUANO ("2026-10-06T04:15:00Z", "...+02:00") in UTC
#' @noRd
parse_iso_time <- function(x) {
  m <- regmatches(x, regexec("^([0-9-]{10})[T ]([0-9:]{8})(?:\\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?$", x))
  out <- vapply(m, function(p) {
    if (length(p) == 0) return(NA_real_)
    t <- as.numeric(as.POSIXct(paste(p[2], p[3]), format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
    if (nzchar(p[4]) && p[4] != "Z") {
      sign <- if (startsWith(p[4], "-")) -1 else 1
      hm <- as.numeric(c(substr(p[4], 2, 3), substr(gsub(":", "", p[4]), 4, 5)))
      t <- t - sign * (hm[1] * 3600 + hm[2] * 60)
    }
    t
  }, numeric(1))
  as.POSIXct(out, origin = "1970-01-01", tz = "UTC")
}

#' Minimal configuration when the card has no CONFIG.TXT
#' @noRd
config_from_recordings <- function(recordings) {
  most <- function(x) {
    x <- stats::na.omit(x)
    if (length(x)) names(sort(table(x), decreasing = TRUE))[1] else NA
  }
  device <- most(recordings$device_id)
  if (is.na(device)) abort("The device ID cannot be found in the WAV files.")
  structure(list(file = NA_character_, settings = list(), device_id = device, firmware = NA_character_,
                 device_time_utc = as.POSIXct(NA), sample_rate = as.integer(most(recordings$sample_rate)),
                 gain = most(recordings$gain), sleep_s = NA_real_, recording_s = NA_real_,
                 periods = NULL, sun_mode = NA_character_, trigger = NA_character_,
                 first_date = min(c(recordings$local_date, NA), na.rm = TRUE),
                 last_date = max(c(recordings$local_date, NA), na.rm = TRUE),
                 utc_offset_h = NA_real_, location = NULL),
            class = "audiomoth_config")
}

#' Warns when the WAV files do not match the CONFIG.TXT (mixed cards, or a
#' device reconfigured during the deployment)
#' @noRd
check_card_consistency <- function(recordings, config) {
  other <- !is.na(recordings$device_id) & recordings$device_id != config$device_id
  if (any(other)) {
    cli::cli_warn("{sum(other)} recording{?s} {?was/were} made by another AudioMoth ({.val {unique(recordings$device_id[other])}}): are two cards mixed?")
  }
  gain <- unique(stats::na.omit(recordings$gain))
  if (!is.na(config$gain) && length(gain) && any(gain != tolower(config$gain))) {
    cli::cli_warn("The gain of some recordings ({.val {gain}}) differs from the CONFIG.TXT ({.val {config$gain}}): the device was reconfigured during the deployment.")
  }
}

#' Each results folder belongs to a single card: otherwise the BirdNET cache
#' and the results of different cards would be mixed
#' @noRd
check_output_card <- function(output, device_id, recordings) {
  previous <- list.files(output, pattern = "^AudioMoth_.+_recordings\\.csv$", full.names = TRUE)
  own <- file.path(output, sprintf("AudioMoth_%s_recordings.csv", device_id))
  others <- setdiff(previous, own)
  if (length(others)) {
    abort("The results folder {.file {output}} already holds the results of another AudioMoth ({.file {basename(others[1])}}).",
          "i" = "Use a different {.arg output} folder for each card.")
  }
  if (file.exists(own)) {
    old <- tryCatch(read_csv(own), error = function(e) NULL)
    if (!is.null(old) && nrow(old) && !is.null(old$file) && !any(old$file %in% recordings$file)) {
      abort("The results folder {.file {output}} holds the results of another deployment of AudioMoth {device_id} (none of its recordings is on this card).",
            "i" = "Use a different {.arg output} folder for each deployment.")
    }
  }
}

#' Path of a results file: <output>/AudioMoth_<ID>_<type>.<ext>
#' @noRd
output_file <- function(am, type, ext = "csv") {
  file.path(am$output, sprintf("AudioMoth_%s_%s.%s", am$config$device_id, type, ext))
}

#' Checks that `am` is an audiomoth object
#' @noRd
check_audiomoth <- function(am) {
  if (!inherits(am, "audiomoth")) abort("{.arg am} must be the result of {.fn read_audiomoth}.")
}

#' @export
print.audiomoth <- function(x, ...) {
  g <- x$recordings
  dates <- stats::na.omit(g$local_date)
  days <- length(unique(dates))
  hours <- sum(g$duration_s, na.rm = TRUE) / 3600
  total <- if (hours < 1) sprintf("%.1f min", 60 * hours) else sprintf("%.1f h", hours)
  rates <- unique(stats::na.omit(g$sample_rate))
  u <- x$location
  cli::cli_h1("AudioMoth {x$config$device_id}")
  cli::cli_ul(c(
    "Folder: {.file {x$folder}}",
    "Site: {x$site} ({u$lat}, {u$lon}; \u00b1{u$precision_m} m; source: {u$source})",
    "Map: {.url {map_link(u$lat, u$lon)}}",
    if (length(dates)) "Recordings: {nrow(g)} in {days} day{?s} ({min(dates)} to {max(dates)}, {x$time_zone} time)" else "Recordings: {nrow(g)}",
    if (length(rates)) "Audio: {paste(format(rates, big.mark = ','), collapse = ', ')} Hz, gain {x$config$gain}, {total} in total",
    if (any(g$triggered)) "{sum(g$triggered)} triggered recording{?s} (amplitude or frequency threshold)",
    if (any(!g$valid)) "{.strong {sum(!g$valid)}} with problems: {paste(unique(stats::na.omit(g$problem)), collapse = '; ')}",
    if (any(!is.na(g$battery_v))) "Battery: {max(g$battery_v, na.rm = TRUE)} V \u2192 {min(g$battery_v, na.rm = TRUE)} V",
    if (any(!is.na(g$temperature_c))) "Temperature: {min(g$temperature_c, na.rm = TRUE)} to {max(g$temperature_c, na.rm = TRUE)} \u00b0C",
    "Results in: {.file {x$output}}"
  ))
  invisible(x)
}
