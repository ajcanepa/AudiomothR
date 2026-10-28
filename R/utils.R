# Internal helpers shared by the whole package: messages, argument checks,
# external programs (ffmpeg), CSV input/output and small conversions.

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# --- Messages ----------------------------------------------------------------

#' Error with a readable message (no R call or traceback)
#' @noRd
abort <- function(..., .envir = parent.frame()) {
  cli::cli_abort(c(...), call = NULL, .envir = .envir)
}

#' Informative message, hidden with `options(AudiomothR.quiet = TRUE)`
#' @noRd
inform <- function(..., .envir = parent.frame()) {
  if (!isTRUE(getOption("AudiomothR.quiet"))) cli::cli_inform(c(...), .envir = .envir)
  invisible()
}

#' Escapes text coming from outside (stderr of a program, file contents) so
#' that cli does not interpret its braces as glue expressions.
#' @noRd
cli_escape <- function(x) gsub("([{}])", "\\1\\1", cli::ansi_strip(x))

# --- Argument checks ---------------------------------------------------------

#' A single number between min and max (error otherwise)
#' @noRd
check_number <- function(x, name, min = -Inf, max = Inf, integer = FALSE, hint = NULL) {
  ok <- is.numeric(x) && length(x) == 1 && !is.na(x) && x >= min && x <= max &&
    (!integer || x == round(x))
  if (!ok) {
    range_txt <- if (is.finite(min) && is.finite(max)) sprintf(" between %s and %s", min, max) else
      if (is.finite(min)) sprintf(" >= %s", min) else ""
    abort("{.arg {name}} must be a single {if (integer) 'whole ' else ''}number{range_txt}.",
          "x" = "You supplied {.val {format(x)}}.", "i" = hint)
  }
  invisible(x)
}

#' A confidence between 0 and 1 (suggests x/100 if it looks like a percentage)
#' @noRd
check_confidence <- function(x, name) {
  hint <- if (is.numeric(x) && length(x) == 1 && !is.na(x) && x > 1 && x <= 100) {
    "Confidences go from 0 to 1: did you mean {.code {name} = {x / 100}}?"
  }
  check_number(x, name, 0, 1, hint = hint)
}

#' TRUE or FALSE
#' @noRd
check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1 || is.na(x)) abort("{.arg {name}} must be {.code TRUE} or {.code FALSE}.")
  invisible(x)
}

#' One of a set of values (a translated replacement for match.arg())
#' @noRd
check_choice <- function(x, choices, name) {
  if (is.null(x) || identical(x, choices)) return(choices[1])
  if (!is.character(x) || length(x) != 1 || !x %in% choices) {
    abort("{.arg {name}} must be one of {.or {.val {choices}}}.", "x" = "You supplied {.val {format(x)}}.")
  }
  x
}

#' Errors on unknown arguments passed through `...`
#' @noRd
check_dots_empty <- function(...) {
  extra <- names(list(...))
  if (length(list(...))) {
    extra[is.na(extra) | !nzchar(extra)] <- "(unnamed)"
    abort("Unknown argument{?s}: {.arg {extra}}.")
  }
}

# --- Files -------------------------------------------------------------------

#' Path to a file installed with the package (inst/)
#' @noRd
package_file <- function(...) {
  system.file(..., package = "AudiomothR", mustWork = TRUE)
}

#' Writes a CSV file in UTF-8 with commas and a decimal point
#'
#' The file is written to a temporary name and then renamed, so that an
#' interruption (Ctrl+C, full disk) never leaves a truncated file behind.
#' @noRd
write_csv <- function(x, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(file, ".part")
  old <- options(scipen = 100) # never scientific notation (coordinates)
  on.exit(options(old))
  con <- file(tmp, open = "w", encoding = "UTF-8")
  ok <- FALSE
  on.exit(if (!ok) unlink(tmp), add = TRUE)
  utils::write.csv(x, con, row.names = FALSE, na = "")
  close(con)
  if (!file.rename(tmp, file)) {
    file.copy(tmp, file, overwrite = TRUE)
    unlink(tmp)
  }
  ok <- TRUE
  invisible(file)
}

# Columns that are always read as text: AudioMoth IDs are hexadecimal and may
# look like numbers (e.g. "2403750567123456" or "24037E0567123456").
text_columns <- c("device_id", "deployment_id", "day_folder", "file", "path", "local_date",
                  "local_time", "utc_offset", "recording_start_utc", "start_utc",
                  "start_local", "date", "time", "record_id", "decision", "new_name",
                  "comment", "scientific_name", "common_name", "ioc_name", "deployment",
                  "site", "folder", "first_date", "last_date")

#' Reads a CSV written by the package (or edited by hand)
#'
#' Accepts files saved by a spreadsheet with ";" as separator and "," as
#' decimal mark (Excel with a Spanish locale) and files with a BOM.
#' @noRd
read_csv <- function(file) {
  first <- readLines(file, n = 1, warn = FALSE, encoding = "UTF-8")
  if (length(first) == 0) abort("{.file {file}} is empty.")
  semicolon <- lengths(regmatches(first, gregexpr(";", first, fixed = TRUE))) >
    lengths(regmatches(first, gregexpr(",", first, fixed = TRUE)))
  header <- utils::read.csv(file, nrows = 1, sep = if (semicolon) ";" else ",",
                            check.names = FALSE, encoding = "UTF-8", fileEncoding = "UTF-8-BOM")
  cls <- rep(NA_character_, ncol(header))
  cls[names(header) %in% text_columns] <- "character"
  utils::read.csv(file, sep = if (semicolon) ";" else ",", dec = if (semicolon) "," else ".",
                  stringsAsFactors = FALSE, check.names = FALSE, na.strings = "",
                  colClasses = cls, fileEncoding = "UTF-8-BOM")
}

#' Text that can be used as (part of) a file name on any system
#' @noRd
safe_name <- function(x) {
  # Remove accents explicitly first: iconv(TRANSLIT) leaves marks behind on
  # macOS ("R'io") and gives different results on each system.
  x <- chartr("\u00e1\u00e9\u00ed\u00f3\u00fa\u00e0\u00e8\u00ec\u00f2\u00f9\u00e4\u00eb\u00ef\u00f6\u00fc\u00e2\u00ea\u00ee\u00f4\u00fb\u00f1\u00e7\u00c1\u00c9\u00cd\u00d3\u00da\u00c0\u00c8\u00cc\u00d2\u00d9\u00c4\u00cb\u00cf\u00d6\u00dc\u00c2\u00ca\u00ce\u00d4\u00db\u00d1\u00c7",
              "aeiouaeiouaeiouaeiouncAEIOUAEIOUAEIOUAEIOUNC", enc2utf8(as.character(x)))
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
  x[is.na(x)] <- ""
  x <- gsub("[`'^~\"]", "", x)
  x <- gsub("[^A-Za-z0-9._-]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  x[!nzchar(x)] <- "unnamed"
  x
}

# --- ffmpeg --------------------------------------------------------------------

#' Path to the ffmpeg executable (readable error if it is missing)
#'
#' Besides the PATH, it looks in the usual folders of each system: RStudio
#' opened from the macOS Dock does not see the Homebrew PATH, and on Windows
#' ffmpeg is often installed without adding it to the PATH.
#' @noRd
ffmpeg_path <- function() {
  option <- getOption("AudiomothR.ffmpeg")
  if (!is.null(option)) {
    if (!file.exists(option) || dir.exists(option)) {
      abort("{.file {option}} does not exist (option {.code AudiomothR.ffmpeg}).")
    }
    return(option)
  }
  candidates <- c(
    Sys.which("ffmpeg"),
    "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/opt/local/bin/ffmpeg",
    file.path(Sys.getenv("LOCALAPPDATA"), "Microsoft", "WinGet", "Links", "ffmpeg.exe"),
    file.path(Sys.getenv("ProgramData"), "chocolatey", "bin", "ffmpeg.exe"),
    file.path(Sys.getenv("USERPROFILE"), "scoop", "shims", "ffmpeg.exe"),
    "C:/ffmpeg/bin/ffmpeg.exe", "C:/Program Files/ffmpeg/bin/ffmpeg.exe"
  )
  candidates <- candidates[nzchar(candidates) & file.exists(candidates) & !dir.exists(candidates)]
  if (length(candidates) == 0) {
    abort(
      "Cannot find {.strong ffmpeg}, which is needed to convert audio and create videos.",
      "i" = "Install it (Linux: {.code sudo apt install ffmpeg}; macOS: {.code brew install ffmpeg}; Windows: {.code winget install ffmpeg})",
      "i" = "or set its path with {.code options(AudiomothR.ffmpeg = \"/path/to/ffmpeg\")}."
    )
  }
  unname(candidates[1])
}

#' Runs ffmpeg with its arguments as a vector (never as a command string)
#' @noRd
run_ffmpeg <- function(args) {
  res <- processx::run(ffmpeg_path(), c("-hide_banner", "-loglevel", "error", "-y", args),
                       error_on_status = FALSE)
  if (res$status != 0) {
    lines <- utils::tail(strsplit(trimws(res$stderr), "\n")[[1]], 10)
    abort("ffmpeg failed.", stats::setNames(cli_escape(lines), rep("x", length(lines))))
  }
  invisible(res)
}

# --- Dates and languages -----------------------------------------------------

#' BirdNET week of the year: 48 weeks, 4 per month (1 to 48)
#'
#' Uses the convention of the eBird bar charts, on which the BirdNET metadata
#' model is based (also used by BirdNET-Go): days 1-7, 8-14, 15-21 and 22 to
#' the end of the month.
#' @noRd
birdnet_week <- function(date) {
  date <- as.Date(date)
  month <- as.integer(format(date, "%m"))
  day <- as.integer(format(date, "%d"))
  (month - 1L) * 4L + pmin(4L, (day - 1L) %/% 7L + 1L)
}

# Languages of the common names of BirdNET v2.4 ("pl" is excluded: its label
# file repeats a species and shifts the names of more than 3,000 species).
birdnet_languages <- c("af", "ar", "cs", "da", "de", "en_uk", "en_us", "es", "fi", "fr", "hu",
                       "it", "ja", "ko", "nl", "no", "pt", "ro", "ru", "sk", "sl", "sv", "th",
                       "tr", "uk", "zh")

#' Language of the common names according to the operating system locale
#'
#' Looks at the LANGUAGE, LC_ALL, LC_MESSAGES and LANG environment variables
#' and at the R locale ("es_ES.UTF-8" on Linux and macOS, "Spanish_Spain.1252"
#' on Windows). Falls back to "en_us" when the language has no BirdNET labels.
#' @noRd
default_language <- function() {
  candidates <- c(strsplit(Sys.getenv("LANGUAGE"), ":", fixed = TRUE)[[1]],
                  Sys.getenv(c("LC_ALL", "LC_MESSAGES", "LANG")),
                  tryCatch(Sys.getlocale("LC_COLLATE"), error = function(e) ""))
  candidates <- candidates[nzchar(candidates) & !candidates %in% c("C", "POSIX", "C.UTF-8")]
  windows <- c(spanish = "es", english = "en_us", german = "de", french = "fr", italian = "it",
               portuguese = "pt", dutch = "nl", swedish = "sv", danish = "da", norwegian = "no",
               finnish = "fi", czech = "cs", slovak = "sk", slovenian = "sl", hungarian = "hu",
               romanian = "ro", russian = "ru", ukrainian = "uk", turkish = "tr", japanese = "ja",
               korean = "ko", chinese = "zh", arabic = "ar", thai = "th", afrikaans = "af")
  for (x in candidates) {
    x <- tolower(sub("[.@].*$", "", x))
    win <- windows[startsWith(x, names(windows))]
    if (length(win)) return(if (grepl("kingdom", x)) "en_uk" else unname(win[1]))
    if (x %in% c("en_gb", "en_ie", "en_au", "en_nz")) return("en_uk")
    lang <- sub("_.*$", "", x)
    if (lang == "en") return("en_us")
    if (lang %in% c("nb", "nn")) return("no")
    if (lang %in% birdnet_languages) return(lang)
  }
  "en_us"
}

# --- Requirements --------------------------------------------------------------

#' Checks what AudiomothR needs and what is installed
#'
#' Reports, for each requirement, whether it is available and how to install
#' it otherwise: ffmpeg (required to convert audio and create videos),
#' birdnetR (required; the first time it installs Python and the BirdNET
#' model) and, for the PDF report, Quarto, knitr and rmarkdown, and the map
#' packages (maptiles, sf and terra). It also shows the language that will be
#' used for the common names of the species.
#'
#' @return Invisibly, a named logical vector: `TRUE` when the requirement is
#'   available.
#' @examples
#' check_requirements()
#' @export
check_requirements <- function() {
  path <- function(f) tryCatch(f(), error = function(e) NA_character_)
  ffmpeg <- path(ffmpeg_path)
  quarto <- path(quarto_path)
  has <- function(p) rlang::is_installed(p)
  ok <- c(ffmpeg = !is.na(ffmpeg), birdnetR = has("birdnetR"), quarto = !is.na(quarto),
          knitr_rmarkdown = has("knitr") && has("rmarkdown"),
          map = has("maptiles") && has("sf") && has("terra"))
  line <- function(yes, text_yes, text_no) if (yes) c("v" = text_yes) else c("x" = text_no)
  language <- default_language()
  cli::cli_h2("AudiomothR requirements")
  cli::cli_bullets(c(
    line(ok[["ffmpeg"]], "ffmpeg: {.file {ffmpeg}}",
         "ffmpeg: not found (required). Linux: {.code sudo apt install ffmpeg}; macOS: {.code brew install ffmpeg}; Windows: {.code winget install ffmpeg}. Or set {.code options(AudiomothR.ffmpeg = \"/path/to/ffmpeg\")}."),
    line(ok[["birdnetR"]], "birdnetR {utils::packageVersion('birdnetR')} (the first time it installs Python and the BirdNET model)",
         "birdnetR: not installed (required). {.code install.packages(\"birdnetR\")}"),
    line(ok[["quarto"]], "Quarto (PDF report): {.file {quarto}}",
         "Quarto: not found (only for {.fn create_report}). It comes with RStudio and Positron, or {.url https://quarto.org}."),
    line(ok[["knitr_rmarkdown"]], "knitr and rmarkdown (PDF report)",
         "knitr or rmarkdown: not installed (only for {.fn create_report}). {.code install.packages(c(\"knitr\", \"rmarkdown\"))}"),
    line(ok[["map"]], "maptiles, sf and terra (report map on OpenStreetMap)",
         "maptiles, sf or terra: not installed (optional; without them the map has no background). {.code install.packages(c(\"maptiles\", \"sf\", \"terra\"))}"),
    "i" = "Language of the common names (from the system locale): {.val {language}}. Change it with the {.arg language} argument of {.fn analyze_birdnet}."
  ))
  invisible(ok)
}
