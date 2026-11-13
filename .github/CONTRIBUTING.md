# Contributing to AudiomothR

Thank you for your interest in AudiomothR. Comments, questions, bug reports
and improvements are welcome, from users of every level: you do not need to
write code to help.

## Asking a question or reporting a problem

Open an [issue](https://github.com/ajcanepa/AudiomothR/issues/new/choose)
and choose the template that fits. For a problem, please include:

- what you ran (the R code) and the full message you got;
- the output of `AudiomothR::check_requirements()` and of `sessionInfo()`;
- if the problem comes from a card, its `CONFIG.TXT` and the names of a few
  WAV files. Please **do not attach real recordings or exact locations of
  sensitive species**: the example card of the package
  (`system.file("extdata", "example", "card", package = "AudiomothR")`) is
  often enough to reproduce a problem.

Issues may be written in English or Spanish.

## Proposing a change

Small fixes (typos, documentation) can go directly as a pull request. For
anything bigger, please open an issue first, so that we can agree on the
design before you spend time on it.

1. Fork the repository and create a branch from `main`.
2. Install the development dependencies:
   `install.packages(c("devtools", "testthat", "knitr", "rmarkdown"))`.
3. Make your change, with tests in `tests/testthat/` when it changes what a
   function does.
4. Update the documentation with `devtools::document()` and check the
   package with `devtools::check()`: it should give 0 errors, 0 warnings and
   0 notes.
5. Add a line to `NEWS.md`, at the top, describing the change for users.
6. Open the pull request, describing what it changes and why.

## Conventions of the code

- The whole package is in English: function and argument names, messages,
  comments, documentation and vignettes.
- R code must be ASCII: write non-ASCII characters in strings as `\uxxxx`
  escapes (comments and roxygen may have accents).
- Messages with [cli](https://cli.r-lib.org) through the internal helpers
  `inform()` (it respects `options(AudiomothR.quiet = TRUE)`) and `abort()`.
- External programs (ffmpeg, Quarto) are always run with `processx::run()`,
  with the arguments as a vector.
- Documentation with roxygen2 in markdown; do not edit the files in `man/`
  by hand.
- Tests use testthat 3 and a synthetic card (`tests/testthat/helper-card.R`);
  BirdNET and GBIF are mocked, so the tests run without Python or Internet.

## Code of conduct

Please note that AudiomothR is released with a
[Contributor Code of Conduct](CODE_OF_CONDUCT.md). By contributing to this
project you agree to abide by its terms.
