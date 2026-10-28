# Functions of the AudiomothR report: tables and plots with base R.
# This file, report.qmd and _section.qmd can be edited; then run
# `quarto render report.qmd` in this folder. report.qmd loads these functions
# in their own environment, so they do not mask functions of AudiomothR.

col_main <- "#2E6F8E"
col_second <- "#E07A3F"
col_soft <- "grey80"

# --- Numbers, dates and tables -----------------------------------------------

`%|%` <- function(x, y) {
  if (length(x) == 0) return(y)
  x[is.na(x)] <- y
  x
}
min_or <- function(x, default) {
  x <- suppressWarnings(min(x, na.rm = TRUE))
  if (is.finite(x)) x else default
}
num <- function(x, k = 2) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.na(x), "\u2013", formatC(x, format = "f", digits = k))
}
int <- function(x) formatC(x, format = "d", big.mark = ",")
date_txt <- function(x) ifelse(is.na(x), "\u2013", format(as.Date(x), "%d/%m/%Y"))
# Italics only for scientific names (two words, the first capitalised)
italic <- function(x) ifelse(grepl("^[A-Z][a-z]+ [a-z-]+$", x), paste0("*", x, "*"), x)

# Texts given by the user (site names...) can contain characters with a
# meaning in Markdown or Typst ("@" starts a citation, "#" a heading...)
esc <- function(x) gsub("([\\\\`*_{}<>#@$~^|\\[\\]])", "\\\\\\1", x, perl = TRUE)

kable_md <- function(x, ...) {
  print(knitr::kable(x, format = "pipe", row.names = FALSE, ...))
  cat("\n")
}

paragraph <- function(...) cat(paste0(...), "\n\n", sep = "")

plot_style <- function(mar = c(4, 4, 1, 1)) {
  graphics::par(mar = mar, las = 1, cex = 0.8, bty = "l", mgp = c(2.6, 0.6, 0), tcl = -0.3)
}

rows_of <- function(x, recorders) {
  if (is.null(x)) return(data.frame())
  x[x$recorder %in% recorders, , drop = FALSE]
}

# --- Summaries ---------------------------------------------------------------

report_species <- function(d) {
  if (nrow(d) == 0) return(data.frame())
  by <- split(d, d$scientific_name)
  r <- do.call(rbind, lapply(by, function(x) data.frame(
    scientific_name = x$scientific_name[1],
    common_name = x$common_name[1],
    detections = length(unique(paste(x$recorder, x$file, x$event))),
    days = length(unique(x$local_date)),
    recorders = length(unique(x$recorder)),
    confidence_max = max(x$confidence),
    confidence_mean = mean(x$confidence),
    no_doubts = mean(as.logical(x$no_doubts)),
    stringsAsFactors = FALSE
  )))
  r <- r[order(-r$detections, -r$confidence_max), , drop = FALSE]
  rownames(r) <- NULL
  r
}

table_species <- function(r, several_recorders = FALSE) {
  t <- data.frame(
    Species = esc(r$common_name),
    `Scientific name` = italic(r$scientific_name),
    Detections = int(r$detections),
    Days = r$days,
    `Conf. max.` = num(r$confidence_max),
    `Conf. mean` = num(r$confidence_mean),
    `No doubts` = paste0(round(100 * r$no_doubts), " %"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  if (several_recorders) t$Recorders <- r$recorders
  kable_md(t, align = c("l", "l", rep("r", ncol(t) - 2)))
}

# --- Map ---------------------------------------------------------------------

map_recorders <- function(recorders) {
  recorders <- recorders[is.finite(recorders$lat) & is.finite(recorders$lon), , drop = FALSE]
  if (nrow(recorders) == 0) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "The recorders have no coordinates")
    return(invisible())
  }
  colours <- grDevices::hcl.colors(max(3, nrow(recorders)), "Dark 3")[seq_len(nrow(recorders))]
  background <- NULL
  if (all(vapply(c("maptiles", "sf", "terra"), requireNamespace, logical(1), quietly = TRUE))) {
    pts <- sf::st_transform(sf::st_as_sf(recorders, coords = c("lon", "lat"), crs = 4326), 3857)
    bb <- sf::st_bbox(pts)
    # Margin for the labels: wider when the names are long
    margin <- max(600, 0.2 * max(bb[["xmax"]] - bb[["xmin"]], bb[["ymax"]] - bb[["ymin"]]))
    margin_x <- margin * max(1, max(nchar(recorders$recorder)) / 12)
    bb[["xmin"]] <- bb[["xmin"]] - margin_x
    bb[["xmax"]] <- bb[["xmax"]] + margin_x
    bb[["ymin"]] <- bb[["ymin"]] - margin
    bb[["ymax"]] <- bb[["ymax"]] + margin
    background <- tryCatch(
      suppressMessages(maptiles::get_tiles(sf::st_as_sfc(bb), provider = "OpenStreetMap",
                                           crop = TRUE, verbose = FALSE)),
      error = function(e) NULL)
  }
  if (!is.null(background)) {
    terra::plotRGB(background, mar = c(1.5, 0, 0, 0), maxcell = 5e6)
    xy <- sf::st_coordinates(pts)
    graphics::points(xy, pch = 21, bg = colours, col = "white", cex = 2.2, lwd = 2)
    graphics::text(xy, labels = recorders$recorder, pos = 3, offset = 1, font = 2, cex = 0.8, xpd = NA)
    graphics::mtext("\u00a9 OpenStreetMap contributors", side = 1, line = 0.3, adj = 1, cex = 0.6)
  } else {
    plot_style()
    range_of <- function(x) range(x) + c(-1, 1) * max(0.01, 0.2 * diff(range(x)))
    graphics::plot(recorders$lon, recorders$lat, xlim = range_of(recorders$lon), ylim = range_of(recorders$lat),
                   asp = 1 / cos(mean(recorders$lat) * pi / 180), pch = 21, bg = colours, cex = 2,
                   xlab = "Longitude (\u00b0)", ylab = "Latitude (\u00b0)")
    graphics::grid()
    graphics::text(recorders$lon, recorders$lat, labels = recorders$recorder, pos = 3, offset = 1, cex = 0.8, xpd = NA)
    graphics::mtext("Map without background (maptiles, sf and terra not installed, or no Internet connection)",
                    side = 1, line = 2.8, adj = 1, cex = 0.6, col = "grey40")
  }
}

# --- Recordings --------------------------------------------------------------

plot_recordings_day <- function(g) {
  g <- g[!is.na(g$local_date), , drop = FALSE]
  if (nrow(g) == 0) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "No recordings with a date")
    return(invisible())
  }
  plot_style(c(5, 4, 2.5, 1))
  t <- table(factor(g$valid, c(TRUE, FALSE)), g$local_date)
  graphics::barplot(t, col = c(col_main, col_second), border = NA, space = 0.15,
                    names.arg = format(as.Date(colnames(t)), "%d/%m"), las = 2,
                    ylab = "Recordings", cex.names = if (ncol(t) > 30) 0.6 else 0.8)
  graphics::legend("topright", c("Valid", "With problems"), fill = c(col_main, col_second),
                   border = NA, bty = "n", horiz = TRUE, inset = c(0, -0.15), xpd = NA)
}

# Variables with data among battery and temperature (old firmware versions do
# not record the temperature)
battery_variables <- function(g) {
  ok <- !is.na(g$start_local)
  c("battery_v", "temperature_c")[c(any(is.finite(g$battery_v[ok])), any(is.finite(g$temperature_c[ok])))]
}

plot_battery <- function(g) {
  vars <- battery_variables(g)
  if (length(vars) == 0) return(invisible())
  g <- g[!is.na(g$start_local), , drop = FALSE]
  g <- g[order(g$recorder, g$start_local), , drop = FALSE]
  t <- as.POSIXct(g$start_local, tz = "UTC")
  recorders <- unique(g$recorder)
  colours <- grDevices::hcl.colors(max(3, length(recorders)), "Dark 3")[seq_along(recorders)]
  graphics::par(mfrow = c(1, length(vars)))
  for (v in vars) {
    plot_style(c(4, 4, 1, 1))
    y <- g[[v]]
    graphics::plot(range(t), range(y, na.rm = TRUE), type = "n", xaxt = "n", xlab = "",
                   ylab = if (v == "battery_v") "Battery (V)" else "Temperature (\u00b0C)")
    graphics::axis.POSIXct(1, t, format = "%d/%m")
    for (k in seq_along(recorders)) {
      e <- g$recorder == recorders[k] & is.finite(y)
      graphics::lines(t[e], y[e], col = colours[k], lwd = 1.5)
    }
  }
  if (length(recorders) > 1) {
    graphics::legend("topright", recorders, col = colours, lwd = 2, bty = "n", cex = 0.8)
  }
}

# --- Species -----------------------------------------------------------------

plot_confidence <- function(d, r, max_species = 25) {
  sp <- rev(utils::head(r$scientific_name, max_species))
  x <- d[d$scientific_name %in% sp, , drop = FALSE]
  labels <- r$common_name[match(sp, r$scientific_name)]
  plot_style(c(4, 11, 1, 1))
  f <- factor(x$scientific_name, levels = sp)
  graphics::boxplot(x$confidence ~ f, horizontal = TRUE, names = labels, col = "white",
                    border = "grey50", outline = FALSE, ylim = c(min(d$confidence), 1),
                    xlab = "", ylab = "", las = 1, cex.axis = 0.8)
  graphics::stripchart(x$confidence ~ f, add = TRUE, method = "jitter", jitter = 0.2, pch = 16,
                       cex = 0.6, col = grDevices::adjustcolor(col_main, 0.5))
  graphics::title(xlab = "BirdNET confidence")
}

plot_hourly_activity <- function(d, r, max_species = 20) {
  sp <- utils::head(r$scientific_name, max_species)
  x <- d[d$scientific_name %in% sp, , drop = FALSE]
  hour <- as.integer(substr(x$local_time, 1, 2))
  m <- table(factor(x$scientific_name, levels = rev(sp)), factor(hour, 0:23))
  palette <- c("white", grDevices::hcl.colors(30, "YlGnBu", rev = TRUE))
  graphics::layout(matrix(1:2, nrow = 2), heights = c(1, 0.12 + 0.6 / max(1, nrow(m))))
  plot_style(c(4, 11, 1, 1))
  graphics::image(0:23, seq_along(rownames(m)), t(log1p(m)), axes = FALSE, col = palette,
                  xlab = "Local hour", ylab = "")
  graphics::axis(1, at = seq(0, 23, 3))
  graphics::axis(2, at = seq_along(rownames(m)), labels = r$common_name[match(rownames(m), r$scientific_name)],
                 cex.axis = 0.8, tick = FALSE)
  graphics::box()
  # Colour key
  top <- max(m)
  plot_style(c(1.5, 11, 0.2, 1))
  graphics::image(seq(0, log1p(top), length.out = 31), 1, matrix(seq(0, log1p(top), length.out = 31)),
                  col = palette, axes = FALSE, xlab = "", ylab = "")
  at <- unique(round(c(0, expm1(log1p(top) / 2), top)))
  graphics::axis(1, at = log1p(at), labels = at, cex.axis = 0.7, mgp = c(1, 0.2, 0))
  graphics::mtext("Detections", side = 2, las = 1, line = 0.5, cex = 0.6)
}

plot_species_day <- function(d, g) {
  days <- sort(unique(stats::na.omit(g$local_date)))
  n <- vapply(days, function(x) length(unique(d$scientific_name[d$local_date == x])), numeric(1))
  det <- vapply(days, function(x) sum(d$local_date == x), numeric(1))
  plot_style(c(5, 4, 1, 4))
  xs <- graphics::barplot(det, col = col_soft, border = NA, names.arg = format(as.Date(days), "%d/%m"),
                          las = 2, ylab = "Detections", cex.names = if (length(days) > 30) 0.6 else 0.8)
  graphics::par(new = TRUE)
  graphics::plot(xs, n, type = "b", pch = 16, col = col_main, axes = FALSE, xlab = "", ylab = "",
                 xlim = graphics::par("usr")[1:2], xaxs = "i", ylim = c(0, max(1, n)))
  graphics::axis(4, col.axis = col_main)
  graphics::mtext("Species", side = 4, line = 2.6, las = 0, cex = 0.8, col = col_main)
}

matrix_recorders <- function(d, r) {
  m <- table(factor(d$scientific_name, levels = r$scientific_name), d$recorder)
  t <- data.frame(Species = esc(r$common_name), check.names = FALSE, stringsAsFactors = FALSE)
  for (k in colnames(m)) t[[esc(k)]] <- ifelse(m[, k] > 0, int(as.integer(m[, k])), "\u00b7")
  kable_md(t, align = c("l", rep("r", ncol(t) - 1)))
}
