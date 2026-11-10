# Builds inst/extdata/taxonomy/birdnet_v2.4_to_gbif.csv.gz: the GBIF species
# (accepted name and key of the GBIF Backbone Taxonomy) of every bird of
# BirdNET v2.4, used by gbif_species_list() to turn the species found by GBIF
# around a site into BirdNET names. GBIF resolves the synonyms itself: the
# occurrences of "Parus caeruleus" are counted under the accepted species
# (Cyanistes caeruleus), whose key is the one stored here.
#
# Run from the root of the package (needs internet; about 10 minutes):
#   Rscript data-raw/build_gbif_keys.R
# Rebuild it when GBIF changes its backbone taxonomy (keys may change).

tax <- read.csv(gzfile("inst/extdata/taxonomy/birdnet_v2.4_to_ioc_15.2.csv.gz"), stringsAsFactors = FALSE)
birds <- tax$birdnet_name[tax$match != "not_bird"]

match_one <- function(name) {
  url <- paste0("https://api.gbif.org/v1/species/match?class=Aves&strict=true&name=",
                utils::URLencode(name, reserved = TRUE))
  for (attempt in 1:5) {
    res <- tryCatch(jsonlite::fromJSON(url), error = function(e) NULL)
    if (!is.null(res)) break
    Sys.sleep(2 * attempt)
  }
  if (is.null(res)) stop("GBIF does not answer for ", name)
  # Homonyms with plants or insects (Chloris chloris, Ortalis guttata...):
  # the strict match gives no species, so the bird among the alternatives of
  # a verbose match is taken
  if (is.null(res$speciesKey)) {
    url2 <- paste0("https://api.gbif.org/v1/species/match?kingdom=Animalia&verbose=true&name=",
                   utils::URLencode(name, reserved = TRUE))
    all <- tryCatch(jsonlite::fromJSON(url2, simplifyVector = FALSE), error = function(e) NULL)
    candidates <- c(list(all), all$alternatives)
    birds <- Filter(function(a) identical(a$class, "Aves") && !is.null(a$speciesKey) &&
                      identical(a$canonicalName, name), candidates)
    if (length(birds)) res <- birds[[1]]
  }
  get <- function(k) if (is.null(res[[k]])) NA else res[[k]]
  data.frame(birdnet_name = name, gbif_species = get("species"), gbif_key = get("speciesKey"),
             gbif_match = get("matchType"), gbif_status = get("status"), stringsAsFactors = FALSE)
}

# 8 requests at a time (on Windows mclapply runs them one by one: ~1 hour)
out <- parallel::mclapply(birds, match_one, mc.cores = 8)
failed <- vapply(out, inherits, logical(1), "try-error")
if (any(failed)) stop("GBIF did not answer for ", sum(failed), " names: run the script again")
out <- do.call(rbind, out)
# Only species-level matches are useful (HIGHERRANK = only the genus is known)
out$gbif_key[is.na(out$gbif_species)] <- NA
message("Without a GBIF species: ", sum(is.na(out$gbif_key)), " of ", nrow(out))
con <- gzfile("inst/extdata/taxonomy/birdnet_v2.4_to_gbif.csv.gz", "w", encoding = "UTF-8")
utils::write.csv(out, con, row.names = FALSE, na = "")
close(con)
