# Goal 1 dashboard reverse-engineering test

This project rebuilds the supplied final dashboard as
`output/goal1_reverse_engineer_test.html` while checking every embedded data
payload against the retained production inputs.

The output preserves the reference layout, colors, navigation, maps, hover
labels, country switching, indicator and bivariate controls, state/profile
drawer, both profile-chart designs, and CSV download behavior. It is a portable
HTML file with no external data requests or machine-specific paths.

## Rebuild on another computer

### Requirements

- R 4.1.3 for the closest match to `renv.lock`;
- internet access once to restore the recorded R packages; and
- RStudio or a terminal with `Rscript` available.

### RStudio workflow

1. Clone or download the complete `goal1_reverse_engineer_test/` folder.
2. Open `goal1_reverse_engineer_test.Rproj`.
3. In the R console, run:

```r
install.packages("renv", repos = "https://cloud.r-project.org") # only if needed
renv::restore(prompt = FALSE)
source("render.R")
source("validate.R")
```

4. Confirm that validation ends with `Validation passed`.
5. Open `output/goal1_reverse_engineer_test.html` in a current browser.

### Terminal workflow

From the project root:

```sh
Rscript -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript -e "renv::restore(prompt=FALSE)"
Rscript render.R
Rscript validate.R
Rscript scripts/audit_risk_alignment.R
```

All build paths are relative to the project root. The project does not use
`setwd()` or store paths from the computer on which it was created.

## How the reconstruction works

The supplied final HTML is retained under
`reference/reference_dashboard.html` as the visual and functional benchmark.
The one-time extraction script separates it into:

- `assets/templates/reference_dashboard.template.html`: exact page and map markup;
- `assets/css/reference_dashboard.css`: exact reference styling;
- `assets/js/reference_dashboard.template.js`: exact interaction logic with data placeholders;
- `artifacts/profile_images_prevalence.json`: 74 embedded prevalence-profile PNGs;
- `artifacts/profile_images_change.json`: 74 embedded change-profile PNGs; and
- `artifacts/reference_payloads/`: reference data used only for parity checks.

During every normal build, R recomputes the 581 indicator records and 581
country-and-indicator-specific change classifications from the CSV inputs. It
inserts those values into the reference interaction code, embeds all 148 profile
plots, writes `data/worsening_count_threshold_distributions.csv`, and assembles
the final standalone HTML.

The threshold-distribution CSV contains one row for every area-indicator record,
ordered from most improving to most worsening within each country and indicator.
It records the risk-aligned change, absolute change used for the distribution,
type-7 25th-percentile threshold, improving and worsening cutoffs, final
classification, and the contribution to each count category.

The reference contained a second identical copy of all 37 Nigeria boundary
paths. It also attached six Ethiopia indicator-map labels and all 37 Nigeria
current-prevalence labels to the wrong shape IDs. The extraction step removes
the redundant paths and reconnects those 43 labels to their pinned public
geometry. Styling and data values remain unchanged; every generated HTML ID is
unique and every area now colors its own location. The supplied HTML also
referenced an unavailable relative `favicon.png`; that nonfunctional link is
removed so the output has no missing runtime asset.

The regular rebuild does not require Python. `scripts/extract_reference_assets.py`
is retained only to document how the supplied reference was decomposed. Run it
again only if `reference/reference_dashboard.html` is deliberately replaced.

## Dashboard coverage reproduced

| Country | Areas | Indicators | Reproduced sections |
|---|---:|---:|---|
| DRC | 26 provinces | 8 | Current prevalence, 10-year change, indicator prevalence, worsening count, bivariate map |
| Ethiopia | 11 regions | 7 | Current prevalence, indicator change, indicator prevalence, bivariate map |
| Nigeria | 37 states/FCT | 8 | Current prevalence, indicator change, indicator prevalence, bivariate map |

Ethiopia has seven indicators because the source inputs do not contain an
Ethiopia malaria-RDT series.

Nigeria's bivariate section supports all eight indicators. Every one of the 28
distinct indicator pairs has complete data for all 37 states/FCT and works in
both risk-aligned change and current-prevalence-rank modes.

Clicking a mapped area opens the profile image appropriate to the source map:
prevalence maps use the prevalence-profile bank; change, count, and change-mode
bivariate maps use the change-profile bank. The `Download CSV file` control is
populated from the source-generated indicator and classification payloads.

## Validation

`validate.R` stops the build when any check fails. It verifies:

- 26 DRC, 11 Ethiopia, and 37 Nigeria areas;
- 208 DRC, 77 Ethiopia, and 296 Nigeria indicator records;
- a 581-row country/indicator threshold-distribution CSV;
- exact baseline/latest values, raw changes, direction labels, risk-aligned changes, and risk-ordered ranks for all 581 area-indicator records;
- type-7 25th-percentile threshold `T` separately for every country and indicator;
- exact reference classifications and composite prevalence/change map values;
- exact DRC worsening counts and indicator membership;
- exact DRC worsening-count color categories derived from those risk-aligned counts;
- one-to-one state/region/province joins to pinned public boundary files;
- one-to-one U5MR matches for all 74 areas;
- 74 unique boundary paths, 322 rendered map regions, and no missing or duplicate IDs;
- exactly two valid profile PNGs for every area, for 148 images total;
- all reference sections and CSV-download wiring;
- all 77 country-specific indicator pairs (28 DRC, 21 Ethiopia, and 28 Nigeria) with complete area coverage in both bivariate modes;
- no external data requests, absolute paths, or machine identifiers.

The offline map audit performs 995 pinned boundary name, code, feature-order,
location, hash, and rendered-join checks. To additionally compare against the
current public geoBoundaries downloads, run:

```sh
Rscript scripts/validate_maps.R --online
```

## Project structure

```text
goal1_reverse_engineer_test/
|-- goal1_reverse_engineer_test.Rproj
|-- render.R
|-- validate.R
|-- renv.lock
|-- README.md
|-- DATA_INVENTORY.md
|-- R/
|   |-- data_prep.R
|   |-- html_helpers.R
|   |-- map_validation.R
|   |-- reference_build.R
|   |-- reference_validation.R
|   |-- risk_alignment_validation.R
|   `-- threshold_distribution.R
|-- assets/
|   |-- css/reference_dashboard.css
|   |-- js/reference_dashboard.template.js
|   |-- templates/reference_dashboard.template.html
|   `-- geo/
|       |-- drc-adm1.geojson
|       |-- ethiopia-adm1.geojson
|       `-- nigeria-adm1.geojson
|-- artifacts/
|   |-- profile_images_prevalence.json
|   |-- profile_images_change.json
|   |-- profile_images_manifest.csv
|   |-- reference_manifest.json
|   `-- reference_payloads/
|-- data/
|   |-- count_map_input_combined_master.csv
|   |-- composite_indicator_rankings.csv
|   |-- subnational_indicator_rankings.csv
|   |-- mortalityunder5.csv
|   |-- profile_indicator_estimates.csv
|   |-- worsening_count_threshold_distributions.csv
|   |-- reference/
|   `-- source/
|-- reference/reference_dashboard.html
|-- scripts/
|   |-- audit_risk_alignment.R
|   |-- extract_reference_assets.py
|   |-- prepare_profile_input.py
|   |-- validate_maps.R
|   `-- test_map_validation.R
|-- renv/
`-- output/goal1_reverse_engineer_test.html
```

`renv/library/`, `.Rproj.user/`, `.Rhistory`, and `.RData` are local generated
files and must not be uploaded. The remaining folder structure should be kept
intact in Git.

## Updating the dashboard

1. Update the relevant files under `data/`, `assets/geo/`, or the source code.
2. Run `Rscript render.R`.
3. Run `Rscript validate.R`.
4. Run `Rscript scripts/audit_risk_alignment.R` for the detailed country-by-indicator audit table.
5. Review all three countries and click both prevalence- and change-type maps.
6. Commit the source changes and regenerated output together.

The generated HTML is enough for deployment. The complete project folder is
required for review, maintenance, validation, and future rebuilding.
