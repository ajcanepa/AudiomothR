# Reads coordinates in any of the usual formats

Meant for copying and pasting the position of a point from Google Earth,
Google Maps or a GPS. Recognises:

## Usage

``` r
parse_coordinates(text)
```

## Arguments

- text:

  Text with the coordinates, or a numeric vector
  `c(latitude, longitude)` (named `c(lat = , lon = )` in any order).

## Value

A list with `lat`, `lon` (decimal degrees, WGS84) and `precision_m`:
approximate uncertainty (metres) due to the number of decimals written.

## Details

|  |  |
|----|----|
| Format | Example |
| Decimal degrees (Google Maps / Earth) | `"41.123456, -3.123456"` |
| Degrees, minutes and seconds | `"41°07'24.4\"N 3°07'24.4\"W"` |
| Spanish hemisphere letters (O = west) | `"41°07'24.4\"N 3°07'24.4\"O"` |
| Degrees and decimal minutes | `"41°07.407'N 3°07.407'W"` |
| Hemisphere first (handheld GPS) | `"N41 07.407 W3 07.407"` |
| Hemisphere words | `"41.1234 North, 3.1234 West"` |
| Without symbols | `"41 07 24.4 N 3 07 24.4 W"` |
| Google Earth placemark (KML) | `"<coordinates>-3.1234,41.1234,0</coordinates>"` |
| Google Maps link (marked point) | `"https://www.google.com/maps?q=41.1234,-3.1234"` |
| Decimal comma | `"41,123456 -3,123456"` |
| Numeric vector | `c(41.123456, -3.123456)` or `c(lon = -3.1, lat = 41.1)` |

Without hemisphere letters the **latitude goes first** (as in Google)
and a negative longitude is west. Typographic minus signs and quotes
(copied from PDF or Word documents) are accepted. Texts that do not
contain coordinates (short links, Plus Codes, notes) are rejected.

## Examples

``` r
parse_coordinates("41.123456, -3.123456")
#> $lat
#> [1] 41.12346
#> 
#> $lon
#> [1] -3.123456
#> 
#> $precision_m
#> [1] 1
#> 
parse_coordinates("41°07'24.4\"N 3°07'24.4\"O")
#> $lat
#> [1] 41.12344
#> 
#> $lon
#> [1] -3.123444
#> 
#> $precision_m
#> [1] 2
#> 
parse_coordinates("N41 07.407 W3 07.407")
#> $lat
#> [1] 41.12345
#> 
#> $lon
#> [1] -3.12345
#> 
#> $precision_m
#> [1] 2
#> 
parse_coordinates(c(41.12, -3.12))
#> $lat
#> [1] 41.12
#> 
#> $lon
#> [1] -3.12
#> 
#> $precision_m
#> [1] 697
#> 
```
