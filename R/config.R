# Reading the AudioMoth CONFIG.TXT file (adapted from Biosonora,
# fct_audiomoth.R).
#
# Time zones: AudioMoth states the zone of each time ("(UTC)", "(UTC+2)").
# All dates are converted to a UTC instant (POSIXct with tz = "UTC"); the
# conversion to local time is done later with the zone chosen by the user.

#' Reads the CONFIG.TXT file of an AudioMoth
#'
#' Format: one line per setting, `Key<spaces>: value`. Keys contain no ":"
#' but values do (times), so each line is split at the first one. A value of
#' "-" means "not applicable". Unknown keys are kept (other firmware versions
#' add fields).
#'
#' @param file Path to the CONFIG.TXT file.
#' @return A list of class `audiomoth_config` with `settings` (all the
#'   key/value pairs as text) and the interpreted fields: `device_id`,
#'   `firmware`, `device_time_utc`, `sample_rate`, `gain`, `sleep_s`,
#'   `recording_s`, `periods` (data frame), `sun_mode`, `trigger`,
#'   `first_date`, `last_date`, `utc_offset_h` and `location` (list with
#'   `lat`, `lon` and `precision_m`, or `NULL` when the file has no location).
#' @examples
#' card <- system.file("extdata", "example", "card", package = "AudiomothR")
#' read_config(file.path(card, "CONFIG.TXT"))
#' @export
read_config <- function(file) {
  if (!file.exists(file)) abort("File {.file {file}} does not exist.")
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  # A CONFIG.TXT saved again by a Windows editor may be in Latin-1 (the degree
  # sign of the location is then an invalid UTF-8 byte)
  bad <- !validUTF8(lines)
  if (any(bad)) lines[bad] <- iconv(lines[bad], from = "latin1", to = "UTF-8")
  lines <- trimws(sub("\r$", "", lines))
  lines <- lines[grepl(":", lines, fixed = TRUE)]
  if (length(lines) == 0 || !any(grepl("^Device ID", lines))) {
    abort("{.file {file}} does not look like an AudioMoth CONFIG.TXT (it has no {.field Device ID}).")
  }
  keys <- trimws(sub(":.*$", "", lines))
  values <- trimws(sub("^[^:]*:", "", lines))
  values[values == "-"] <- NA_character_
  settings <- stats::setNames(as.list(values), keys)
  get <- function(key) settings[[key]] %||% NA_character_

  # Fixed recording periods: "16:00 - 21:00 (UTC)"
  period_keys <- grep("^Recording period [0-9]+$", keys, value = TRUE)
  periods <- do.call(rbind, lapply(period_keys, function(k) {
    v <- settings[[k]]
    m <- regmatches(v, regexec("([0-9]{2}:[0-9]{2})\\s*-\\s*([0-9]{2}:[0-9]{2})", v))[[1]]
    data.frame(start = if (length(m)) m[2] else NA_character_,
               end = if (length(m)) m[3] else NA_character_,
               utc_offset_h = utc_offset(v), stringsAsFactors = FALSE)
  }))

  # Offset of the device clock: "Device time" (recent firmware), "Time zone"
  # (old firmware such as 1.5.0) or the zone of the recording periods
  device_time <- get("Device time")
  offset <- utc_offset(device_time)
  if (is.na(offset)) offset <- utc_offset(get("Time zone"))
  if (is.na(offset) && !is.null(periods)) offset <- periods$utc_offset_h[1]

  location <- NULL
  location_text <- get("Location")
  if (!is.na(location_text)) {
    location <- tryCatch(parse_coordinates(sub("\\s*\\(.*$", "", location_text)),
                         error = function(e) {
                           cli::cli_warn("Cannot read the location of the CONFIG.TXT ({.val {location_text}}): {cli_escape(conditionMessage(e))}")
                           NULL
                         })
  }

  structure(list(
    file = normalizePath(file),
    settings = settings,
    device_id = get("Device ID"),
    firmware = get("Firmware"),
    device_time_utc = date_with_offset(sub("\\s*\\(.*$", "", device_time), "%Y-%m-%d %H:%M:%S",
                                       utc_offset(device_time)),
    sample_rate = suppressWarnings(as.integer(get("Sample rate (Hz)"))),
    gain = get("Gain"),
    sleep_s = suppressWarnings(as.numeric(get("Sleep duration (s)"))),
    recording_s = suppressWarnings(as.numeric(get("Recording duration (s)"))),
    periods = periods,
    sun_mode = get("Sun recording mode"),
    trigger = get("Trigger type"),
    first_date = sub("\\s*\\(.*$", "", get("First recording date")),
    last_date = sub("\\s*\\(.*$", "", get("Last recording date")),
    utc_offset_h = offset,
    location = location
  ), class = "audiomoth_config")
}

#' @export
print.audiomoth_config <- function(x, ...) {
  zone <- function(h) if (is.na(h) || h == 0) "UTC" else sprintf("UTC%+g", h)
  cli::cli_h2("AudioMoth {x$device_id}")
  cli::cli_ul(c(
    if (!is.na(x$firmware)) "Firmware: {x$firmware}",
    if (!is.na(x$sample_rate)) "Sample rate: {format(x$sample_rate, big.mark = ',')} Hz, gain {x$gain}",
    if (!is.na(x$recording_s)) "Cycle: {x$recording_s} s recording / {x$sleep_s} s sleeping",
    if (!is.na(x$sun_mode)) "Sun recording mode: {x$sun_mode}",
    if (!is.null(x$periods)) "Periods ({zone(x$periods$utc_offset_h[1])}): {paste(x$periods$start, x$periods$end, sep = '-', collapse = ', ')}",
    if (!is.na(x$trigger)) "Trigger: {x$trigger} (amplitude or frequency threshold)",
    if (!is.na(x$first_date)) "Dates: {x$first_date} to {x$last_date}",
    if (!is.null(x$location)) "Location: {x$location$lat}, {x$location$lon} (\u00b1{x$location$precision_m} m)" else "Location: not set"
  ))
  invisible(x)
}

#' Offset from UTC stated in a text: "(UTC)" -> 0, "(UTC+2)" -> 2,
#' "(UTC-3:30)" -> -3.5. Returns NA when the text states no zone.
#' @noRd
utc_offset <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x)) return(NA_real_)
  m <- regmatches(x, regexec("UTC(?:([+-])([0-9]{1,2})(?::?([0-9]{2}))?)?", x, perl = TRUE))[[1]]
  if (length(m) == 0) return(NA_real_)
  if (!nzchar(m[2])) return(0)
  sign <- ifelse(m[2] == "-", -1, 1)
  minutes <- if (nzchar(m[4])) as.numeric(m[4]) else 0
  sign * (as.numeric(m[3]) + minutes / 60)
}

#' Converts a "wall clock" date with a known offset into a UTC instant
#' @noRd
date_with_offset <- function(text, format, offset_h) {
  t <- as.POSIXct(text, format = format, tz = "UTC")
  offset_h[is.na(offset_h)] <- 0
  t - offset_h * 3600
}
