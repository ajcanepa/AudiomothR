# Hex sticker of AudiomothR: man/figures/logo.png
#
# Run from the root of the package:
#   Rscript data-raw/logo.R
# Needs: devtools, ggplot2, hexSticker, magick, showtext/sysfonts (and an
# Internet connection the first time, to download the Fira Sans font from
# Google Fonts).
#
# A songbird sings and its song comes out of its beak as a fan of
# spectrogram: the real song of Cetti's warbler (Cettia cetti) in the
# example card of the package (BirdNET confidence 0.82, Figure 2 of the
# note), drawn with the colours of the package (viridis on #111418 and the
# orange #FF5A36 of the cursor of the videos). No external image is used.
#
# Conventions of https://github.com/rstudio/hex-stickers: hexagon with a
# vertex on top, 2" high x 1.73" wide (50.8 x 43.9 mm), everything inside
# the border. The sticker is drawn at 300 dpi and saved at 240 x 278 px, the
# size used by usethis::use_logo() for man/figures/logo.png.

devtools::load_all(quiet = TRUE)
library(ggplot2)

navy <- "#111418"
orange <- "#FF5A36"
dark_orange <- "#B83A1B"
viridis <- grDevices::hcl.colors(256, "viridis")

sysfonts::font_add_google("Fira Sans", "fira", regular.wt = 600)
showtext::showtext_auto()

# --- Spectrogram of the Cetti's warbler --------------------------------------
card <- system.file("extdata", "example", "card", package = "AudiomothR")
wav <- list.files(card, "FACADE0012345678_20261007_071500.WAV", recursive = TRUE, full.names = TRUE)[1]
clip <- cut_audio(wav, 2.6, 6.2)
spec <- compute_spectrogram(clip$wave, max_freq = 9500)
# Noise reduction: each frequency minus its median level, so that the song
# stands out from the background noise; 2 to 17 dB above the background
db <- spec$db - apply(spec$db, 1, stats::median)
db <- pmin(pmax(db, 2), 17)
spec_raster <- local({
  idx <- 1 + round((db - min(db)) / (max(db) - min(db)) * 255)
  m <- matrix(viridis[idx], nrow = nrow(db))
  grDevices::as.raster(m[nrow(m):1, , drop = FALSE])
})

# --- The songbird --------------------------------------------------------------
ellipse <- function(cx, cy, a, b, angle, n = 120) {
  t <- seq(0, 2 * pi, length.out = n)
  x <- a * cos(t); y <- b * sin(t)
  data.frame(x = cx + x * cos(angle) - y * sin(angle), y = cy + x * sin(angle) + y * cos(angle))
}
poly <- function(x, y, part) data.frame(x = x, y = y, part = part)
place <- function(d, dx = -0.30, dy = -0.10, scale = 0.80) transform(d, x = dx + scale * x, y = dy + scale * y)

# Perched, facing right, singing with the beak open
bird <- place(rbind(
  cbind(ellipse(0, 0, 0.38, 0.27, 0.38), part = "body"),
  cbind(ellipse(0.33, 0.30, 0.17, 0.17, 0), part = "head"),
  poly(c(-0.26, -0.60, -0.54, -0.16), c(-0.04, -0.30, -0.38, -0.20), "tail"),
  poly(c(0.47, 0.63, 0.49), c(0.37, 0.43, 0.31), "upper beak"),
  poly(c(0.49, 0.61, 0.46), c(0.29, 0.25, 0.24), "lower beak")
))
wing <- place(poly(c(0.20, 0.02, -0.22, -0.40, -0.10, 0.12), c(0.12, 0.17, 0.10, -0.08, -0.06, 0.00), "wing"))
eye <- place(cbind(ellipse(0.37, 0.34, 0.035, 0.035, 0), part = "eye"))
legs <- place(data.frame(x = c(0.02, -0.02, NA, 0.10, 0.08), y = c(-0.20, -0.42, NA, -0.18, -0.42)))
perch <- place(data.frame(x = c(-0.35, 0.40), y = c(-0.43, -0.43)))
# The song: a fan from the tip of the open beak
fan <- poly(c(0.20, 1.55, 1.55), c(0.24, 0.66, -0.20), "fan")

# --- Drawing: spectrogram inside the fan, then the bird on top ----------------
xlim <- c(-1.0, 1.6)
ylim <- c(-0.55, 0.65)
px <- 1600
layer <- function(p, bg) {
  f <- tempfile(fileext = ".png")
  ggsave(f, p + coord_equal(xlim = xlim, ylim = ylim, expand = FALSE) + theme_void(),
         width = px / 300, height = px * diff(ylim) / diff(xlim) / 300, dpi = 300, bg = bg)
  magick::image_read(f)
}
song <- layer(ggplot() + annotation_raster(spec_raster, 0.20, 1.6, -0.22, 0.66, interpolate = TRUE), "transparent")
mask <- layer(ggplot() + geom_polygon(data = fan, aes(x, y), fill = "white") +
                theme(plot.background = element_rect(fill = "black", colour = NA)), "black")
song <- magick::image_composite(song, magick::image_convert(mask, colorspace = "gray"), operator = "CopyOpacity")
singer <- layer(ggplot() +
                  geom_polygon(data = bird, aes(x, y, group = part), fill = orange) +
                  geom_polygon(data = wing, aes(x, y), fill = dark_orange) +
                  geom_polygon(data = eye, aes(x, y), fill = navy) +
                  geom_path(data = legs, aes(x, y), colour = orange, linewidth = 1.3, lineend = "round") +
                  geom_path(data = perch, aes(x, y), colour = "grey55", linewidth = 1.3, lineend = "round"),
                "transparent")
subplot <- tempfile(fileext = ".png")
magick::image_write(magick::image_composite(song, singer, operator = "over"), subplot)

# --- The sticker ---------------------------------------------------------------
big <- tempfile(fileext = ".png")
hexSticker::sticker(subplot, s_x = 0.97, s_y = 1.12, s_width = 0.72, s_height = 0.36,
                    package = "AudiomothR", p_family = "fira", p_size = 16, p_y = 0.58,
                    p_color = "white", h_fill = navy, h_color = orange, h_size = 1.6,
                    url = "ajcanepa.github.io/AudiomothR", u_size = 4.2, u_color = "grey70",
                    u_family = "fira", spotlight = FALSE, dpi = 300, filename = big)
dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)
logo <- magick::image_scale(magick::image_read(big), "240x278")
magick::image_write(logo, "man/figures/logo.png")
message("Logo in man/figures/logo.png")
