# Goal 1 dashboard

This project rebuilds the DRC, Ethiopia, and Nigeria dashboard as a single,
portable HTML file:

`output/goal1_reverse_engineer_test.html`

The output is self-contained and works when opened directly in a current
browser. It has no external data requests, local-machine paths, or runtime
sidecar files. The current clean build is approximately 2.5 MB.

## Rebuild on another computer

### Requirements

- R 4.1.3 for the closest match to `renv.lock`;
- internet access once to restore the recorded R packages; and
- RStudio or a terminal with `Rscript`.

### RStudio

1. Clone or download the complete `goal1_reverse_engineer/` folder.
2. Open `goal1_reverse_engineer.Rproj`.
3. Run:

```r
install.packages("renv", repos = "https://cloud.r-project.org") # only if needed
renv::restore(prompt = FALSE)
source("render.R")
source("validate.R")
```

4. Confirm that validation ends with `Validation passed`.
5. Open `output/goal1_reverse_engineer_test.html`.

### Terminal

From the project root:

```sh
Rscript -e "install.packages('renv', repos='https://cloud.r-project.org')"
Rscript -e "renv::restore(prompt=FALSE)"
Rscript render.R
Rscript validate.R
Rscript scripts/audit_risk_alignment.R
```

All build paths are relative to the project root. The project does not use
`setwd()`.

## Why the HTML stays below 10 MB

The map geometry, validated numerical payloads, CSS, and interaction code are
embedded in the final HTML. Popup charts are generated as SVG in the browser
from those embedded numbers when an area is selected.

The build does not embed 148 raster PNG files. The supplied prevalence PNGs
alone contain 23.5 MiB of image data (31.3 MiB after base64 encoding); the full
prevalence-plus-change collection would add about 48.8 MiB after base64
encoding. Embedding those files is therefore incompatible with a 10 MB HTML.
Generating the plots as SVG retains offline clicks, profile charts, keyboard
activation, and CSV downloads without missing image bundles.

A clean build enforces a strict output limit of 10,000,000 bytes. The current
output is approximately 2.5 MB, leaving substantial room for hosting overhead
and future changes.

## Popup behavior

Every mapped province, region, or state is clickable and keyboard accessible.

- Prevalence, indicator-prevalence, and current-rank bivariate views open a
  source-generated distribution profile. It follows the supplied profile
  layout, separates row labels from range labels, draws both ends of every 95%
  confidence interval even when they extend beyond the observed range, and
  includes all available indicators plus U5MR, NMR, and IMR.
- Change, worsening-count, and change-mode bivariate views open a source-generated
  risk-aligned endpoint chart with 95% confidence intervals.
- Facility delivery, fever care seeking, and ANC4+ are inverted in the change
  chart so higher plotted values consistently indicate worse outcomes.
- The download button creates the selected area's CSV directly in the browser.

No server or network connection is required after the HTML is built.

## Data and analytical rules

Routine builds use:

- `data/count_map_input_combined_master.csv`
- `data/composite_indicator_rankings.csv`
- `data/subnational_indicator_rankings.csv`
- `data/mortalityunder5.csv`
- `data/profile_indicator_estimates.csv`
- `data/source/region_profile_numbers.csv`
- `data/source/region_profile_mortality.csv`
- the three GeoJSON files under `assets/geo/`

Rows where `composite_set == "severe"` are excluded. Composite rank 1 is best.

Indicator change is risk aligned before ranking or counting. Positive
`pp_change_10yr_recoded` means worsening. For each indicator in each country,
threshold `T` is the type-7 25th percentile of the absolute risk-aligned
changes:

- below `-T`: improving;
- above `T`: worsening;
- otherwise: non-significant change.

The build regenerates
`data/worsening_count_threshold_distributions.csv` with one audit row for each
of the 581 area-indicator combinations.

## Coverage

| Country | Areas | Indicators |
|---|---:|---:|
| DRC | 26 provinces | 8 |
| Ethiopia | 11 regions | 7 |
| Nigeria | 37 states/FCT | 8 |

Ethiopia has seven indicators because the retained inputs do not contain an
Ethiopia malaria-RDT series.

## Validation

`validate.R` stops on a mismatch. It checks:

- 74 administrative areas and 581 indicator records;
- all source values, endpoint years, confidence intervals, risk directions,
  ranks, thresholds, classifications, and worsening counts;
- all 23 country-indicator prevalence maps, including country-specific
  area/value coverage, alphabetical controls, and non-degenerate risk-aligned
  color distributions;
- 222 IMR/NMR/U5MR rows and one-to-one mortality joins;
- all 77 country-specific bivariate indicator pairs;
- state/region/province names against pinned boundary metadata;
- 995 boundary, feature-order, location, hash, and rendered-join checks;
- complete profile payload coverage for all 74 areas;
- exact agreement between the 581 plotted latest confidence intervals and the
  supplied profile-number source, plus validation of all 74 supplied
  prevalence-profile manifest records;
- clickable and keyboard profile wiring;
- no external scripts, image data URIs, network requests, absolute paths, or
  machine identifiers; and
- a self-contained final HTML smaller than 10,000,000 bytes.

For an optional live comparison with the current public boundary downloads:

```sh
Rscript scripts/validate_maps.R --online
```

## Project structure

```text
goal1_reverse_engineer/
|-- goal1_reverse_engineer.Rproj
|-- render.R
|-- validate.R
|-- renv.lock
|-- README.md
|-- DATA_INVENTORY.md
|-- R/
|-- assets/
|   |-- css/reference_dashboard.css
|   |-- js/reference_dashboard.template.js
|   |-- templates/reference_dashboard.template.html
|   `-- geo/
|-- artifacts/
|-- data/
|-- reference/README.md
|-- scripts/
|-- renv/
`-- output/goal1_reverse_engineer_test.html
```

The original benchmark HTML and supplied prevalence-profile PNG archive are
visual provenance only. They are intentionally kept outside the uploadable
project because each exceeds the repository's 10 MB file limit. Rendering and
normal validation use the committed templates, source data, and small manifests;
they do not require either large reference file.

Local `renv/library/`, `.Rproj.user/`, `.Rhistory`, `.RData`, and
`.DS_Store` files should not be uploaded.

## Deployment

For static hosting, deploy
`output/goal1_reverse_engineer_test.html`. If the host requires a landing file,
copy or rename that generated file to `index.html` during deployment. No
`assets/` folder is required beside the deployed HTML.

For reproducibility, commit source changes and the regenerated HTML together:

1. update the relevant input or source file;
2. run `Rscript render.R`;
3. run `Rscript validate.R`;
4. review representative prevalence and change profiles in all three countries;
5. commit the code, input changes, audit CSV, and final HTML.
