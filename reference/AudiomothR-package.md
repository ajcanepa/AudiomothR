# AudiomothR: Acoustic Processing of 'AudioMoth' Recordings with 'BirdNET'

Reads the cards of 'AudioMoth' recorders (Hill et al. 2018)
[doi:10.1111/2041-210X.12955](https://doi.org/10.1111/2041-210X.12955)
('CONFIG.TXT' file and daily folders), optionally copies them to the
disk, prepares the audio and analyses it with 'BirdNET' (Kahl et al.
2021)
[doi:10.1016/j.ecoinf.2021.101236](https://doi.org/10.1016/j.ecoinf.2021.101236)
through 'birdnetR', with the species expected at the site or an own list
of species (which can be built from the observations published in 'GBIF'
around the recorder). Saves the detections as CSV files, extracts
high-confidence examples of the chosen species with their audio and a
video of the spectrogram, creates a web page to validate the records by
ear, and converts the detections into the import format of
'Observation.org', translating the species names into the IOC World Bird
List. It also creates a PDF report with 'Quarto' of one or several
recorders, with a map, the state of the recordings and the detected
species.

## See also

Useful links:

- <https://github.com/ajcanepa/AudiomothR>

- <https://ajcanepa.github.io/AudiomothR/>

- Report bugs at <https://github.com/ajcanepa/AudiomothR/issues>

## Author

**Maintainer**: Antonio Canepa-Oneto <ajcanepa@gmail.com>
([ORCID](https://orcid.org/0000-0002-0608-2743))

Authors:

- Antonio Canepa-Oneto <ajcanepa@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-0608-2743))

- Patricia de la Fuente Gamero
  ([ORCID](https://orcid.org/0000-0002-6048-1534))

- José Antonio Barbero-Aparicio
  ([ORCID](https://orcid.org/0000-0002-3269-0806))

- Julia Guerra Carande ([ORCID](https://orcid.org/0000-0002-7398-3402))

- Claudia Fernández-Ruiz
  ([ORCID](https://orcid.org/0009-0005-6450-3605))

- Alicia Olivares ([ORCID](https://orcid.org/0000-0002-3378-197X))

- Raúl Marticorena-Sánchez
  ([ORCID](https://orcid.org/0000-0002-2633-635X))
