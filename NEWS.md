# AudiomothR 0.3.0

## Breaking changes

* The package is now in English: functions, arguments, messages, help, the
  vignette, the PDF report and the columns and names of the result files.
  Equivalences with version 0.2.0:

  | 0.2.0 | 0.3.0 |
  |---|---|
  | `leer_audiomoth(carpeta, coordenadas, punto, precision_m, zona_horaria, salida)` | `read_audiomoth(folder, coordinates, site, precision_m, time_zone, output)` |
  | `leer_config()` | `read_config()` |
  | `parsear_coordenadas()` | `parse_coordinates()` |
  | `seleccionar_carpeta()` | `choose_folder()` |
  | `preparar_audios()` | `prepare_audio()` |
  | `analizar_birdnet(confianza_minima, idioma, filtro_ubicacion, umbral_ubicacion, solapamiento, sensibilidad, hilos, reanalizar)` | `analyze_birdnet(min_confidence, language, location_filter, location_threshold, overlap, sensitivity, threads, reanalyze)` |
  | `leer_detecciones()` | `read_detections()` |
  | `resumen_especies()` | `species_summary()` |
  | `especies_detectadas(confianza_ejemplos)` | `detected_species(example_confidence)` |
  | `seleccionar_ejemplos()` | `select_examples()` |
  | `extraer_ejemplos(margen_s, estilo = "desplazamiento")` | `extract_examples(margin_s, style = "scroll")` |
  | `imagen_espectrograma()`, `video_espectrograma()` | `spectrogram_image()`, `spectrogram_video()` |
  | `exportar_observation(min_detecciones, solo_sin_dudas, desde, hasta, equivalencias, archivo)` | `export_observation(min_detections, no_doubts_only, from, to, equivalences, file)` |
  | `crear_informe(cajas, por_caja, salida, titulo, abrir)` | `create_report(recorders, by_recorder, output, title, open)` |
  | `procesar_audiomoth(especies_ejemplo, n_ejemplos, confianza_ejemplos, estilo_video, informe)` | `process_audiomoth(example_species, n_examples, example_confidence, video_style, report)` |
  | `comprobar_requisitos()` | `check_requirements()` |

  Results files: `AudioMoth_<ID>_recordings.csv`, `_detections.csv`,
  `_observation.csv`, `examples/`, `report/` and `validation/`. Results of
  version 0.2.0 must be produced again (the BirdNET cache has a new layout).
* The language of the common names is taken from the operating system
  (`language` in `analyze_birdnet()`); notes of Observation.org are in
  English unless the language is Spanish.
* The minimum confidence is inclusive (`>=`) everywhere.

## New features

* `setup_birdnet()` installs and checks BirdNET. The BirdNET model is now
  downloaded by AudiomothR (with retries and an MD5 check) into the folder
  where the Python package 'birdnet' looks for it on Windows, macOS and
  Linux: its own download gave up after 30 s on slow connections. The
  messages of TensorFlow Lite are no longer shown.
* When `output` is not given, `read_audiomoth()` and `process_audiomoth()`
  ask for the results folder (`choose_output()`), suggesting one outside the
  card and remembering the folder chosen for each card; in non-interactive
  sessions it must be given. Before, the results were saved inside the card.
* The metadata of the WAV files are cached in the results folder
  (`.inventory_cache.rds`): reading a card again only reads the new or
  changed files.
* `create_validation()` creates a self-contained web page to validate the
  records by ear before exporting them: one card per species and day, from
  the least to the most plausible (confidence and probability of occurrence
  at the site), with audio clips, spectrograms and the other species that
  BirdNET proposed. Records can be marked as valid, not valid or unsure, or
  relabelled with autocompletion. `read_validation()` reads the decisions
  (also from the Downloads folder) and `export_observation()` applies them:
  validated records are exported with `is certain = True` even with a single
  detection, and those marked as not valid are left out.
* `analyze_birdnet()` stores the probability of occurrence of each species at
  the site and week (`location_prob`), the UTC offset of each detection and
  the versions of the software (`birdnet/<ID>_<key>/metadata.txt`).
* Triggered recordings (`*T.WAV`, amplitude or frequency threshold) are
  expanded before the analysis, so that times and durations are right.
* `read_audiomoth()` reads cards without `CONFIG.TXT`, GUANO metadata (exact
  battery voltage), comments with a deployment ID, and finds duplicated
  recordings.
* `process_audiomoth()` gains `precision_m`, `example_species = "auto"`,
  `video`, `export`, `validation` and checks its arguments before the
  analysis.
* `detected_species()` returns the vector it prints, ready for
  `extract_examples()`, which also accepts a list of recorders.
* `parse_coordinates()` reads hemisphere letters before the numbers or
  written in words, degrees-minutes-seconds without symbols, typographic
  minus signs, Google Maps links and named numeric vectors, and rejects texts
  that are not coordinates.

## Bug fixes (audit of 2026-10-26)

* Coordinates: the sign was lost with the hemisphere before the number,
  degrees-minutes-seconds separated by spaces gave wrong values, and swapped
  latitude and longitude were accepted without warning (now compared with
  `CONFIG.TXT`). The precision of a numeric vector was about 69 km.
* Taxonomy: the BirdNET → IOC table was rebuilt from the BirdNET v2.4 labels
  and the official IOC comparison with other checklists
  (`data-raw/build_taxonomy.R`): the 250 birds that were lost (Eurasian
  jackdaw, cattle egret, little ringed plover, alpine swift, goshawk...) now
  reach Observation.org. Species split by IOC are translated according to
  the location (`regional_rules.csv`) or reported. Own `equivalences` are
  checked.
* Observation.org: the exported names are now those of the species list of
  Observation.org (downloaded on 2026-10-28), which differs from IOC in some
  lumps and genera: every bird of BirdNET v2.4 has a valid name (e.g.
  *Corvus cornix* → *Corvus corone*, *Saxicola stejnegeri* → *Saxicola
  maurus*, *Tumbezia salvini* → *Ochthoeca salvini*), and the BirdNET name is
  kept in the notes when they differ.
* BirdNET cache: changing a parameter no longer deletes previous results;
  arguments are checked before anything is written; interrupted conversions
  and results are written atomically and detected; errors are recorded in
  the column `analysis` and in `errors.csv`; an empty location filter or an
  analysis where every recording fails are errors instead of "0 detections".
  The cache is separated by recorder. Doubts no longer depend on
  `min_confidence` and classes that are not species ("Engine", "Human
  vocal"...) no longer count as species nor as doubts. Overlapping windows
  are grouped into events. BirdNET weeks follow the eBird convention. The
  Polish labels of BirdNET v2.4, which are wrong, are rejected.
* Examples: successive calls add to the index instead of replacing it, the
  `scroll` video no longer overwrites the `cursor` one, paths are relative,
  a failed example does not stop the others, species names are matched
  without accents and by IOC name, 24 and 32-bit WAV files are read, and the
  `scroll` video is no longer quadratic in time.
* Observation.org: the location of `am` is used (not that of the analysis),
  accuracy above 1000 m is warned about, `from`/`to` accept `DD/MM/YYYY`,
  the external reference is unique and stable, and a CSV edited by hand is
  not overwritten.
* Report: it no longer deletes the examples, keeps the edits of its template,
  flags recorders not analysed, counts only analysed audio, survives missing
  temperature or dates, site names with quotes or `@`, CSV files saved with
  `;`, and shows the real error of Quarto. Quarto receives `.libPaths()`.
* Inventory: faster, with the gain of each recording, the UTC offset of old
  firmware (`Time zone`), warnings about WAV files outside the daily folders,
  a clear error when the card is write-protected, time zones such as
  `"UTC+2"`, and a warning when the time zone does not fit the location
  (Canary Islands).
* The example data and tests no longer contain the ID or location of a real
  recorder.

# AudiomothR 0.2.0

* `crear_informe()`: PDF report (Quarto + Typst) of one or several
  recorders.
* `especies_detectadas()`, number of examples per species and
  `comprobar_requisitos()`.

# AudiomothR 0.1.0

* First version: reading AudioMoth cards, analysis with BirdNET, audio,
  spectrogram and video examples, and export to Observation.org.
