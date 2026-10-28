# Synthetic AudioMoth card for the tests: CONFIG.TXT (format of firmware
# 1.12.1) and two daily folders with short WAV files written byte by byte,
# with the ICMT comment (and optionally GUANO) that AudioMoth writes. The
# device ID and the location are fictitious.

device <- "FACADE0012345678"

config_txt <- function(location = TRUE, rate = 48000, device_time = TRUE) {
  c(
    sprintf("Device ID                       : %s", device),
    "Firmware                        : AudioMoth-Firmware-Basic (1.12.1)",
    "",
    if (device_time) "Device time                     : 2026-10-05 19:46:26 (UTC)" else "Time zone                       : UTC+2",
    "",
    sprintf("Sample rate (Hz)                : %d", rate),
    "Gain                            : Medium",
    "",
    "Sleep duration (s)              : 240",
    "Recording duration (s)          : 60",
    "",
    if (location) "Location                        : 41.00°N 3.00°W (Configuration app)",
    if (location) "Sun recording mode              : Sunrise and sunset" else "Recording period 1              : 16:00 - 21:00 (UTC)",
    "",
    "First recording date            : 2026-10-06 (UTC)",
    "Last recording date             : 2026-10-30 (UTC)",
    "",
    "Filter                          : -",
    "Trigger type                    : -",
    "Use daily folder for WAV files  : Yes"
  )
}

u32 <- function(x) writeBin(as.integer(x), raw(), size = 4, endian = "little")
u16 <- function(x) writeBin(as.integer(x), raw(), size = 2, endian = "little")
chunk <- function(id, body) {
  c(charToRaw(id), u32(length(body)), body, if (length(body) %% 2) as.raw(0))
}

#' Writes a 16-bit PCM WAV file with optional INFO comment and GUANO block
write_wav <- function(path, duration = 8, rate = 48000, channels = 1, comment = NULL, guano = NULL,
                      samples = NULL, data_size = NULL) {
  if (is.null(samples)) {
    t <- seq(0, duration, length.out = round(duration * rate))
    samples <- round(8000 * sin(2 * pi * (2000 + 1500 * (t %% 1)) * t) + stats::rnorm(length(t), sd = 50))
    samples <- rep(samples, each = channels)
  }
  fmt <- c(u16(1), u16(channels), u32(rate), u32(rate * 2 * channels), u16(2 * channels), u16(16))
  data <- writeBin(as.integer(samples), raw(), size = 2, endian = "little")
  body <- c(charToRaw("WAVE"), chunk("fmt ", fmt))
  if (!is.null(comment)) {
    text <- c(charToRaw(comment), as.raw(0))
    body <- c(body, chunk("LIST", c(charToRaw("INFO"), chunk("ICMT", text))))
  }
  data_chunk <- chunk("data", data)
  if (!is.null(data_size)) data_chunk[5:8] <- u32(data_size)
  body <- c(body, data_chunk)
  if (!is.null(guano)) body <- c(body, chunk("guan", charToRaw(guano)))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(c(charToRaw("RIFF"), u32(length(body)), body), path)
  invisible(path)
}

#' The comment written by the AudioMoth firmware
am_comment <- function(time, offset = "UTC", battery = "4.7V", temperature = "12.5C", id = device) {
  sprintf("Recorded at %s (%s) by AudioMoth %s at medium gain while battery was %s and temperature was %s.",
          format(time, "%H:%M:%S %d/%m/%Y", tz = "UTC"), offset, id, battery, temperature)
}

make_card <- function(location = TRUE, rate = 48000, comments = TRUE) {
  dir <- tempfile("card_")
  dir.create(dir)
  con <- file(file.path(dir, "CONFIG.TXT"), "wb")
  writeLines(enc2utf8(config_txt(location, rate)), con, sep = "\r\n", useBytes = TRUE)
  close(con)
  for (day in c("20261010", "20261011")) {
    for (h in c("060000", "060500")) {
      start <- as.POSIXct(paste(day, h), format = "%Y%m%d %H%M%S", tz = "UTC")
      write_wav(file.path(dir, day, sprintf("%s_%s_%s.WAV", device, day, h)), rate = rate,
                comment = if (comments) am_comment(start))
    }
  }
  # Empty file (full card or interrupted recording)
  file.create(file.path(dir, "20261011", sprintf("%s_20261011_061000.WAV", device)))
  dir
}

read_card <- function(dir = make_card(), coordinates = "41.00, -3.00", output = file.path(dir, "results"), ...) {
  suppressMessages(read_audiomoth(dir, coordinates = coordinates, output = output, ...))
}

# --- BirdNET mock --------------------------------------------------------------
# What the mock "hears" in each file (by start second); every file not listed
# returns nothing.

mock_predictions <- data.frame(
  file = c("20261010_060000", "20261010_060000", "20261010_060000", "20261010_060500",
           "20261011_060000", "20261011_060000", "20261011_060500"),
  start = c(0, 0, 3, 3, 0, 3, 3),
  end = c(3, 3, 6, 6, 3, 6, 6),
  scientific_name = c("Cettia cetti", "Troglodytes troglodytes", "Cettia cetti", "Cettia cetti",
                      "Cettia cetti", "Human vocal", "Turdus merula"),
  confidence = c(0.95, 0.30, 0.90, 0.88, 0.70, 0.90, 0.60),
  stringsAsFactors = FALSE
)

mock_labels <- data.frame(
  label = c("Cettia cetti_Cetti's Warbler", "Troglodytes troglodytes_Eurasian Wren",
            "Turdus merula_Eurasian Blackbird", "Human vocal_Human vocal", "Corvus monedula_Eurasian Jackdaw"),
  scientific_name = c("Cettia cetti", "Troglodytes troglodytes", "Turdus merula", "Human vocal", "Corvus monedula"),
  common_name = c("Cetti's Warbler", "Eurasian Wren", "Eurasian Blackbird", "Human vocal", "Eurasian Jackdaw"),
  stringsAsFactors = FALSE
)

#' Runs `code` with birdnetR replaced by the mock; `calls` counts the files
#' analysed and `fail` makes the files matching it fail
with_mock_birdnet <- function(code, fail = NULL, calls = new.env(), scores = 0.5) {
  calls$n <- 0
  testthat::local_mocked_bindings(
    bn_prepare = function(...) invisible(),
    bn_load_model = function(...) list(),
    bn_load_meta = function(...) list(),
    bn_labels = function(model, language) mock_labels,
    bn_location_scores = function(meta, lat, lon, week, min_confidence) {
      data.frame(label = mock_labels$label[1:3], confidence = rep(scores, 3))
    },
    bn_predict = function(model, path, min_confidence, overlap, sensitivity, filter) {
      calls$n <- calls$n + 1
      if (!is.null(fail) && grepl(fail, path)) stop("cannot read the audio")
      key <- sub("^[0-9A-F]{16}_", "", tools::file_path_sans_ext(basename(path)))
      p <- mock_predictions[mock_predictions$file == key & mock_predictions$confidence >= min_confidence, -1]
      p$common_name <- p$scientific_name
      p
    },
    .package = "AudiomothR"
  )
  code
}

analysed_card <- function(...) {
  am <- read_card()
  with_mock_birdnet(suppressMessages(suppressWarnings(analyze_birdnet(am, language = "en_us", ...))))
}

skip_if_no_ffmpeg <- function() {
  testthat::skip_if(inherits(try(AudiomothR:::ffmpeg_path(), silent = TRUE), "try-error"),
                    "ffmpeg is not installed")
}

example_card <- function() system.file("extdata", "example", "card", package = "AudiomothR")
example_detections <- function() {
  read_detections(system.file("extdata", "example", "birdnet_detections.csv", package = "AudiomothR"))
}
