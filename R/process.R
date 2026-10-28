#' Processes an AudioMoth card from start to end
#'
#' Chains all the steps:
#' 1. [read_audiomoth()]: folder, `CONFIG.TXT`, location and inventory.
#' 2. [prepare_audio()]: conversion to 48 kHz mono when needed.
#' 3. [analyze_birdnet()]: detections in `AudioMoth_<ID>_detections.csv`.
#' 4. [export_observation()]: `AudioMoth_<ID>_observation.csv` (only the
#'    first time: an existing export, perhaps edited by hand, is kept unless
#'    `export = TRUE`).
#' 5. [extract_examples()]: audio, spectrogram and video of the best
#'    detections of `example_species` (when given).
#' 6. [create_validation()]: page to validate the records by ear (when
#'    `validation = TRUE`).
#' 7. [create_report()]: PDF report (when `report = TRUE`).
#'
#' If it is interrupted, running it again continues where it stopped. When
#' `output` is not given, the results folder is asked for in the console (see
#' [choose_output()]).
#'
#' @inheritParams read_audiomoth
#' @param example_species Species of which to extract examples: names, a
#'   named vector `c("Cettia cetti" = 3, ...)` with the examples of each one
#'   (see [detected_species()]) or `"auto"`, which takes the species and
#'   numbers proposed by [detected_species()] with `example_confidence`.
#'   `NULL` (default) = none.
#' @param n_examples Examples per species (one value for all or one per
#'   species) when `example_species` are only names.
#' @param example_confidence Minimum confidence of the examples.
#' @param video,video_style Create the videos of the examples, and their
#'   style (`"cursor"` or `"scroll"`).
#' @param export Export to Observation.org: `NULL` (default) only when the
#'   CSV does not exist yet, `TRUE` always (an edited CSV is still kept), or
#'   `FALSE`.
#' @param validation Create the validation page ([create_validation()]).
#' @param report Create a PDF report with [create_report()] (needs Quarto).
#' @param ... Other arguments for [analyze_birdnet()] (e.g. `language`,
#'   `min_confidence`, `location_threshold`).
#' @return Invisibly, the `audiomoth` object with its detections.
#' @examples
#' \dontrun{
#' am <- process_audiomoth(
#'   coordinates = "41.123456, -3.123456",    # copied from Google Earth
#'   output = "~/AudiomothR_results/site_01",
#'   example_species = "auto",
#'   validation = TRUE
#' )
#' }
#' @export
process_audiomoth <- function(folder = choose_folder(), coordinates = NULL, site = NULL, precision_m = NULL,
                              time_zone = "Europe/Madrid", output = NULL, example_species = NULL,
                              n_examples = 3, example_confidence = 0.85, video = TRUE,
                              video_style = c("cursor", "scroll"), export = NULL, validation = FALSE,
                              report = FALSE, ...) {
  # Arguments are checked before the (slow) analysis starts
  video_style <- check_choice(video_style, c("cursor", "scroll"), "video_style")
  check_confidence(example_confidence, "example_confidence")
  check_flag(video, "video")
  check_flag(validation, "validation")
  check_flag(report, "report")
  if (!is.null(export)) check_flag(export, "export")
  birdnet_args <- list(...)
  unknown <- setdiff(names(birdnet_args), names(formals(analyze_birdnet)))
  if (length(unknown) || (length(birdnet_args) && is.null(names(birdnet_args)))) {
    abort("Unknown argument{?s} for {.fn analyze_birdnet}: {.arg {unknown %||% '(unnamed)'}}.")
  }
  if (report) quarto_path()

  am <- read_audiomoth(folder, coordinates = coordinates, site = site, precision_m = precision_m,
                       time_zone = time_zone, output = output)
  am <- prepare_audio(am)
  am <- do.call(analyze_birdnet, c(list(am), birdnet_args))
  if (isTRUE(export) || (is.null(export) && !file.exists(output_file(am, "observation")))) {
    export_observation(am)
  } else if (is.null(export)) {
    inform("i" = "{.file {basename(output_file(am, 'observation'))}} already exists and is kept; run {.fn export_observation} to export again.")
  }
  if (identical(example_species, "auto")) {
    example_species <- detected_species(am, example_confidence = example_confidence, print = FALSE)
    example_species <- example_species[example_species > 0]
    if (length(example_species) == 0) inform("i" = "No species has examples with confidence \u2265 {example_confidence}.")
  }
  if (length(example_species)) {
    extract_examples(am, example_species, n = n_examples, min_confidence = example_confidence,
                     video = video, style = video_style)
  }
  if (validation) create_validation(am)
  if (report) create_report(am)
  invisible(am)
}
