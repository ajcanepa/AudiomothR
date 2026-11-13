# Installs and checks BirdNET

Prepares everything
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
needs, so that the first analysis does not stop half-way: downloads the
BirdNET model (with retries and an integrity check), lets birdnetR
install its Python environment (Python 3.11, TensorFlow and the
'birdnet' package, about 3 GB, with uv; nothing has to be installed by
hand on Windows, macOS or Linux) and loads the model once. It only takes
time the first time; afterwards it returns at once. Running it is
optional:
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
does the same when needed.

## Usage

``` r
setup_birdnet(version = "v2.4", language = default_language())
```

## Arguments

- version:

  Version of the BirdNET model.

- language:

  Language of the common names to check.

## Value

Invisibly, `TRUE` when BirdNET works.

## Examples

``` r
if (FALSE) { # \dontrun{
# Not run: it installs Python, TensorFlow and the BirdNET model (about 3 GB)
setup_birdnet()
} # }
```
