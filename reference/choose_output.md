# Asks for the results folder

Asks in the console for the folder where the results of a card are saved
(a path can be typed, pasted or dragged from the file manager). Pressing
Enter accepts the suggested folder. The folder does not need to exist.
[`read_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/read_audiomoth.md)
and
[`process_audiomoth()`](https://ajcanepa.github.io/AudiomothR/reference/process_audiomoth.md)
call it when `output` is not given.

## Usage

``` r
choose_output(suggested = file.path("~", "AudiomothR_results"))
```

## Arguments

- suggested:

  Folder proposed by default.

## Value

The path of the chosen folder.

## Examples

``` r
if (interactive()) choose_output("~/AudiomothR_results/box_01")
```
