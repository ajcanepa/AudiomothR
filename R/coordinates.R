# Reading coordinates typed by hand or copied from Google Earth, Google Maps,
# a handheld GPS or a field notebook.
#
# The text is normalised (typographic symbols, minus signs, hemisphere words)
# and then read in blocks: each coordinate is a group of 1 to 3 numbers
# (degrees, minutes, seconds) with an optional hemisphere letter before or
# after it. Anything that cannot be read unambiguously is an error: a wrong
# location silently changes the BirdNET species filter and the records sent
# to Observation.org.

#' Reads coordinates in any of the usual formats
#'
#' Meant for copying and pasting the position of a point from Google Earth,
#' Google Maps or a GPS. Recognises:
#'
#' | Format | Example |
#' |---|---|
#' | Decimal degrees (Google Maps / Earth) | `"41.123456, -3.123456"` |
#' | Degrees, minutes and seconds | `"41°07'24.4\"N 3°07'24.4\"W"` |
#' | Spanish hemisphere letters (O = west) | `"41°07'24.4\"N 3°07'24.4\"O"` |
#' | Degrees and decimal minutes | `"41°07.407'N 3°07.407'W"` |
#' | Hemisphere first (handheld GPS) | `"N41 07.407 W3 07.407"` |
#' | Hemisphere words | `"41.1234 North, 3.1234 West"` |
#' | Without symbols | `"41 07 24.4 N 3 07 24.4 W"` |
#' | Google Earth placemark (KML) | `"<coordinates>-3.1234,41.1234,0</coordinates>"` |
#' | Google Maps link (marked point) | `"https://www.google.com/maps?q=41.1234,-3.1234"` |
#' | Decimal comma | `"41,123456 -3,123456"` |
#' | Numeric vector | `c(41.123456, -3.123456)` or `c(lon = -3.1, lat = 41.1)` |
#'
#' Without hemisphere letters the **latitude goes first** (as in Google) and
#' a negative longitude is west. Typographic minus signs and quotes (copied
#' from PDF or Word documents) are accepted. Texts that do not contain
#' coordinates (short links, Plus Codes, notes) are rejected.
#'
#' @param text Text with the coordinates, or a numeric vector
#'   `c(latitude, longitude)` (named `c(lat = , lon = )` in any order).
#' @return A list with `lat`, `lon` (decimal degrees, WGS84) and
#'   `precision_m`: approximate uncertainty (metres) due to the number of
#'   decimals written.
#' @examples
#' parse_coordinates("41.123456, -3.123456")
#' parse_coordinates("41°07'24.4\"N 3°07'24.4\"O")
#' parse_coordinates("N41 07.407 W3 07.407")
#' parse_coordinates(c(41.12, -3.12))
#' @export
parse_coordinates <- function(text) {
  if (is.numeric(text)) return(parse_numeric_coordinates(text))
  if (!is.character(text) || length(text) != 1 || is.na(text) || !nzchar(trimws(text))) {
    abort("The coordinates must be a text, e.g. {.val 41.123456, -3.123456}, or {.code c(latitude, longitude)}.")
  }
  original <- text
  t <- normalise_coordinate_text(text)

  if (grepl("^https?://|google\\.[a-z.]+/maps|maps\\.app\\.goo\\.gl|goo\\.gl/maps", t, ignore.case = TRUE)) {
    return(coordinates_from_url(t, original))
  }

  # Google Earth placemark (KML): longitude,latitude[,altitude] (one tuple per point)
  kml <- regmatches(t, regexec("<coordinates>\\s*([^<]+)</coordinates>", t))[[1]]
  if (length(kml)) {
    tuples <- strsplit(trimws(kml[2]), "\\s+")[[1]]
    if (length(tuples) > 1) inform("i" = "The KML has {length(tuples)} points; the first one is used.")
    parts <- strsplit(tuples[1], ",", fixed = TRUE)[[1]]
    if (length(parts) < 2) abort("Cannot read the KML coordinates {.val {cli_escape(original)}}.")
    return(check_coordinates(suppressWarnings(as.numeric(parts[2])), suppressWarnings(as.numeric(parts[1])),
                             decimal_step(parts[1:2]), original))
  }

  t <- toupper(t)
  # A label before a colon ("Box 2: 41.12, -3.12") and words that only label the values
  t <- sub("^[^:]*[A-Z][^:]*:\\s*(?=[-+0-9NSEWO])", "", t, perl = TRUE)
  t <- gsub("\\b(LAT(ITUD|ITUDE)?|LON(G|GITUD|GITUDE)?|LNG)\\b\\s*[:=]?", " ", t, perl = TRUE)
  t <- gsub("\\b(NORTE|NORTH)\\b", "N", t, perl = TRUE)
  t <- gsub("\\b(SUR|SOUTH)\\b", "S", t, perl = TRUE)
  t <- gsub("\\b(ESTE|EAST)\\b", "E", t, perl = TRUE)
  t <- gsub("\\b(OESTE|WEST)\\b", "W", t, perl = TRUE)

  if (grepl("(?<![A-Z])[NSEWO](?![A-Z])", t, perl = TRUE)) {
    return(coordinates_with_hemispheres(t, original))
  }
  coordinates_without_hemispheres(t, original)
}

#' Coordinates given as a numeric vector
#' @noRd
parse_numeric_coordinates <- function(x) {
  if (length(x) != 2) abort("Give the coordinates as {.code c(latitude, longitude)}.")
  nm <- tolower(names(x) %||% c("", ""))
  nm[nm %in% c("latitude", "latitud")] <- "lat"
  nm[nm %in% c("long", "lng", "longitude", "longitud")] <- "lon"
  if (setequal(nm, c("lat", "lon"))) x <- x[match(c("lat", "lon"), nm)]
  # The precision follows from the decimals actually written, as with text
  digits <- vapply(x, function(v) format(v, digits = 15, scientific = FALSE), character(1))
  check_coordinates(unname(x[1]), unname(x[2]), decimal_step(digits), paste(x, collapse = ", "))
}

#' Typographic symbols, minus signs and quotes to plain ASCII
#' @noRd
normalise_coordinate_text <- function(x) {
  x <- enc2utf8(x)
  x <- gsub("[\u2212\u2010\u2011\u2012\u2013\u2014\u2015\ufe63\uff0d]", "-", x)  # minus signs and dashes
  x <- gsub("[\u00ba\u02da]", "\u00b0", x)                           # degree sign look-alikes
  x <- gsub("(\u2033|\u201c|\u201d|'')", "\"", x)                           # double quotes, seconds
  x <- gsub("[\u2032\u2018\u2019\u00b4`]", "'", x)                           # single quotes, minutes
  trimws(x)
}

#' Coordinates in a Google Maps link
#' @noRd
coordinates_from_url <- function(t, original) {
  u <- utils::URLdecode(t)
  num <- "(-?[0-9]+(?:\\.[0-9]+)?)"
  # The marked point: "!3d<lat>!4d<lon>" or a query such as "?q=<lat>,<lon>"
  patterns <- c(paste0("!3d", num, "!4d", num),
                paste0("[?&](?:q|ll|query|destination)=", num, ",\\s*", num))
  for (p in patterns) {
    m <- regmatches(u, regexec(p, u, perl = TRUE))[[1]]
    if (length(m)) return(check_coordinates(as.numeric(m[2]), as.numeric(m[3]), decimal_step(m[2:3]), original))
  }
  # ".../place/<coordinates>/@...": the coordinates of the place, as written
  place <- regmatches(u, regexec("/place/([^/@]+)", u))[[1]]
  if (length(place)) {
    text <- gsub("+", " ", place[2], fixed = TRUE)
    res <- tryCatch(parse_coordinates(text), error = function(e) NULL)
    if (!is.null(res)) return(res)
  }
  # "@<lat>,<lon>,<zoom>z" is only the centre of the map view, not the point
  abort("This link does not contain the coordinates of a point: {.val {cli_escape(original)}}.",
        "i" = "The numbers after {.val @} in a Google Maps link are the centre of the map view, and short links ({.url maps.app.goo.gl}) only point to a place.",
        "i" = "Click the point in Google Maps and copy the numbers shown (e.g. {.val 41.123456, -3.123456}).")
}

#' Numbers of a text. Decimal commas are accepted when they are the only way
#' of reading the text as the expected number of values.
#' @noRd
coordinate_numbers <- function(t, decimal_comma) {
  if (decimal_comma) t <- gsub("([0-9]),([0-9])", "\\1.\\2", t)
  regmatches(t, gregexpr("[-+]?[0-9]+(?:\\.[0-9]+)?", t, perl = TRUE))[[1]]
}

#' Coordinates with hemisphere letters (before or after the numbers)
#' @noRd
coordinates_with_hemispheres <- function(t, original) {
  leftover <- gsub("(?<![A-Z])[NSEWO](?![A-Z])", " ", t, perl = TRUE)
  if (grepl("[A-Z]", leftover)) {
    abort("Cannot read the coordinates {.val {cli_escape(original)}}: they contain text that is not a hemisphere (N/S/E/W/O).")
  }
  # Tokens in order: numbers and hemisphere letters
  decimal_comma <- !grepl(".", t, fixed = TRUE)
  tt <- if (decimal_comma) gsub("([0-9]),([0-9])", "\\1.\\2", t) else t
  tokens <- regmatches(tt, gregexpr("[-+]?[0-9]+(?:\\.[0-9]+)?|(?<![A-Z])[NSEWO](?![A-Z])", tt, perl = TRUE))[[1]]
  is_letter <- grepl("^[NSEWO]$", tokens)
  if (sum(is_letter) != 2) {
    abort("Cannot read the coordinates {.val {cli_escape(original)}}: there must be one hemisphere for the latitude (N/S) and one for the longitude (E/W/O).")
  }
  # Hemisphere before the numbers (GPS: "N41 07.407 W3 07.407") or after them
  prefix <- is_letter[1]
  group <- if (prefix) cumsum(is_letter) else rev(cumsum(rev(is_letter)))
  if (any(group == 0)) {
    abort("Cannot read the coordinates {.val {cli_escape(original)}}: there are numbers after the last hemisphere.")
  }
  blocks <- lapply(1:2, function(k) tokens[group == k])
  if (!all(vapply(blocks, function(b) sum(grepl("^[NSEWO]$", b)) == 1 && length(b) %in% 2:4, logical(1)))) {
    abort("Cannot read the coordinates {.val {cli_escape(original)}}: each one must have 1 to 3 numbers (degrees, minutes, seconds) and a hemisphere.")
  }
  values <- lapply(blocks, function(b) {
    hemisphere <- b[grepl("^[NSEWO]$", b)]
    v <- dms_value(b[!grepl("^[NSEWO]$", b)], original)
    if (v$negative && hemisphere %in% c("S", "W", "O")) {
      abort("The coordinates {.val {cli_escape(original)}} have both a minus sign and a hemisphere S/W.")
    }
    v$value <- abs(v$value) * if (v$negative || hemisphere %in% c("S", "W", "O")) -1 else 1
    v$is_lat <- hemisphere %in% c("N", "S")
    v
  })
  is_lat <- vapply(values, `[[`, logical(1), "is_lat")
  if (sum(is_lat) != 1) {
    abort("Cannot tell the latitude from the longitude in {.val {cli_escape(original)}}.",
          "i" = "Use N/S for the latitude and E/W (or O) for the longitude.")
  }
  lat <- values[[which(is_lat)]]
  lon <- values[[which(!is_lat)]]
  check_coordinates(lat$value, lon$value, max(lat$step, lon$step), original)
}

#' Coordinates without hemisphere letters: latitude first
#' @noRd
coordinates_without_hemispheres <- function(t, original) {
  if (grepl("[A-Z]", t)) {
    abort("Cannot read the coordinates {.val {cli_escape(original)}}.",
          "i" = "Valid examples: {.val 41.123456, -3.123456} or {.val 41\u00b007'24.4\"N 3\u00b007'24.4\"W}.",
          "i" = "Plus Codes and place names are not accepted.")
  }
  numbers <- coordinate_numbers(t, FALSE)
  decimal_comma <- FALSE
  if (!length(numbers) %in% c(2, 4, 6) || (length(numbers) > 2 && !grepl("[\u00b0'\"]", t) &&
                                           length(coordinate_numbers(t, TRUE)) == 2)) {
    alt <- coordinate_numbers(t, TRUE)
    if (length(alt) %in% c(2, 4, 6)) {
      numbers <- alt
      decimal_comma <- TRUE
    }
  }
  if (!length(numbers) %in% c(2, 4, 6)) {
    abort("Cannot read the coordinates {.val {cli_escape(original)}}.",
          "i" = "Valid examples: {.val 41.123456, -3.123456} or {.val 41\u00b007'24.4\"N 3\u00b007'24.4\"W}.")
  }
  if (length(numbers) == 2) {
    if (!all(grepl(".", numbers, fixed = TRUE))) {
      abort("{.val {cli_escape(original)}} has whole numbers only: it does not look like coordinates.",
            "i" = "Write them with decimals ({.val 41.12, -3.12}) or as {.code c(latitude, longitude)}.")
    }
    groups <- list(numbers[1], numbers[2])
  } else {
    # Degrees, minutes and seconds: split where a degree sign starts a group,
    # at the separator between both coordinates or in half
    tt <- if (decimal_comma) gsub("([0-9]),([0-9])", "\\1.\\2", t) else t
    pieces <- regmatches(tt, gregexpr("[-+]?[0-9]+(?:\\.[0-9]+)?\\s*\u00b0?|[,;]", tt, perl = TRUE))[[1]]
    starts <- grepl("\u00b0", pieces)
    if (sum(starts) == 2) {
      groups <- split(numbers, cumsum(starts[!pieces %in% c(",", ";")]))
    } else if (any(pieces %in% c(",", ";"))) {
      first <- sum(!pieces[seq_len(which(pieces %in% c(",", ";"))[1])] %in% c(",", ";"))
      groups <- list(numbers[seq_len(first)], numbers[-seq_len(first)])
    } else {
      groups <- split(numbers, rep(1:2, each = length(numbers) / 2))
    }
    if (length(groups) != 2 || any(!lengths(groups) %in% 1:3)) {
      abort("Cannot read the coordinates {.val {cli_escape(original)}}: write each one as degrees, minutes and seconds.")
    }
  }
  values <- lapply(groups, dms_value, original = original)
  check_coordinates(values[[1]]$value, values[[2]]$value,
                    max(values[[1]]$step, values[[2]]$step), original)
}

#' Decimal degrees from 1 to 3 numbers (degrees, minutes, seconds)
#' @noRd
dms_value <- function(parts, original) {
  x <- as.numeric(parts)
  negative <- startsWith(parts[1], "-")
  decimals <- function(p) if (grepl(".", p, fixed = TRUE)) nchar(sub("^.*\\.", "", p)) else 0
  if (length(x) > 1 && any(vapply(parts[-length(parts)], decimals, numeric(1)) > 0)) {
    abort("In {.val {cli_escape(original)}} only the last component (degrees, minutes or seconds) can have decimals.")
  }
  if (any(x[-1] >= 60) || any(x[-1] < 0)) {
    abort("Minutes and seconds must be between 0 and 59 in {.val {cli_escape(original)}}.")
  }
  value <- abs(x[1]) + sum(x[-1] / c(60, 3600)[seq_along(x[-1])])
  step <- 10^-decimals(parts[length(parts)]) / c(1, 60, 3600)[length(parts)]
  list(value = if (negative) -value else value, negative = negative, step = step)
}

#' Resolution (degrees) of the decimal values written
#' @noRd
decimal_step <- function(x) {
  x <- trimws(x)
  dec <- ifelse(grepl("[.]", x), nchar(sub("^.*[.]", "", x)), 0)
  max(10^-dec)
}

#' Checks the range of a location and computes its precision
#' @noRd
check_coordinates <- function(lat, lon, step_degrees, original) {
  original <- paste(original, collapse = ", ")
  if (length(lat) != 1 || length(lon) != 1 || anyNA(c(lat, lon))) {
    abort("The latitude or the longitude is missing in {.val {cli_escape(original)}}.")
  }
  if (abs(lat) > 90 || abs(lon) > 180) {
    abort("Coordinates out of range: {.val {cli_escape(original)}}.",
          "i" = "The latitude must be between -90 and 90 and the longitude between -180 and 180.")
  }
  # Maximum rounding error: half a step on each axis (1 degree ~ 111.32 km)
  precision <- 111320 * step_degrees / 2 * sqrt(1 + cos(lat * pi / 180)^2)
  list(lat = round(lat, 6), lon = round(lon, 6),
       precision_m = max(1L, as.integer(ceiling(precision))))
}

#' Great-circle distance in km between two locations (lists with lat and lon)
#' @noRd
distance_km <- function(a, b) {
  r <- pi / 180
  x <- sin(a$lat * r) * sin(b$lat * r) + cos(a$lat * r) * cos(b$lat * r) * cos((a$lon - b$lon) * r)
  6371 * acos(min(1, max(-1, x)))
}

#' OpenStreetMap link to check a location
#' @noRd
map_link <- function(lat, lon) {
  sprintf("https://www.openstreetmap.org/?mlat=%s&mlon=%s#map=15/%s/%s", lat, lon, lat, lon)
}
