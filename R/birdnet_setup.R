# Installation of BirdNET: the Python environment (installed by birdnetR with
# uv) and the model files.
#
# The Python package 'birdnet' (0.1.7, used by birdnetR 0.3.2) downloads the
# model from Zenodo with a 30 s timeout and no retries, and a slow or
# interrupted connection makes it fail ("Failed to download the file. Status
# code: 200"). AudiomothR downloads the model itself first, with retries and
# an MD5 check, into the folder where 'birdnet' looks for it, so that
# 'birdnet' finds it and does not download anything.

# BirdNET v2.4 TFLite model (Zenodo record 15050749), as expected by birdnet 0.1.7
birdnet_model_files <- list(
  "v2.4" = list(
    url = "https://zenodo.org/records/15050749/files/BirdNET_v2.4_tflite.zip",
    size = 76822925, md5 = "c13f7fd28a5f7a3b092cd993087f93f7",
    files = c("audio-model.tflite" = 51726412, "meta-model.tflite" = 29526096)
  )
)

#' Folder where the Python package 'birdnet' keeps the TFLite model
#'
#' Windows: %APPDATA%/birdnet; macOS: ~/Library/Application Support/birdnet;
#' Linux: ~/.local/share/birdnet (as in birdnet.utils.get_app_data_path()).
#' @noRd
birdnet_model_dir <- function(version = "v2.4") {
  base <- switch(
    if (.Platform$OS.type == "windows") "windows" else if (Sys.info()[["sysname"]] == "Darwin") "mac" else "linux",
    windows = Sys.getenv("APPDATA"),
    mac = file.path(path.expand("~"), "Library", "Application Support"),
    linux = file.path(path.expand("~"), ".local", "share")
  )
  file.path(base, "birdnet", "models", version, "TFLite")
}

#' TRUE when the model files are complete
#' @noRd
birdnet_model_ok <- function(version = "v2.4") {
  spec <- birdnet_model_files[[version]]
  if (is.null(spec)) return(TRUE)   # other versions: left to birdnet
  dir <- birdnet_model_dir(version)
  sizes <- file.size(file.path(dir, names(spec$files)))
  isTRUE(all(sizes == spec$files)) && length(list.files(file.path(dir, "labels"), pattern = "\\.txt$")) > 0
}

#' Downloads and unpacks the BirdNET model when it is missing or incomplete
#' @noRd
ensure_birdnet_model <- function(version = "v2.4", attempts = 3) {
  spec <- birdnet_model_files[[version]]
  if (is.null(spec) || birdnet_model_ok(version)) return(invisible(TRUE))
  dir <- birdnet_model_dir(version)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  zip <- file.path(dir, "AudiomothR_download.zip")
  on.exit(unlink(zip), add = TRUE)
  old <- options(timeout = max(3600, getOption("timeout")))
  on.exit(options(old), add = TRUE)
  inform("Downloading the BirdNET {version} model ({round(spec$size / 2^20)} MB) into {.file {dir}}...")
  ok <- FALSE
  for (i in seq_len(attempts)) {
    res <- tryCatch(utils::download.file(spec$url, zip, mode = "wb", quiet = isTRUE(getOption("AudiomothR.quiet"))),
                    error = function(e) e, warning = function(w) w)
    ok <- !inherits(res, "condition") && isTRUE(file.size(zip) == spec$size) &&
      identical(unname(tools::md5sum(zip)), spec$md5)
    if (ok) break
    if (i < attempts) inform("!" = "The download failed (attempt {i} of {attempts}); trying again...")
  }
  if (!ok) {
    abort("Cannot download the BirdNET {version} model.",
          "i" = "Check the Internet connection, or download {.url {spec$url}} by hand and unzip it into {.file {dir}}.")
  }
  utils::unzip(zip, exdir = dir)
  if (!birdnet_model_ok(version)) abort("The BirdNET model in {.file {dir}} is incomplete after unzipping it.")
  inform(c("v" = "BirdNET {version} model installed."))
  invisible(TRUE)
}

#' Installs and checks BirdNET
#'
#' Prepares everything [analyze_birdnet()] needs, so that the first analysis
#' does not stop half-way: downloads the BirdNET model (with retries and an
#' integrity check), lets birdnetR install its Python environment (Python
#' 3.11, TensorFlow and the 'birdnet' package, about 3 GB, with uv; nothing
#' has to be installed by hand on Windows, macOS or Linux) and loads the
#' model once. It only takes time the first time; afterwards it returns at
#' once. Running it is optional: [analyze_birdnet()] does the same when needed.
#'
#' @param version Version of the BirdNET model.
#' @param language Language of the common names to check.
#' @return Invisibly, `TRUE` when BirdNET works.
#' @examples
#' \dontrun{
#' setup_birdnet()   # the first time: a few minutes and about 3 GB
#' }
#' @export
setup_birdnet <- function(version = "v2.4", language = default_language()) {
  language <- check_language(language)
  bn_prepare(version)
  model <- quiet_python(bn_load_model(version, language, 1L))
  labels <- bn_labels(model, language)
  inform(c("v" = "BirdNET {version} is ready ({nrow(labels)} classes; common names in {.val {language}}).",
           "i" = "Model in {.file {birdnet_model_dir(version)}}."))
  invisible(TRUE)
}

#' Model files and Python ready before the first model is loaded (replaced by
#' a mock function in the tests)
#' @noRd
bn_prepare <- function(version) {
  ensure_birdnet_model(version)
  if (!reticulate::py_available(initialize = FALSE)) {
    inform("Starting BirdNET (the first time birdnetR installs Python and TensorFlow, about 3 GB; it may take a few minutes)...")
  }
  bn_start_python()
}

#' Starts the Python of birdnetR before the first model is loaded, so that the
#' messages of TensorFlow Lite can be silenced from the start
#' @noRd
bn_start_python <- function() {
  loadNamespace("birdnetR")   # declares its Python requirements (reticulate::py_require)
  invisible(reticulate::py_config())
}
