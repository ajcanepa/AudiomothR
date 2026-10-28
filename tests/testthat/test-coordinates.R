test_that("reads the formats of Google Earth, Google Maps and AudioMoth", {
  dec <- parse_coordinates("41.123456, -3.123456")
  expect_equal(c(dec$lat, dec$lon), c(41.123456, -3.123456))
  expect_equal(dec$precision_m, 1L)

  dms <- parse_coordinates("41°07'24.4\"N 3°07'24.4\"W")
  expect_equal(dms$lat, 41 + 7 / 60 + 24.4 / 3600, tolerance = 1e-6)
  expect_equal(dms$lon, -(3 + 7 / 60 + 24.4 / 3600), tolerance = 1e-6)

  # Google Earth Pro in Spanish (O = west) and typographic symbols
  es <- parse_coordinates("41º07′24.4″N, 3º07′24.4″O")
  expect_equal(c(es$lat, es$lon), c(dms$lat, dms$lon))

  inv <- parse_coordinates("3.1234°W 41.1234°N")
  expect_equal(c(inv$lat, inv$lon), c(41.1234, -3.1234))

  dm <- parse_coordinates("41°07.407'N 3°07.407'W")
  expect_equal(dm$lat, 41 + 7.407 / 60, tolerance = 1e-6)

  kml <- parse_coordinates("<Point><coordinates>-3.123456,41.123456,0</coordinates></Point>")
  expect_equal(c(kml$lat, kml$lon), c(41.123456, -3.123456))

  comma <- parse_coordinates("41,123456 -3,123456")
  expect_equal(c(comma$lat, comma$lon), c(41.123456, -3.123456))

  am <- parse_coordinates("41.00°N 3.00°W")
  expect_equal(c(am$lat, am$lon), c(41, -3))
  expect_gt(am$precision_m, 500) # two decimals: ~700 m
})

test_that("reads the hemisphere before the number and written in words", {
  expect_equal(parse_coordinates("N41.12345° W003.12345°")$lon, -3.12345)
  expect_equal(parse_coordinates("N 41.123456 W 3.123456")$lon, -3.123456)
  expect_equal(parse_coordinates("S33.856 E151.215")$lat, -33.856)
  expect_equal(parse_coordinates("41.123456 Norte, 3.123456 Oeste")$lon, -3.123456)
  expect_equal(parse_coordinates("41.123456 North, 3.123456 West")$lon, -3.123456)
  expect_equal(parse_coordinates("41.123456N3.123456W")$lon, -3.123456)
  expect_equal(parse_coordinates("N41 07.407 W3 07.407")$lon, -(3 + 7.407 / 60), tolerance = 1e-6)
})

test_that("reads degrees, minutes and seconds separated by spaces", {
  expect_equal(parse_coordinates("41 07.407 N 3 07.407 W")$lat, 41 + 7.407 / 60, tolerance = 1e-6)
  x <- parse_coordinates("41 07 24.4 N 3 07 24.4 W")
  expect_equal(c(x$lat, x$lon), c(41 + 7 / 60 + 24.4 / 3600, -(3 + 7 / 60 + 24.4 / 3600)), tolerance = 1e-6)
  y <- parse_coordinates("41 07 24.4, -3 07 24.4")
  expect_equal(y$lon, x$lon, tolerance = 1e-6)
  expect_error(parse_coordinates("41°75'N 3°07'W"), "between 0 and 59")
  expect_error(parse_coordinates("41.5°21'N 3°07'W"), "only the last component")
})

test_that("accepts typographic minus signs, labels and Google Maps links", {
  expect_equal(parse_coordinates("41.123456, −3.123456")$lon, -3.123456)
  expect_equal(parse_coordinates("41.123456, –3.123456")$lon, -3.123456)
  expect_equal(parse_coordinates("Box 2: 41.123456, -3.123456")$lat, 41.123456)
  # The marked point, not the centre of the map view ("@")
  url <- parse_coordinates("https://www.google.com/maps/place/41%C2%B007'24.4%22N+3%C2%B007'24.4%22W/@41.1234567,-3.1334567,17z")
  expect_equal(c(url$lat, url$lon), c(41 + 7 / 60 + 24.4 / 3600, -(3 + 7 / 60 + 24.4 / 3600)), tolerance = 1e-6)
  expect_equal(parse_coordinates("https://www.google.com/maps?q=41.123456,-3.123456")$lon, -3.123456)
  expect_equal(parse_coordinates("https://www.google.com/maps/place/x/data=!3d41.123456!4d-3.123456")$lat, 41.123456)
  expect_error(parse_coordinates("https://www.google.com/maps/@41.1234567,-3.1234567,17z"), "centre of the map")
  expect_error(parse_coordinates("https://maps.app.goo.gl/5rTbQhGkUe1VsA"), "does not contain the coordinates")
})

test_that("rejects texts that are not coordinates", {
  expect_error(parse_coordinates("by the river"), "Cannot read")
  expect_error(parse_coordinates("9C8V+FX Burgos"), "Cannot read")
  expect_error(parse_coordinates("Box 2 by the river, plot 7"), "Cannot read")
  expect_error(parse_coordinates("41, -3"), "whole numbers")
  expect_error(parse_coordinates("95.1, -3.2"), "out of range")
  expect_error(parse_coordinates("41.1°N 3.2°S"), "latitude")
  expect_error(parse_coordinates(c(41, NA)), "missing")
})

test_that("a numeric vector keeps its precision and may be named", {
  x <- parse_coordinates(c(41.123456, -3.123456))
  expect_equal(x$precision_m, 1L)
  expect_gt(parse_coordinates(c(41.1, -3.1))$precision_m, 5000)
  y <- parse_coordinates(c(lon = -3.12, lat = 41.12))
  expect_equal(c(y$lat, y$lon), c(41.12, -3.12))
})
