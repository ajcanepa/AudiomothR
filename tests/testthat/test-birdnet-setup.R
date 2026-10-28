test_that("installs the BirdNET model from its archive, checking it", {
  skip_if(!nzchar(Sys.which("zip")), "zip is not installed")
  # A fake model archive served from a local file
  src <- tempfile("model_")
  dir.create(file.path(src, "labels"), recursive = TRUE)
  writeBin(raw(10), file.path(src, "audio-model.tflite"))
  writeBin(raw(20), file.path(src, "meta-model.tflite"))
  writeLines("Cettia cetti_Cetti's Warbler", file.path(src, "labels", "en_us.txt"))
  zip <- tempfile(fileext = ".zip")
  old <- setwd(src)
  utils::zip(zip, c("audio-model.tflite", "meta-model.tflite", "labels/en_us.txt"), flags = "-q")
  setwd(old)
  target <- tempfile("TFLite_")
  spec <- list("v2.4" = list(url = paste0("file://", zip), size = file.size(zip),
                             md5 = unname(tools::md5sum(zip)),
                             files = c("audio-model.tflite" = 10, "meta-model.tflite" = 20)))
  local_mocked_bindings(birdnet_model_dir = function(version) target, birdnet_model_files = spec)
  expect_false(AudiomothR:::birdnet_model_ok())
  suppressMessages(AudiomothR:::ensure_birdnet_model())
  expect_true(AudiomothR:::birdnet_model_ok())
  expect_true(file.exists(file.path(target, "labels", "en_us.txt")))

  # A corrupted download is an error
  unlink(target, recursive = TRUE)
  spec[["v2.4"]]$md5 <- "0"
  local_mocked_bindings(birdnet_model_files = spec)
  expect_error(suppressMessages(AudiomothR:::ensure_birdnet_model(attempts = 1)), "Cannot download")
})

test_that("knows where birdnet keeps the model on each system", {
  dir <- AudiomothR:::birdnet_model_dir()
  expect_match(dir, "birdnet[/\\\\]models[/\\\\]v2.4[/\\\\]TFLite$")
})
