# Chooses the folder of an AudioMoth card with a dialog

Opens the folder chooser of RStudio or, when it is not available, the
Tcl/Tk one. Without a graphical interface it asks for the path in the
console (a folder dragged from the file manager into the terminal is
accepted, with its escaped spaces).

## Usage

``` r
choose_folder(start = getwd())
```

## Arguments

- start:

  Folder where the dialog opens.

## Value

Path of the chosen folder (the one that contains CONFIG.TXT).

## Examples

``` r
if (interactive()) choose_folder()
```
