# Reading the header and metadata of WAV files without loading the audio
# (adapted from Biosonora, fct_wav_metadata.R and fct_audiomoth.R).
#
# A WAV file is a "RIFF" container made of chunks:
#   - "fmt " : format (channels, sample rate, bits)
#   - "data" : the audio samples (the only chunk NOT read here)
#   - "LIST" : INFO metadata (AudioMoth writes its ICMT comment here)
#   - "guan" : GUANO metadata (recent firmware: exact battery voltage...)

# Largest metadata chunk that is read
max_metadata_chunk <- 1024 * 1024

#' Reads the header of a WAV file
#'
#' @return A list with channels, sample_rate, bits, format, data_bytes,
#'   data_start, duration_s, incomplete_header, info (INFO metadata) and guano
#'   (GUANO metadata), or NULL when the file is not a readable WAV.
#' @noRd
read_wav_header <- function(path) {
  size <- file.size(path)
  if (is.na(size) || size < 44) return(NULL)
  con <- file(path, "rb")
  on.exit(close(con))
  riff <- read_fourcc(con)
  readBin(con, "integer", size = 4, endian = "little")
  wave <- read_fourcc(con)
  if (!identical(riff, "RIFF") || !identical(wave, "WAVE")) return(NULL)

  out <- list(channels = NA_integer_, sample_rate = NA_integer_, bits = NA_integer_,
              format = NA_integer_, data_bytes = NA_real_, data_start = NA_real_,
              incomplete_header = FALSE, info = list(), guano = list())
  pos <- 12
  while (pos + 8 <= size) {
    seek(con, pos)
    id <- read_fourcc(con)
    chunk_size <- read_uint32(con)
    start <- pos + 8
    if (identical(id, "data")) {
      # The firmware first writes a header with data = 0 and rewrites it when
      # the recording ends; an interrupted recording may keep the first one
      # (or declare more data than the file holds)
      if (chunk_size == 0 || chunk_size == 4294967295) {
        chunk_size <- size - start
        out$incomplete_header <- TRUE
      }
      out$data_bytes <- min(chunk_size, size - start)
      out$data_start <- start
      if (is.na(out$sample_rate)) break
    } else if (chunk_size <= max_metadata_chunk) {
      body <- readBin(con, "raw", n = chunk_size)
      if (identical(id, "fmt ") && length(body) >= 16) {
        out$format <- as.integer(raw_uint(body[1:2]))
        out$channels <- as.integer(raw_uint(body[3:4]))
        out$sample_rate <- as.integer(raw_uint(body[5:8]))
        out$bits <- as.integer(raw_uint(body[15:16]))
      } else if (identical(id, "LIST")) {
        out$info <- c(out$info, read_list_info(body))
      } else if (identical(id, "guan")) {
        out$guano <- read_guano(body)
      }
    }
    # Chunks of odd size carry a padding byte
    pos <- start + chunk_size + (chunk_size %% 2)
  }
  if (is.na(out$sample_rate) || is.na(out$data_bytes) || is.na(out$channels) || out$channels == 0) {
    return(NULL)
  }
  bytes_per_sample <- out$channels * ceiling(out$bits / 8)
  out$duration_s <- floor(out$data_bytes / bytes_per_sample) / out$sample_rate
  out
}

read_fourcc <- function(con) {
  b <- readBin(con, "raw", n = 4)
  if (length(b) < 4) return("")
  b[b == as.raw(0)] <- as.raw(32)
  rawToChar(b)
}

read_uint32 <- function(con) {
  b <- as.numeric(readBin(con, "raw", n = 4))
  if (length(b) < 4) return(0)
  sum(b * 256^(0:3))
}

raw_uint <- function(b) sum(as.numeric(b) * 256^(seq_along(b) - 1))

raw_to_text <- function(b) {
  b <- b[b != as.raw(0)]
  if (length(b) == 0) return("")
  txt <- rawToChar(b)
  Encoding(txt) <- "UTF-8"
  if (!validUTF8(txt)) txt <- iconv(txt, from = "latin1", to = "UTF-8", sub = "")
  trimws(txt)
}

#' INFO list: pairs of key (4 letters) and text
#' @noRd
read_list_info <- function(body) {
  if (length(body) < 4 || !identical(rawToChar(body[1:4]), "INFO")) return(list())
  res <- list()
  i <- 5
  while (i + 7 <= length(body)) {
    key <- raw_to_text(body[i:(i + 3)])
    size <- raw_uint(body[(i + 4):(i + 7)])
    end <- min(i + 7 + size, length(body))
    res[[key]] <- if (size > 0) raw_to_text(body[(i + 8):end]) else ""
    i <- i + 8 + size + (size %% 2)
  }
  res
}

#' GUANO metadata: "key:value" lines ("OAD|Battery Voltage:4.9")
#' @noRd
read_guano <- function(body) {
  lines <- strsplit(raw_to_text(body), "\n", fixed = TRUE)[[1]]
  lines <- lines[grepl(":", lines, fixed = TRUE)]
  keys <- sub("^(?:[^|:]*\\|)?([^:]*):.*$", "\\1", lines, perl = TRUE)
  stats::setNames(as.list(trimws(sub("^[^:]*:", "", lines))), trimws(keys))
}

#' Parses AudioMoth file names
#'
#' Formats: "YYYYMMDD_HHMMSS.WAV" and "DEVICEID_YYYYMMDD_HHMMSS.WAV" (the
#' prefix is the deployment ID when one was set). A "T" before the extension
#' marks a triggered recording (amplitude or frequency threshold). Any other
#' text before the extension (e.g. " 2" of a copy) is returned in `suffix`.
#' @noRd
parse_audiomoth_name <- function(name) {
  pattern <- "^(?:([0-9A-Fa-f]{16})_)?([0-9]{8}_[0-9]{6})(T?)(.*)\\.wav$"
  m <- regmatches(name, regexec(pattern, name, ignore.case = TRUE, perl = TRUE))
  part <- function(k) vapply(m, function(x) if (length(x) && nzchar(x[k])) x[k] else NA_character_, "")
  data.frame(
    prefix_id = toupper(part(2)),
    date_text = part(3),
    triggered = !is.na(part(4)),
    suffix = ifelse(lengths(m) > 0, ifelse(is.na(part(5)), "", part(5)), NA_character_),
    stringsAsFactors = FALSE
  )
}

#' Parses the comment (ICMT) that AudioMoth writes in each WAV (vectorised)
#'
#' Examples:
#' "Recorded at 04:20:00 10/10/2026 (UTC) by AudioMoth FACADE0012345678 at
#' medium gain while battery was 4.7V and temperature was 6.7C."
#' "Recorded at 06:20:00 10/10/2026 (UTC+2) during deployment
#' 0123456789ABCDEF at high gain while battery was less than 3.6V and
#' temperature was -1.5C. Amplitude threshold was 1000."
#' Each field is extracted separately because the sentence changes between
#' firmware versions.
#' @noRd
parse_audiomoth_comment <- function(comment) {
  comment <- as.character(comment)
  comment[is.na(comment) | !grepl("^Recorded at", comment)] <- NA_character_
  get <- function(pattern) {
    m <- regmatches(comment, regexec(pattern, comment, perl = TRUE))
    vapply(m, function(x) if (length(x) > 1) x[2] else NA_character_, "")
  }
  when <- regmatches(comment, regexec("^Recorded at ([0-9:]{8}) ([0-9/]{10}) \\((UTC[^)]*)\\)", comment))
  start <- vapply(when, function(x) if (length(x)) paste(x[3], x[2]) else NA_character_, "")
  offset <- vapply(when, function(x) if (length(x)) utc_offset(x[4]) else NA_real_, numeric(1))
  battery_text <- get("battery (?:state )?was ((?:less than |greater than )?[0-9.]+)V")
  data.frame(
    start_utc = date_with_offset(start, "%d/%m/%Y %H:%M:%S", offset),
    device_id = toupper(get("by AudioMoth ([0-9A-Fa-f]{16})")),
    deployment_id = toupper(get("during deployment ([0-9A-Fa-f]{16})")),
    gain = get("at ([a-z -]+) gain"),
    # "4.7V", "less than 2.5V" or "greater than 4.9V": the number and the limit
    battery_v = suppressWarnings(as.numeric(sub("^[a-z ]+", "", battery_text))),
    battery_limit = ifelse(grepl("^less", battery_text), "<",
                           ifelse(grepl("^greater", battery_text), ">", NA_character_)),
    temperature_c = suppressWarnings(as.numeric(get("temperature was (-?[0-9.]+)C"))),
    threshold = grepl("threshold", comment, ignore.case = TRUE),
    stringsAsFactors = FALSE
  )
}

# --- Triggered recordings (T.WAV) --------------------------------------------
#
# With an amplitude or frequency threshold, the firmware replaces each silent
# stretch by a single block of 256 samples (512 bytes) whose first 32 samples
# encode, bit by bit (least significant first, +1 = 1 and -1 = 0), how many
# blocks of 256 samples were skipped; the remaining 224 samples are 0
# (AudioMoth-Firmware-Basic, main.c: encodeCompressionBuffer). The audio must
# be expanded before analysis so that the times of the detections are right.

triggered_block <- 256L

#' Blocks of a triggered recording
#'
#' The firmware writes the audio in buffers of 512 bytes aligned with the
#' file, not with the start of the data: with the usual header of 488 bytes,
#' the first block starts 12 samples into the data.
#' @return Data frame with the position of each compressed block (`start`, in
#'   samples from 0) and the number of 256-sample blocks it stands for
#'   (`blocks`).
#' @noRd
triggered_markers <- function(samples, data_start) {
  first <- ((512 - data_start %% 512) %% 512) %/% 2
  if (length(samples) < first + triggered_block) return(data.frame(start = numeric(), blocks = numeric()))
  starts <- seq(first, length(samples) - triggered_block, by = triggered_block)
  head <- matrix(samples[outer(0:31, starts, "+") + 1], nrow = 32)
  candidates <- starts[colSums(abs(head) == 1) == 32]
  rest <- matrix(samples[outer(32:(triggered_block - 1), candidates, "+") + 1], nrow = triggered_block - 32)
  markers <- candidates[colSums(rest != 0) == 0]
  bits <- matrix(samples[outer(0:31, markers, "+") + 1] == 1, nrow = 32)
  data.frame(start = markers, blocks = pmax(1, colSums(bits * 2^(0:31))))
}

#' Reads the 16-bit mono samples of a WAV file
#' @noRd
read_pcm16 <- function(path, header = read_wav_header(path)) {
  if (is.null(header) || header$bits != 16 || header$channels != 1 || !header$format %in% c(1L, 65534L)) {
    abort("{.file {path}} is not a 16-bit mono PCM WAV file.")
  }
  con <- file(path, "rb")
  on.exit(close(con))
  seek(con, header$data_start)
  readBin(con, "integer", n = header$data_bytes %/% 2, size = 2, signed = TRUE, endian = "little")
}

#' Real duration (s) of a triggered recording, silences included
#' @noRd
triggered_duration <- function(path, header) {
  samples <- tryCatch(read_pcm16(path, header), error = function(e) NULL)
  if (is.null(samples)) return(header$duration_s)
  m <- triggered_markers(samples, header$data_start)
  (length(samples) + sum(m$blocks - 1) * triggered_block) / header$sample_rate
}

#' Writes the expanded version of a triggered recording (silences restored)
#'
#' Each compressed block is replaced by the silence it stands for. The file
#' is written in pieces (a silence may last hours) under a temporary name.
#' @noRd
expand_triggered_wav <- function(path, dest) {
  header <- read_wav_header(path)
  samples <- read_pcm16(path, header)
  m <- triggered_markers(samples, header$data_start)
  n <- length(samples) + sum(m$blocks - 1) * triggered_block
  if (2 * n + 36 > 4294967295) abort("{.file {path}} is too long to be expanded into a WAV file.")
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".part")
  con <- file(tmp, "wb")
  on.exit({ close(con); unlink(tmp) })
  u32 <- function(v) writeBin(as.integer(v - if (v > .Machine$integer.max) 2^32 else 0), con, size = 4, endian = "little")
  u16 <- function(v) writeBin(as.integer(v), con, size = 2, endian = "little")
  rate <- header$sample_rate
  writeChar("RIFF", con, eos = NULL); u32(36 + 2 * n); writeChar("WAVE", con, eos = NULL)
  writeChar("fmt ", con, eos = NULL); u32(16); u16(1); u16(1); u32(rate); u32(2 * rate); u16(2); u16(16)
  writeChar("data", con, eos = NULL); u32(2 * n)
  put <- function(v) if (length(v)) writeBin(as.integer(v), con, size = 2, endian = "little")
  from <- 1
  for (k in seq_len(nrow(m))) {
    put(samples[seq.int(from, length.out = m$start[k] + 1 - from)])
    silence <- m$blocks[k] * triggered_block
    while (silence > 0) {
      piece <- min(silence, 2^20)
      put(integer(piece))
      silence <- silence - piece
    }
    from <- m$start[k] + triggered_block + 1
  }
  put(samples[seq.int(from, length.out = length(samples) + 1 - from)])
  close(con)
  on.exit(unlink(tmp))
  if (!file.rename(tmp, dest)) abort("Cannot write {.file {dest}}.")
  invisible(dest)
}
