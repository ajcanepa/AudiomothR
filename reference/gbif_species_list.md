# Builds a list of species from GBIF around a site

Asks GBIF (<https://www.gbif.org>) which bird species have been observed
within `radius_km` of the recorder, in the months of the recordings, in
the datasets of eBird, Observation.org and iNaturalist that GBIF
publishes. No account or key is needed (it uses the public occurrence
search of the GBIF API), but it does need an internet connection. The
result can be given directly to
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
with `species_list`, saved with `file` to be reviewed or edited (e.g. in
a spreadsheet), or merged with an own list.

## Usage

``` r
gbif_species_list(
  x,
  radius_km = 25,
  months = NULL,
  years = NULL,
  datasets = c("ebird", "observation", "inaturalist"),
  min_records = 1,
  file = NULL
)
```

## Arguments

- x:

  An `audiomoth` object (the locations of its deployments and, by
  default, the months of its recordings) or coordinates in any format
  accepted by
  [`parse_coordinates()`](https://ajcanepa.github.io/AudiomothR/reference/parse_coordinates.md).

- radius_km:

  Radius around each site, in km. Larger radii (25-50 km) give a more
  complete list in little visited areas; very large ones bring species
  of other habitats.

- months:

  Months (1 to 12) of the observations. By default, the months of the
  recordings of `x` (all the year for plain coordinates); `1:12` for all
  the year.

- years:

  Years of the observations: two values, from and to. By default the
  last ten years.

- datasets:

  Sources: any of `"ebird"`, `"observation"` and `"inaturalist"`
  (default, all three), or `"all"` for every dataset of GBIF (also
  museum collections and other surveys).

- min_records:

  Minimum number of occurrences for a species to enter the list (e.g. 2
  or 3 to leave out single, perhaps wrong, records).

- file:

  Optional path of a CSV file where the list is saved.

## Value

A data frame with one row per BirdNET species, sorted by the number of
occurrences: `scientific_name` (BirdNET), `english_name`, `gbif_name`,
`records` and `match`. It can be given to
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md)
as `species_list`.

## Details

**Why.** The location filter of BirdNET (see
[`analyze_birdnet()`](https://ajcanepa.github.io/AudiomothR/reference/analyze_birdnet.md))
predicts the species expected at a site from the eBird checklists, so it
may leave out species that are present but rarely recorded there:
nocturnal or secretive species (owls, Stone-curlew...), steppe birds in
little visited areas, scarce migrants. A list of the species actually
observed around the site, in a wide enough radius, keeps them, while
still leaving out the species of other continents.

**How.** One query per site (the different locations of the deployments
of the box) with the GBIF occurrence search, counting the occurrences of
each species (`facet=speciesKey`) of the class Aves, present (not
absences), without geospatial issues. GBIF resolves the synonyms, and
the species are translated into BirdNET v2.4 names with a table of the
package (GBIF Backbone Taxonomy). Species of GBIF that BirdNET cannot
detect are reported in the attribute `"not_in_birdnet"`.

**Citation.** The data belong to the observers and to the publishers of
each dataset. When the list is used in a publication, cite GBIF and the
datasets (e.g. "GBIF.org (2026) GBIF Occurrence Search, , accessed on ";
the queries are in the attribute `"queries"`). The result is a summary
(counts per species), not a GBIF download with a DOI.

## See also

[`read_species_list()`](https://ajcanepa.github.io/AudiomothR/reference/read_species_list.md)
for the accepted formats of a list.

## Examples

``` r
if (FALSE) { # interactive()
# Needs an Internet connection
# Around a site, all the year
sp <- gbif_species_list("41.35, -3.70", radius_km = 25)
head(sp)

# Around the deployments of a box, in the months of its recordings, saved
# to be reviewed and then used in the analysis
card <- system.file("extdata", "example", "card", package = "AudiomothR")
am <- read_audiomoth(card, coordinates = "41.00, -3.00", output = tempfile())
list_file <- tempfile(fileext = ".csv")
sp <- gbif_species_list(am, radius_km = 30, file = list_file)
# am <- analyze_birdnet(am, species_list = list_file)
}
```
