# Builds the taxonomy tables in inst/extdata/taxonomy/ used by
# export_observation() to translate BirdNET v2.4 labels into the names of the
# IOC World Bird List v15.2 (the taxonomy used by Observation.org).
#
# Sources (downloaded on 2026-10-28):
#   - BirdNET v2.4 labels, from the TFLite model archive used by the Python
#     package 'birdnet' 0.1.7 (and therefore by birdnetR):
#     https://zenodo.org/records/15050749/files/BirdNET_v2.4_tflite.zip
#     (files labels/en_us.txt and labels/en_uk.txt).
#   - IOC World Bird List v15.2 compared with other checklists:
#     https://www.worldbirdnames.org/IOC_15.2_vs_other_lists.xlsx
#   - IOC World Bird List v15.2 with English and Spanish names (the previous
#     inst/extdata/taxonomia/ioc_15.2_aves.csv of AudiomothR 0.2.0, built from
#     https://worldbirdnames.org/Multiling%20IOC%2015.2.xlsx).
#
# Usage, from the package root:
#   Rscript data-raw/build_taxonomy.R <folder with the downloaded files>
# The folder must contain labels/en_us.txt, labels/en_uk.txt, ioc_vs.xlsx and
# ioc_15.2_aves.csv. Needs the 'readxl' package (not a package dependency).
#
# Matching rules, in order, for each BirdNET label:
#   1. Not a bird (non-species classes such as "Engine" or "Human vocal", and
#      the amphibians, insects and mammals of the model) -> no IOC name.
#   2. Manual table below (lumps, splits and cases checked by hand).
#   3. Same binomial in IOC 15.2 (match = "same"). If the IOC English name is
#      the BirdNET one plus a qualifier ("Red-rumped Swallow" -> "Eastern
#      Red-rumped Swallow"), IOC has split the species and the binomial may
#      now refer to another population (match = "split"):
#      export_observation() warns about them. Splits with a clear geographic
#      rule are handled by regional_rules.csv (written by hand).
#   4. Binomial used by another checklist of the IOC comparison file
#      (Clements, HBW/BirdLife, Howard & Moore, Peters...) -> its IOC species
#      (match = "synonym"); if it maps to several IOC species, the one with the
#      same English name.
#   5. Same English name in IOC 15.2 (match = "english").
# Anything left is a bird without an IOC name (match = "none") and is listed
# at the end so that it can be added to the manual table.

args <- commandArgs(TRUE)
src <- if (length(args)) args[1] else "data-raw/sources"
out_dir <- file.path("inst", "extdata", "taxonomy")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- BirdNET labels ----------------------------------------------------------

read_labels <- function(file) {
  l <- readLines(file, encoding = "UTF-8", warn = FALSE)
  l <- l[nzchar(l)]
  data.frame(sci = sub("_.*$", "", l), common = sub("^[^_]*_", "", l), stringsAsFactors = FALSE)
}
en <- read_labels(file.path(src, "labels", "en_us.txt"))
uk <- read_labels(file.path(src, "labels", "en_uk.txt"))   # IOC uses British spelling
stopifnot(identical(en$sci, uk$sci), !anyDuplicated(en$sci))

# --- IOC 15.2 ---------------------------------------------------------------

vs <- as.data.frame(readxl::read_excel(file.path(src, "ioc_vs.xlsx")))
vs <- vs[vs$Rank == "species", , drop = FALSE]
ioc_col <- 2
other_cols <- grep("AviList|Clements|HBW and BirdLife|Howard and Moore|del Hoyo|Peters|TiF|Gaudin|Sibley|v15.1",
                   names(vs))
other_cols <- setdiff(other_cols, grep("^Family|^Group", names(vs)))

ioc <- utils::read.csv(file.path(src, "ioc_15.2_aves.csv"), encoding = "UTF-8",
                       stringsAsFactors = FALSE)
names(ioc) <- c("ioc_name", "english", "spanish")
stopifnot(all(ioc$ioc_name %in% vs[[ioc_col]]))

norm_english <- function(x) {
  x <- tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT"))
  x <- gsub("gray", "grey", x, fixed = TRUE)
  gsub("[^a-z]", "", x)
}

# --- Not birds ---------------------------------------------------------------

# Non-species classes of BirdNET v2.4
non_species <- c("Dog", "Engine", "Environmental", "Fireworks", "Gun", "Human non-vocal",
                 "Human vocal", "Human whistle", "Noise", "Power tools", "Siren")

# Labels that are not birds are recognised by their genus (amphibians,
# insects and mammals of the model); checked by hand on the list printed at
# the end of this script.
non_bird_genera <- c(
  # Amphibians
  "Acris", "Agalychnis", "Alytes", "Anaxyrus", "Bombina", "Boana", "Bufo", "Craugastor",
  "Crinia", "Dendropsophus", "Dryophytes", "Eleutherodactylus", "Epidalea", "Hyla",
  "Hyliola", "Incilius", "Leptodactylus", "Limnodynastes", "Lithobates", "Litoria",
  "Pelobates", "Pelophylax", "Pseudacris", "Rana", "Rhinella", "Scaphiopus", "Smilisca",
  "Spea", "Uperoleia", "Rhacophorus", "Kaloula", "Microhyla", "Polypedates", "Ascaphus",
  "Gastrophryne", "Hypopachus", "Osteopilus", "Trachycephalus", "Engystomops", "Physalaemus",
  "Pristimantis", "Scinax", "Hylarana", "Fejervarya", "Duttaphrynus", "Crossodactylus",
  "Geocrinia", "Heleioporus", "Neobatrachus", "Pseudophryne", "Platyplectrum",
  # Insects
  "Allonemobius", "Amblycorypha", "Anaxipha", "Atlanticus", "Conocephalus", "Cyrtoxipha",
  "Eunemobius", "Gryllus", "Hapithus", "Microcentrum", "Neoconocephalus", "Neonemobius",
  "Oecanthus", "Orchelimum", "Orocharis", "Pterophylla", "Scudderia", "Tettigonia",
  "Pholidoptera", "Roeseliana", "Chorthippus", "Tibicen", "Neotibicen", "Magicicada",
  "Megatibicen", "Okanagana", "Diceroprocta", "Cicada", "Lyristes", "Gryllotalpa",
  "Acheta", "Teleogryllus", "Nemobius", "Ephippiger", "Platycleis", "Decticus",
  "Tettigettalna", "Cicadetta", "Tylopsis", "Leptophyes", "Meconema", "Barbitistes",
  "Bicolorana", "Metrioptera", "Ruspolia", "Euchorthippus", "Omocestus", "Stenobothrus",
  "Gomphocerippus", "Pseudochorthippus", "Myrmeleotettix", "Stethophyma",
  # Mammals
  "Canis", "Vulpes", "Sciurus", "Tamias", "Tamiasciurus", "Odocoileus", "Cervus", "Alces",
  "Capreolus", "Dama", "Lynx", "Felis", "Procyon", "Ochotona", "Marmota", "Spermophilus",
  "Urocitellus", "Callospermophilus", "Otospermophilus", "Ictidomys", "Poliocitellus",
  "Cynomys", "Glaucomys", "Erethizon", "Lepus", "Sylvilagus", "Sus", "Bos", "Ovis",
  "Capra", "Equus", "Homo", "Alouatta", "Ateles", "Cebus", "Saimiri", "Callithrix",
  "Hylobates", "Nomascus", "Symphalangus", "Pan", "Gorilla", "Pongo", "Macaca", "Papio",
  "Tursiops", "Delphinus", "Orcinus", "Megaptera", "Balaenoptera", "Physeter",
  "Neovison", "Mustela", "Lutra", "Lontra", "Phoca", "Halichoerus", "Zalophus",
  "Eumetopias", "Mirounga", "Arctocephalus", "Ursus", "Puma", "Panthera", "Didelphis",
  "Trichosurus", "Pteropus", "Rattus", "Mus", "Microtus", "Peromyscus", "Neotoma",
  "Tamiops", "Callosciurus", "Funambulus", "Ratufa", "Petaurista", "Muntiacus", "Rusa",
  "Axis", "Elaphurus", "Hydropotes", "Antilocapra", "Bison", "Ovibos", "Rangifer",
  "Nasua", "Potos", "Bassariscus", "Taxidea", "Meles", "Martes", "Gulo", "Ailurus",
  "Ailuropoda", "Pecari", "Tayassu", "Dicotyles",
  # Insects not covered above
  "Apis", "Miogryllus", "Phyllopalpus"
)
genus <- sub(" .*$", "", en$sci)
not_bird <- en$sci %in% non_species | (genus %in% non_bird_genera & !en$sci %in% ioc$ioc_name)

# --- Manual table -----------------------------------------------------------

# BirdNET name = IOC 15.2 name, checked by hand (lumps, and splits where the
# population covered by BirdNET is unambiguous). Splits that depend on the
# region (e.g. Cecropis daurica in Europe) are in regional_rules.csv.
manual <- c(
  "Acanthis cabaret" = "Acanthis flammea",
  "Acanthis hornemanni" = "Acanthis flammea",
  "Acrocephalus baeticatus" = "Acrocephalus scirpaceus",
  # Species of BirdNET that are subspecies in IOC 15.2
  "Asthenes sclateri" = "Asthenes wyatti",
  "Calendulauda alopex" = "Calendulauda africanoides",
  "Caprimulgus nigriscapularis" = "Caprimulgus pectoralis",
  "Cecropis striolata" = "Cecropis daurica",
  "Celeus grammicus" = "Celeus undatus",
  "Colluricincla rufogaster" = "Colluricincla megarhyncha",
  "Cyanoderma ambiguum" = "Cyanoderma rufifrons",
  "Dicrurus divaricatus" = "Dicrurus adsimilis",
  "Empidonax occidentalis" = "Empidonax difficilis",
  "Haliaeetus ichthyaetus" = "Icthyophaga ichthyaetus",
  "Horornis vulcanius" = "Horornis flavolivaceus",
  "Lichmera limbata" = "Lichmera indistincta",
  "Neocossyphus finschi" = "Stizorhina finschi",
  "Pachycephala fulvotincta" = "Pachycephala calliope",
  "Parus minor" = "Parus cinereus",
  "Phylloscopus occisinensis" = "Phylloscopus affinis",
  "Pteruthius ripleyi" = "Pteruthius aeralatus",
  "Serpophaga munda" = "Serpophaga subcristata",
  "Sporophila murallae" = "Sporophila americana"
)

# --- Matching ----------------------------------------------------------------

tab <- data.frame(birdnet_name = en$sci, birdnet_english = en$common, birdnet_uk = uk$common,
                  ioc_name = NA_character_, match = NA_character_, stringsAsFactors = FALSE)
tab$match[not_bird] <- "not_bird"

todo <- is.na(tab$match) & tab$birdnet_name %in% names(manual)
tab$ioc_name[todo] <- manual[tab$birdnet_name[todo]]
tab$match[todo] <- "manual"

todo <- is.na(tab$match) & tab$birdnet_name %in% ioc$ioc_name
tab$ioc_name[todo] <- tab$birdnet_name[todo]
a <- norm_english(tab$birdnet_uk)
b <- norm_english(ioc$english[match(tab$ioc_name, ioc$ioc_name)])
tab$match[todo] <- ifelse(a[todo] != b[todo] & endsWith(b[todo], a[todo]), "split", "same")

for (i in which(is.na(tab$match))) {
  hit <- unique(unlist(lapply(other_cols, function(k) vs[[ioc_col]][which(vs[[k]] == tab$birdnet_name[i])])))
  hit <- hit[!is.na(hit)]
  if (length(hit) > 1) {
    eng <- hit[norm_english(ioc$english[match(hit, ioc$ioc_name)]) == norm_english(tab$birdnet_uk[i])]
    if (length(eng) == 1) hit <- eng
  }
  if (length(hit) == 1) {
    tab$ioc_name[i] <- hit
    tab$match[i] <- "synonym"
  }
}

todo <- which(is.na(tab$match))
by_english <- match(norm_english(tab$birdnet_uk[todo]), norm_english(ioc$english))
ok <- !is.na(by_english)
tab$ioc_name[todo[ok]] <- ioc$ioc_name[by_english[ok]]
tab$match[todo[ok]] <- "english"
tab$match[is.na(tab$match)] <- "none"

tab$ioc_english <- ioc$english[match(tab$ioc_name, ioc$ioc_name)]
stopifnot(all(is.na(tab$ioc_name) | tab$ioc_name %in% ioc$ioc_name))

# --- Write -------------------------------------------------------------------

write_gz <- function(x, file) {
  con <- gzfile(file, "w", encoding = "UTF-8")
  on.exit(close(con))
  utils::write.csv(x, con, row.names = FALSE, na = "")
}
write_gz(tab[, c("birdnet_name", "birdnet_english", "ioc_name", "ioc_english", "match")],
         file.path(out_dir, "birdnet_v2.4_to_ioc_15.2.csv.gz"))
write_gz(ioc, file.path(out_dir, "ioc_15.2_birds.csv.gz"))

print(table(tab$match))
cat("\nBirds without an IOC name (add them to `manual`):\n")
print(tab[tab$match == "none", c("birdnet_name", "birdnet_english")], row.names = FALSE)
cat("\nSame binomial, split in IOC (export_observation() warns):\n")
print(tab[tab$match == "split", c("birdnet_name", "birdnet_uk", "ioc_english")], row.names = FALSE)

rules <- utils::read.csv(file.path(out_dir, "regional_rules.csv"), stringsAsFactors = FALSE)
stopifnot(all(rules$ioc_name %in% ioc$ioc_name), all(rules$birdnet_name %in% tab$birdnet_name))
