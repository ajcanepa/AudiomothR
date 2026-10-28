# Spectrograms (PNG) and videos of the spectrogram with the audio (MP4).

#' Spectrogram (STFT) of a Wave object
#'
#' Uses seewave::spectro() when seewave is installed; otherwise an
#' equivalent calculation of its own (Hann window).
#' @param wave Mono `Wave` object of tuneR.
#' @param resolution_hz Approximate frequency resolution (Hz).
#' @param overlap Overlap between windows (0-1).
#' @param max_freq Highest frequency (Hz) that is kept.
#' @return A list with `time` (s), `frequency` (Hz) and `db` (matrix
#'   frequency x time, in dB relative to the maximum).
#' @noRd
compute_spectrogram <- function(wave, resolution_hz = 47, overlap = 0.875, max_freq = 12000) {
  fs <- wave@samp.rate
  wl <- 2^round(log2(fs / resolution_hz))
  max_freq <- min(max_freq, fs / 2)
  if (requireNamespace("seewave", quietly = TRUE)) {
    s <- seewave::spectro(wave, f = fs, wl = wl, ovlp = 100 * overlap, plot = FALSE,
                          norm = TRUE, dB = "max0")
    keep <- s$freq * 1000 <= max_freq
    return(list(time = s$time, frequency = s$freq[keep] * 1000, db = s$amp[keep, , drop = FALSE]))
  }
  x <- as.numeric(wave@left)
  x <- x - mean(x)
  step <- max(1L, as.integer(round(wl * (1 - overlap))))
  if (length(x) < wl) x <- c(x, numeric(wl - length(x)))
  starts <- seq(1L, max(1L, length(x) - wl + 1L), by = step)
  hann <- 0.5 - 0.5 * cos(2 * pi * (seq_len(wl) - 1) / (wl - 1))
  frames <- vapply(starts, function(i) x[i:(i + wl - 1L)] * hann, numeric(wl))
  spectrum <- Mod(stats::mvfft(frames))[seq_len(wl / 2), , drop = FALSE]
  frequency <- (seq_len(wl / 2) - 1) * fs / wl
  keep <- frequency <= max_freq
  db <- 20 * log10(spectrum[keep, , drop = FALSE] + 1e-12)
  list(time = (starts - 1 + wl / 2) / fs, frequency = frequency[keep], db = db - max(db))
}

#' Raster of colours (rows = frequencies from top to bottom) for fast drawing
#' @noRd
spectrogram_raster <- function(spec, db_range = 70, palette = grDevices::hcl.colors(256, "viridis")) {
  z <- pmax(spec$db, -db_range)
  idx <- 1 + round((z + db_range) / db_range * (length(palette) - 1))
  m <- matrix(palette[idx], nrow = nrow(z))
  grDevices::as.raster(m[nrow(m):1, , drop = FALSE])
}

# Plot margins in pixels (with res = 72, 1 inch = 72 pixels), to know where
# the spectrogram area is when it is animated with ffmpeg
margins_px <- c(bottom = 75, left = 95, top = 95, right = 30)
cursor_colour <- "#FF5A36"
background_colour <- "#111418"

#' Common style of the plots
#' @noRd
plot_style <- function(mai_px = margins_px) {
  graphics::par(bg = background_colour, fg = "grey85", col.axis = "grey85", col.lab = "grey85",
                mai = mai_px / 72, cex = 1.25)
}

#' Draws a spectrogram (or just its frame) on the current graphics device
#' @param spectrum Draw the spectrogram and the time axis (FALSE = only the
#'   frame, the texts and the frequency axis).
#' @noRd
draw_spectrogram <- function(ras, spec, duration, title, subtitle, marks, spectrum = TRUE) {
  plot_style()
  fmax <- max(spec$frequency) / 1000
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, duration), ylim = c(0, fmax), xaxs = "i", yaxs = "i")
  if (spectrum) {
    graphics::rasterImage(ras, 0, 0, duration, fmax, interpolate = TRUE)
    if (length(marks) == 2) graphics::abline(v = marks, col = "white", lty = 2, lwd = 2)
    graphics::axis(1)
  }
  graphics::axis(2, las = 1)
  graphics::box()
  graphics::title(xlab = "Time (s)", ylab = "Frequency (kHz)")
  graphics::mtext(title, side = 3, line = 2.2, adj = 0, font = 2, cex = 1.35, col = "white")
  graphics::mtext(subtitle, side = 3, line = 0.6, adj = 0, cex = 0.95, col = "grey75")
}

#' Reads a WAV file and computes its spectrogram and colour raster
#' @noRd
prepare_spectrogram <- function(wav, max_freq, db_range) {
  if (!file.exists(wav)) abort("File {.file {wav}} does not exist.")
  wave <- mono_wave(tuneR::readWave(wav))
  spec <- compute_spectrogram(wave, max_freq = max_freq)
  list(spec = spec, ras = spectrogram_raster(spec, db_range), duration = length(wave@left) / wave@samp.rate)
}

check_spectrogram_args <- function(max_freq, db_range, width, height) {
  check_number(max_freq, "max_freq", 100)
  check_number(db_range, "db_range", 10, 200)
  check_number(width, "width", 320, 8000)
  check_number(height, "height", 240, 8000)
}

#' Saves the spectrogram of a WAV file as a PNG image
#'
#' @param wav Path of the WAV file (any sample rate; 8 to 32 bits).
#' @param file Output PNG file.
#' @param title,subtitle Texts of the heading.
#' @param marks Start and end (s) of the detection, marked with dashed lines.
#' @param max_freq Highest frequency shown (Hz).
#' @param db_range Dynamic range (dB) of the colour scale.
#' @param width,height Size in pixels.
#' @return Invisibly, the path of the PNG file.
#' @examples
#' wav <- tempfile(fileext = ".wav")
#' t <- seq(0, 2, length.out = 2 * 48000)
#' tuneR::writeWave(tuneR::Wave(round(8000 * sin(2 * pi * (2000 + 1000 * t) * t)),
#'                              samp.rate = 48000, bit = 16), wav)
#' spectrogram_image(wav, tempfile(fileext = ".png"), title = "Chirp")
#' @export
spectrogram_image <- function(wav, file, title = basename(wav), subtitle = "", marks = NULL,
                              max_freq = 12000, db_range = 70, width = 1280, height = 720) {
  check_spectrogram_args(max_freq, db_range, width, height)
  e <- prepare_spectrogram(wav, max_freq, db_range)
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(file, width = width, height = height, res = 72)
  on.exit(grDevices::dev.off())
  draw_spectrogram(e$ras, e$spec, e$duration, title, subtitle, marks)
  invisible(file)
}

#' Video of the spectrogram of a WAV file, in sync with its audio
#'
#' R draws the spectrogram once and ffmpeg animates it and adds the audio
#' (H.264 + AAC, playable in any player and on social media). Two styles:
#' - `"cursor"`: the whole spectrogram, with a line that moves at the pace of
#'   the sound.
#' - `"scroll"`: the spectrogram scrolls from right to left under a fixed
#'   line in the centre (`window_s` seconds are visible).
#'
#' @inheritParams spectrogram_image
#' @param file Output MP4 file.
#' @param style `"cursor"` or `"scroll"`.
#' @param fps Frames per second.
#' @param window_s Seconds visible in the `"scroll"` style.
#' @return Invisibly, the path of the MP4 file.
#' @examplesIf nzchar(Sys.which("ffmpeg"))
#' wav <- tempfile(fileext = ".wav")
#' t <- seq(0, 2, length.out = 2 * 48000)
#' tuneR::writeWave(tuneR::Wave(round(8000 * sin(2 * pi * (2000 + 1000 * t) * t)),
#'                              samp.rate = 48000, bit = 16), wav)
#' spectrogram_video(wav, tempfile(fileext = ".mp4"), title = "Chirp")
#' @export
spectrogram_video <- function(wav, file, title = basename(wav), subtitle = "", marks = NULL,
                              style = c("cursor", "scroll"), fps = 25, window_s = 3,
                              max_freq = 12000, db_range = 70, width = 1280, height = 720) {
  style <- check_choice(style, c("cursor", "scroll"), "style")
  check_number(fps, "fps", 1, 120)
  check_number(window_s, "window_s", 0.5, 60)
  check_spectrogram_args(max_freq, db_range, width, height)
  ffmpeg_path()
  width <- 2L * (as.integer(width) %/% 2L) # H.264 needs even sizes
  height <- 2L * (as.integer(height) %/% 2L)
  e <- prepare_spectrogram(wav, max_freq, db_range)
  tmp <- tempfile("video_")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  # Spectrogram area in pixels
  x0 <- margins_px[["left"]]
  y0 <- margins_px[["top"]]
  pw <- width - x0 - margins_px[["right"]]
  ph <- height - y0 - margins_px[["bottom"]]
  num <- function(x) format(round(x, 4), scientific = FALSE, trim = TRUE)
  background <- file.path(tmp, "background.png")
  grDevices::png(background, width = width, height = height, res = 72)
  draw_spectrogram(e$ras, e$spec, e$duration, title, subtitle, marks, spectrum = style == "cursor")
  grDevices::dev.off()

  inputs <- c("-loop", "1", "-framerate", fps, "-t", num(e$duration), "-i", background)
  line <- sprintf("color=c=0x%s:s=3x%d:r=%s", substring(cursor_colour, 2), ph, fps)
  if (style == "cursor") {
    # Line that moves from x0 to x0 + pw during the audio
    filter <- sprintf("%s[l];[0:v][l]overlay=x='%d+%d*t/%s-1':y=%d:shortest=1,format=yuv420p[v]",
                      line, x0, pw, num(e$duration), y0)
    audio <- "1:a"
  } else {
    # Strip with the whole spectrogram (plus half a window on each side),
    # decoded once and cropped to the visible window at each instant
    pps <- pw / window_s
    strip_height <- ph + 45L
    strip_width <- round((e$duration + window_s) * pps)
    if (strip_width > 32000) {
      abort("The recording is too long for the {.val scroll} style ({round(e$duration)} s); use {.code style = \"cursor\"} or a larger {.arg window_s}.")
    }
    strip <- file.path(tmp, "strip.png")
    grDevices::png(strip, width = strip_width, height = strip_height, res = 72)
    plot_style(c(45, 0, 0, 0))
    graphics::plot.new()
    graphics::plot.window(xlim = c(-window_s / 2, e$duration + window_s / 2),
                          ylim = c(0, max(e$spec$frequency) / 1000), xaxs = "i", yaxs = "i")
    graphics::rasterImage(e$ras, 0, 0, e$duration, max(e$spec$frequency) / 1000, interpolate = TRUE)
    if (length(marks) == 2) graphics::abline(v = marks, col = "white", lty = 2, lwd = 2)
    graphics::axis(1, at = seq(0, floor(e$duration * 2) / 2, by = 0.5))
    grDevices::dev.off()
    inputs <- c(inputs, "-i", strip)
    filter <- sprintf(paste0(
      "[1:v]loop=loop=-1:size=1:start=0,setpts=N/(%s*TB),",
      "crop=w=%d:h=%d:x='t*%s':y=0[b];[0:v][b]overlay=x=%d:y=%d:shortest=1[f];",
      "%s[l];[f][l]overlay=x=%d:y=%d:shortest=1,format=yuv420p[v]"),
      fps, pw, strip_height, num(pps), x0, y0, line, x0 + round(pw / 2) - 1, y0)
    audio <- "2:a"
  }

  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  run_ffmpeg(c(
    inputs, "-i", wav, "-filter_complex", filter, "-map", "[v]", "-map", audio,
    "-c:v", "libx264", "-r", fps, "-af", "aformat=channel_layouts=mono", "-c:a", "aac",
    "-ar", "48000", "-b:a", "192k", "-shortest", "-movflags", "+faststart", file
  ))
  invisible(file)
}
