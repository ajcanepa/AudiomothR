# PDF report of one or several AudioMoth recorders (Quarto + Typst).
#
# The template is in inst/report/. create_report() copies it to the report
# folder (only the first time, so that it can be edited) together with
# report_data.rds (all the tables it needs), _metadata.yml (title, subtitle
# and date) and the spectrograms of the examples. The folder is
# self-contained: report.qmd can be edited and rendered again with
# `quarto render report.qmd`.

report_template <- c("report.qmd", "_section.qmd", "report_functions.R")

#' Creates a PDF report of one or several AudioMoth recorders
#'
#' Prepares a Quarto folder with everything it needs (`report.qmd`,
#' `_section.qmd`, `report_functions.R`, `report_data.rds` and the
#' spectrograms of the examples) and renders it as a PDF with Quarto and
#' Typst (LaTeX is not needed).
#'
#' The report includes:
#' - a summary of the sampling and the results;
#' - a map of the recorders (on OpenStreetMap when `maptiles`, `sf` and
#'   `terra` are installed and there is an Internet connection; otherwise
#'   without background) and a table with their configuration;
#' - the state of the recordings: recordings per day, problems, recordings
#'   that BirdNET could not analyse, battery and temperature;
#' - the detected species, with their confidence and their activity by day
#'   and by hour and, with several recorders, which recorder detected each;
#' - the spectrograms of the examples created with [extract_examples()];
#' - the records exported with [export_observation()] and the result of the
#'   validation by ear ([create_validation()]);
#' - the parameters of the analysis and the versions of the software.
#'
#' The template files are copied only the first time: later calls keep the
#' edits made to them (unless `overwrite_template = TRUE`) and only update
#' the data.
#'
#' @param recorders An `audiomoth` object analysed with [analyze_birdnet()]
#'   or a list of them (several recorders).
#' @param by_recorder With several recorders, `TRUE` gives each recorder its
#'   own section and `FALSE` combines them into a single analysis.
#' @param output Folder of the report. By default, `report/` inside the
#'   results folder of the recorder; with several recorders it must be given.
#' @param title Title of the report.
#' @param min_confidence Only the detections with at least this confidence
#'   are summarised.
#' @param map Include the map of the recorders.
#' @param open Open the PDF at the end.
#' @param overwrite_template Copy the template files again, replacing the
#'   edited ones.
#' @return Invisibly, the path of the PDF file.
#' @examples
#' \dontrun{
#' create_report(am)                                         # one recorder
#' create_report(list(am1, am2, am3), by_recorder = FALSE,
#'               output = "report_river")                    # several recorders together
#' }
#' @export
create_report <- function(recorders, by_recorder = TRUE, output = NULL,
                          title = "Acoustic monitoring report", min_confidence = 0.5, map = TRUE,
                          open = interactive(), overwrite_template = FALSE) {
  recorders <- as_recorders(recorders)
  check_flag(by_recorder, "by_recorder")
  check_confidence(min_confidence, "min_confidence")
  check_flag(map, "map")
  check_flag(open, "open")
  check_flag(overwrite_template, "overwrite_template")
  if (!is.character(title) || length(title) != 1) abort("{.arg title} must be a text.")
  for (p in c("knitr", "rmarkdown")) {
    if (!requireNamespace(p, quietly = TRUE)) {
      abort("The report needs the {.pkg {p}} package.", "i" = "Install it with {.code install.packages(\"{p}\")}.")
    }
  }
  quarto <- quarto_path()
  if (is.null(output)) {
    if (length(recorders) > 1) abort("With several recorders, give the folder of the report in {.arg output}.")
    output <- file.path(recorders[[1]]$output, "report")
  }
  output <- normalizePath(output, mustWork = FALSE)
  results <- vapply(recorders, function(am) normalizePath(am$output, mustWork = FALSE), "")
  if (output %in% results) {
    abort("{.arg output} cannot be the results folder of a recorder.",
          "i" = "Use, for example, {.code output = file.path(am$output, \"report\")}.")
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)

  for (f in report_template) {
    target <- file.path(output, f)
    if (overwrite_template || !file.exists(target)) {
      file.copy(package_file("report", f), target, overwrite = TRUE)
    } else if (!identical(unname(tools::md5sum(target)), unname(tools::md5sum(package_file("report", f))))) {
      inform("i" = "{.file {f}} has been edited: your version is kept (use {.code overwrite_template = TRUE} to replace it).")
    }
  }

  data <- report_data(recorders, output, min_confidence)
  data$by_recorder <- by_recorder && length(recorders) > 1
  data$map <- map
  saveRDS(data, file.path(output, "report_data.rds"))
  writeLines(enc2utf8(c(sprintf("title: %s", yaml_string(md_escape(title))),
                        sprintf("subtitle: %s", yaml_string(md_escape(data$subtitle))),
                        sprintf("date: %s", yaml_string(format(Sys.Date()))))),
             file.path(output, "_metadata.yml"), useBytes = TRUE)

  pdf <- if (length(recorders) == 1) sprintf("Report_AudioMoth_%s.pdf", recorders[[1]]$config$device_id) else
    "Report_AudioMoth.pdf"
  inform("Creating the report with Quarto (it may take a minute)...")
  res <- processx::run(quarto, c("render", "report.qmd", "--to", "typst", "--output", pdf),
                       wd = output, error_on_status = FALSE,
                       env = c("current", QUARTO_R = R.home("bin"),
                               R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)))
  pdf <- file.path(output, pdf)
  if (res$status != 0 || !file.exists(pdf)) {
    lines <- cli::ansi_strip(strsplit(trimws(paste(res$stderr, res$stdout)), "\n")[[1]])
    lines <- lines[!grepl("^\\s*at |^Stack trace|^\\s*$", lines)]
    errors <- grep("ERROR|Error", lines, value = TRUE)
    lines <- unique(c(utils::head(errors, 5), utils::tail(lines, 8)))
    abort("Quarto could not create the report.",
          stats::setNames(cli_escape(lines), rep("x", length(lines))),
          "i" = "The report folder is {.file {output}}.")
  }
  inform(c("v" = "Report in {.file {pdf}}."))
  if (open) {
    tryCatch(utils::browseURL(pdf),
             error = function(e) inform("!" = "Cannot open the PDF: {cli_escape(conditionMessage(e))}"))
  }
  invisible(pdf)
}

#' Escapes the characters with a meaning in Markdown or Typst ("@" starts a
#' citation, "#" a heading...) in texts given by the user
#' @noRd
md_escape <- function(x) gsub("([\\\\`*_{}<>#@$~^|\\[\\]])", "\\\\\\1", x, perl = TRUE)

#' A text as a double-quoted YAML string
#' @noRd
yaml_string <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub("\"", "\\\\\"", x)
  paste0("\"", gsub("[\r\n]+", " ", x), "\"")
}

#' Latest BirdNET cache of a recorder (folder with the newest parameters)
#' @noRd
latest_cache <- function(am) {
  if (!is.null(am$analysis$cache)) return(am$analysis$cache)
  dirs <- list.dirs(file.path(am$output, "birdnet"), recursive = FALSE)
  dirs <- dirs[startsWith(basename(dirs), paste0(am$config$device_id, "_")) &
                 file.exists(file.path(dirs, "parameters.rds"))]
  if (length(dirs) == 0) return(NULL)
  dirs[which.max(file.mtime(file.path(dirs, "parameters.rds")))]
}

#' Gathers the tables that the report needs and copies the spectrograms
#' @noRd
report_data <- function(recorders, output, min_confidence) {
  # A box moved between sites is named after its ID
  labels <- vapply(recorders, function(am) {
    sites <- unique(am$deployments$site %||% am$site)
    if (length(sites) == 1) sites else paste("AudioMoth", am$config$device_id)
  }, character(1))
  labels <- make.unique(labels, sep = " ")
  figures <- file.path(output, "example_figures")
  unlink(figures, recursive = TRUE)   # a folder of the report only
  rec_columns <- c("file", "day_folder", "start_local", "local_date", "duration_s", "sample_rate",
                   "battery_v", "temperature_c", "triggered", "valid", "problem", "deployment")
  parts <- lapply(seq_along(recorders), function(i) {
    am <- recorders[[i]]
    label <- labels[i]
    g <- am$recordings
    cache <- latest_cache(am)
    params <- if (!is.null(cache)) tryCatch(readRDS(file.path(cache, "parameters.rds")), error = function(e) list()) else list()
    meta <- if (!is.null(cache) && file.exists(file.path(cache, "metadata.txt"))) {
      as.list(read.dcf(file.path(cache, "metadata.txt"))[1, ])
    } else list()
    if (is.null(g$analysis) && !is.null(cache)) {
      done <- file.exists(result_file(cache, g))
      g$analysis <- ifelse(!g$valid, NA_character_, ifelse(done, "ok", "pending"))
    }
    g$analysed <- if (is.null(g$analysis)) g$valid else g$valid & g$analysis %in% "ok"
    analysis_known <- !is.null(g$analysis)

    analysed <- !is.null(am$detections) || file.exists(output_file(am, "detections"))
    if (analysed) {
      d <- read_detections(am)   # an unreadable CSV is an error, not "no detections"
    } else {
      cli::cli_warn("Recorder {.val {label}} has not been analysed: run {.fn analyze_birdnet} (it appears as {.emph not analysed} in the report).")
      d <- empty_detections()
    }

    ex <- examples_index(am)
    if (!is.null(ex)) {
      missing <- !file.exists(ex$png_path)
      if (any(missing)) cli::cli_warn("{sum(missing)} example spectrogram{?s} of {.val {label}} not found (e.g. {.file {ex$png_path[missing][1]}}).")
      ex <- ex[!missing, , drop = FALSE]
      if (nrow(ex)) {
        dir.create(figures, showWarnings = FALSE)
        target <- file.path("example_figures", paste0(safe_name(label), "_", basename(ex$png_path)))
        file.copy(ex$png_path, file.path(output, target), overwrite = TRUE)
        ex$png <- target
        ex$recorder <- label
        ex <- ex[, c("recorder", "scientific_name", "common_name", "example", "confidence",
                     "local_date", "local_time", "png"), drop = FALSE]
      } else ex <- NULL
    }

    obs <- observation_export(am, label)
    val <- tryCatch(read_validation(am, quiet = TRUE), error = function(e) NULL)
    cfg <- am$config
    deployments <- am$deployments %||% data.frame(
      deployment = NA_character_, site = am$site, lat = am$location$lat, lon = am$location$lon,
      precision_m = am$location$precision_m, first_date = min(c(g$local_date, NA), na.rm = TRUE),
      last_date = max(c(g$local_date, NA), na.rm = TRUE), recordings = nrow(g), stringsAsFactors = FALSE)
    deployments <- cbind(recorder = label, deployments[, c("deployment", "site", "lat", "lon", "precision_m",
                                                           "first_date", "last_date", "recordings")],
                         stringsAsFactors = FALSE)
    summary <- data.frame(
      recorder = label, device_id = cfg$device_id, lat = am$location$lat, lon = am$location$lon,
      precision_m = am$location$precision_m, location_source = am$location$source %||% NA,
      time_zone = am$time_zone, firmware = cfg$firmware, sample_rate = cfg$sample_rate, gain = cfg$gain,
      recording_s = cfg$recording_s, sleep_s = cfg$sleep_s, analysed = analysed,
      analysis_known = analysis_known,
      model = if (!is.null(params$version)) paste("BirdNET", params$version) else d$model[1] %||% NA,
      cache_threshold = params$cache_threshold %||% NA,
      location_filter = params$location_filter %||% NA,
      location_threshold = params$location_threshold %||% NA,
      sensitivity = params$sensitivity %||% NA, overlap = params$overlap %||% NA,
      audiomothr_version = meta$audiomothr %||% NA, birdnetr_version = meta$birdnetr %||% NA,
      birdnet_python = meta$birdnet_python %||% NA, analysis_date = meta$date %||% NA,
      validated = if (is.null(val)) 0L else sum(!is.na(val$decision) | !is.na(val$new_name)),
      validated_valid = if (is.null(val)) 0L else sum(val$decision %in% "valid" | !is.na(val$new_name)),
      validated_invalid = if (is.null(val)) 0L else sum(val$decision %in% "invalid"),
      stringsAsFactors = FALSE
    )
    for (col in rec_columns) if (is.null(g[[col]])) g[[col]] <- NA
    list(summary = summary,
         recordings = cbind(recorder = label, g[, c(rec_columns, "analysed")], stringsAsFactors = FALSE),
         detections = if (nrow(d)) cbind(recorder = label, d, stringsAsFactors = FALSE) else NULL,
         examples = ex, observation = obs$records, observation_criteria = obs$criteria,
         deployments = deployments)
  })
  join <- function(k) {
    x <- lapply(parts, `[[`, k)
    x <- x[!vapply(x, is.null, logical(1))]
    if (length(x)) do.call(rbind, x) else NULL
  }
  detections <- join("detections") %||% cbind(recorder = character(), empty_detections())
  device <- recorders[[1]]$config$device_id
  list(
    subtitle = if (length(recorders) == 1) {
      if (identical(labels, paste("AudioMoth", device))) labels else sprintf("%s (AudioMoth %s)", labels, device)
    } else sprintf("%d AudioMoth recorders", length(recorders)),
    recorders = join("summary"),
    deployments = join("deployments"),
    recordings = join("recordings"),
    detections = detections[detections$confidence >= min_confidence & detections$is_species, , drop = FALSE],
    n_detections_saved = sum(detections$is_species),
    examples = join("examples"),
    observation = join("observation"),
    observation_criteria = join("observation_criteria"),
    min_confidence = min_confidence,
    package_version = as.character(utils::packageVersion("AudiomothR")),
    r_version = R.version.string,
    generated = format(Sys.time(), "%Y-%m-%d %H:%M")
  )
}

#' Index of the examples with the full path of the spectrograms (paths are
#' relative to the examples folder; absolute ones of version 0.2 are accepted)
#' @noRd
examples_index <- function(am) {
  file <- file.path(am$output, "examples", sprintf("AudioMoth_%s_examples.csv", am$config$device_id))
  if (!file.exists(file)) return(NULL)
  ex <- tryCatch(read_csv(file), error = function(e) NULL)
  if (is.null(ex) || nrow(ex) == 0 || is.null(ex$png)) return(NULL)
  ex <- ex[!is.na(ex$png), , drop = FALSE]
  absolute <- grepl("^(/|[A-Za-z]:)", ex$png)
  ex$png_path <- ifelse(absolute, ex$png, file.path(dirname(file), ex$png))
  ex
}

#' Last export to Observation.org of a recorder (path and criteria from its
#' JSON file); a CSV saved by a spreadsheet with ";" is accepted
#' @noRd
observation_export <- function(am, label) {
  file <- output_file(am, "observation")
  json <- sub("\\.csv$", ".json", file)
  criteria <- NULL
  if (file.exists(json)) {
    text <- paste(readLines(json, warn = FALSE, encoding = "UTF-8"), collapse = " ")
    get <- function(k) {
      m <- regmatches(text, regexec(sprintf("\"%s\"\\s*:\\s*(\"[^\"]*\"|[^,}]+)", k), text))[[1]]
      if (length(m)) gsub("^\"|\"$", "", trimws(m[2])) else NA_character_
    }
    named <- file.path(am$output, get("file"))
    if (file.exists(named)) file <- named
    criteria <- data.frame(recorder = label, min_confidence = as.numeric(get("min_confidence")),
                           min_detections = as.numeric(get("min_detections")),
                           validation = get("validation") == "true", stringsAsFactors = FALSE)
  }
  if (!file.exists(file)) return(list(records = NULL, criteria = criteria))
  obs <- tryCatch(read_csv(file), error = function(e) NULL)
  if (is.null(obs) || !all(c("date", "time", "scientific name", "is certain") %in% names(obs))) {
    cli::cli_warn("{.file {file}} cannot be read as an Observation.org file (keep it comma separated): it is left out of the report.")
    return(list(records = NULL, criteria = criteria))
  }
  if (nrow(obs) == 0) return(list(records = NULL, criteria = criteria))
  obs$recorder <- label
  list(records = obs[, c("recorder", "date", "time", "scientific name", "is certain", "external reference")],
       criteria = criteria)
}

#' Path of the Quarto executable (also the one that comes with RStudio or
#' Positron)
#' @noRd
quarto_path <- function() {
  option <- getOption("AudiomothR.quarto")
  if (!is.null(option) && (!file.exists(option) || dir.exists(option))) {
    abort("{.file {option}} does not exist (option {.code AudiomothR.quarto}).")
  }
  candidates <- c(
    option, Sys.getenv("QUARTO_PATH"), Sys.which("quarto"),
    # Inside RStudio, RSTUDIO_PANDOC points to <...>/quarto/bin/tools/<architecture>
    file.path(sub("[/\\\\]tools([/\\\\].*)?$", "", Sys.getenv("RSTUDIO_PANDOC")), c("quarto", "quarto.exe")),
    "/usr/local/bin/quarto", "/opt/quarto/bin/quarto", "/Applications/quarto/bin/quarto",
    "/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto",
    "/usr/share/positron/resources/app/quarto/bin/quarto",
    "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto",
    "/Applications/Positron.app/Contents/Resources/app/quarto/bin/quarto",
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe",
    "C:/Program Files/Positron/resources/app/quarto/bin/quarto.exe",
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "quarto.exe")
  )
  candidates <- candidates[nzchar(candidates) & file.exists(candidates) & !dir.exists(candidates)]
  if (length(candidates) == 0) {
    abort("Cannot find {.strong Quarto}, which is needed to create the PDF report.",
          "i" = "Install it from {.url https://quarto.org} (RStudio and Positron already include it)",
          "i" = "or set its path with {.code options(AudiomothR.quarto = \"/path/to/quarto\")}.")
  }
  path <- unname(candidates[[1]])
  version <- tryCatch(trimws(processx::run(path, "--version")$stdout), error = function(e) e)
  if (inherits(version, "error")) {
    abort("Cannot run {.file {path}} --version: {cli_escape(conditionMessage(version))}")
  }
  if (utils::compareVersion(version, "1.4") < 0) {
    abort("The report needs Quarto 1.4 or later (found {version} in {.file {path}}).")
  }
  path
}
