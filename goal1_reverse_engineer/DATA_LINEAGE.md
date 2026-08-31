# Data lineage and transformation documentation

## Purpose

This document traces the dashboard data from the supplied upstream files to the
normalized build inputs, derived classifications, interactive profiles, maps,
and final HTML. All paths are relative to the project root.

The word **source** below means the earliest retained file in this project. The
indicator sources contain aggregated DHS estimates by first-level
administrative area (ADM1), not respondent-level DHS recode or household
microdata. Reproducing the ADM1 estimates themselves would require the original
DHS microdata and the upstream survey-analysis code, which are not included.

## Indicator source files

| Retained upstream source | Contents | Source level |
|---|---|---|
| `data/source/nutrition_zd_malaria_under20agefirstBTH_estimates_DHS.csv` | Nutrition, malaria, vaccination-access, and reproductive-timing estimates | Aggregated DHS ADM1 estimates |
| `data/source/Health_systems_combinedindicators_allcountries_REVISED.xlsx`, sheet `in` | Health-system coverage estimates | Aggregated DHS ADM1 estimates |

Both files contain country, survey year, survey source, indicator, ADM1 name,
estimate, standard error, lower and upper 95% confidence limits, unweighted
sample size, survey order, and survey label. All retained survey-source values
for DRC, Ethiopia, and Nigeria are `DHS`.

### Indicator-to-source mapping

| Dashboard indicator | Internal ID | Direction | Upstream source |
|---|---|---|---|
| Wasting | `wasting` | Adverse | Nutrition CSV |
| Anemia among women | `anemia_women` | Adverse | Nutrition CSV |
| Malaria RDT positive | `malaria_rdt_positive` | Adverse | Nutrition CSV |
| Zero-dose | `zero_dose` | Adverse | Nutrition CSV |
| First birth before age 20 | `first_birth_under20` | Adverse | Nutrition CSV |
| Facility delivery | `facility_delivery` | Beneficial | Health-systems Excel, sheet `in` |
| Fever care seeking | `fever_care_seeking` | Beneficial | Health-systems Excel, sheet `in` |
| ANC4+ | `anc4plus` | Beneficial | Health-systems Excel, sheet `in` |

Ethiopia does not have a retained malaria-RDT series. Consequently, DRC and
Nigeria each have eight dashboard indicators while Ethiopia has seven.

## Indicator transformation chain

### 1. Upstream estimates to the combined endpoint master

`data/count_map_input_combined_master.csv` combines the rows from the nutrition
CSV and the `in` sheet of the health-systems workbook. For the eight standard
indicator IDs and the three dashboard countries, the combined file contains
1,520 endpoint rows.

The direct-source validator checks a one-to-one match using:

- `country`;
- `survey_year`;
- `indicator`; and
- `admin_name`.

It then checks exact agreement, within `1e-7`, for estimate, standard error,
confidence limits, and unweighted sample size, and exact agreement for survey
source and survey label. No estimate, confidence interval, or sample size is
recalculated during this combination.

### 2. Combined endpoints to subnational rankings

`data/subnational_indicator_rankings.csv` contains one row per country,
indicator, and mapped ADM1 area: 208 DRC rows, 77 Ethiopia rows, and 296 Nigeria
rows, for 581 rows total.

For each row:

```text
raw percentage-point change = latest estimate - baseline estimate
```

For adverse indicators, risk-aligned change equals raw change. For beneficial
coverage indicators, the sign is reversed:

```text
risk-aligned change = -(latest estimate - baseline estimate)
```

The recoded endpoint representation is:

```text
adverse indicator:    recoded estimate = estimate
beneficial indicator: recoded estimate = 100 - estimate
```

Positive risk-aligned change therefore always means worsening; negative always
means improving.

Ranks are calculated independently within each country and indicator:

- `change_rank = rank(risk-aligned change, ties.method = "min")`;
- for adverse indicators, `prevalence_rank = rank(latest estimate)`; and
- for beneficial indicators, `prevalence_rank = rank(-latest estimate)`.

Rank 1 is the best/lowest-risk result.

### Endpoint windows retained in the rankings

| Country | Indicator group | Baseline | Latest | Areas per indicator |
|---|---|---:|---:|---:|
| DRC | All eight indicators | 2013 | 2024 | 26 |
| Ethiopia | Anemia among women | 2005 | 2016 | 11 |
| Ethiopia | Other six retained indicators | 2016 | 2024 | 11 |
| Nigeria | Anemia among women | 2018 | 2024 | 37 |
| Nigeria | Malaria RDT positive | 2010 | 2021 | 37 |
| Nigeria | Other six indicators | 2013 | 2024 | 37 |

The direct audit compares every baseline year, baseline estimate, latest year,
latest estimate, raw change, recoded endpoints, and risk-aligned change in the
581-row ranking file against the two upstream source files.

### 3. Rankings to improving/non-significant/worsening classifications

For every country-indicator distribution separately:

```text
T = type-7 25th percentile of absolute risk-aligned ADM1 changes
```

- change below `-T`: improving;
- change above `T`: worsening; and
- change from `-T` through `T`: non-significant change.

`R/threshold_distribution.R` writes all classifications to
`data/worsening_count_threshold_distributions.csv`. This file has 581 rows and
records the country-specific threshold, both cutoffs, risk-aligned change, final
classification, and binary count contributions.

`R/worsening_count_validation.R` independently recalculates every threshold and
classification from each country-indicator's own risk-aligned distribution. It
then sums the binary contributions for every ADM1 area and checks the rendered
map tooltip, exact indicator-membership lists, legend bucket, and fill. The
standalone command is:

```sh
Rscript scripts/validate_worsening_count_maps.R
```

Add `--details` to print all 74 area-level results.

### 4. Classifications to worsening-count maps

For each ADM1 area, the build sums the binary worsening contribution across the
country's available indicators. The resulting count is grouped into `0–1`,
`2–3`, `4`, or `5–6` and colored with selected values from the nine-color
RColorBrewer `YlGn` palette. The worst group appears first in the legend.

The build stops if a future result falls outside the configured `0–6` legend
range; it does not silently truncate or recode the count.

### 5. Indicator values to prevalence, change, and bivariate maps

- Indicator-prevalence maps use `observed_latest_estimate` from the ranking file.
- Indicator-change maps use risk-aligned percentage-point change.
- Change-mode bivariate maps combine two indicators' independently calculated
  improving/non-significant/worsening classifications.
- Prevalence-mode bivariate maps classify each latest-value distribution within
  its own country and indicator before combining the two axes.

No DRC thresholds or distributions are reused for Ethiopia or Nigeria.

## Profiles and confidence intervals

`scripts/prepare_profile_input.py` combines the same two upstream indicator
sources into `data/profile_indicator_estimates.csv`, retaining endpoint
estimates, survey labels, and 95% confidence intervals. The normal R build uses
the committed normalized CSV and does not require Python or Excel support.

`data/source/region_profile_numbers.csv` supplies a separate 581-row profile
reference used to verify displayed latest estimates, confidence intervals,
ranks, and country-specific distributions. Profile graphics and CSV downloads
are generated in the browser from the validated numeric payload; raster profile
images are not embedded.

## Composite ranks

`data/source/composite_indicator_rankings_full.csv` is the retained upstream
composite-ranking artifact. The build-ready
`data/composite_indicator_rankings.csv` supplies standard composite prevalence
and change scores and ranks. Rows where `composite_set == "severe"` are excluded
from dashboard composite maps. Composite rank 1 is best.

## Mortality

- `data/mortalityunder5.csv` supplies the filtered U5MR audit input.
- `data/source/region_profile_mortality.csv` supplies IMR, NMR, and U5MR values
  for all 74 profile areas.

The build requires exactly one U5MR record per mapped area after documented name
normalization. It filters `indicator == "U5MR"` and `window_mid == 2022`, with
survey year 2023 for DRC, 2025 for Ethiopia, and 2024 for Nigeria.

## ADM1 names and geometry

`R/data_prep.R` applies explicit spelling reconciliation before joining data to
maps. Examples include `Tanganika` to `Tanganyika`, `Affar` to `Afar`, `Oromiya`
to `Oromia`, and `FCT` to `FCT Abuja`.

The three files under `assets/geo/` contain the mapped geometries. Files under
`data/reference/` pin the expected geoBoundaries identifiers, names, feature
order, hashes, bounding boxes, and geographic centers. Validation rejects
unmatched, duplicated, relocated, or mislabeled areas.

`scripts/validate_maps.R --details` prints the complete 74-area reconciliation,
including dashboard name, public boundary name, subdivision code, public shape
ID, center coordinates, and the number of rendered map occurrences. Add
`--online` to re-download and hash-check the current public geoBoundaries layers.

## Dashboard build outputs

`render.R` calls the preparation and rendering code under `R/`, regenerates the
worsening-threshold audit CSV, embeds the validated data and geometry, and writes
`output/goal1_reverse_engineer_test.html`.

The output is self-contained: it makes no external data requests and contains
no absolute local paths.

## Reproducing the validation

Routine R rebuild and validation:

```sh
Rscript render.R
Rscript validate.R
Rscript scripts/audit_risk_alignment.R
```

Direct validation against the original nutrition CSV and health-systems Excel
workbook requires Python with `pandas` and `openpyxl`:

```sh
python scripts/validate_indicator_source_lineage.py
```

The direct validation stops on missing or duplicate endpoint keys, a source-file
mapping error, a mismatched endpoint, an incorrect raw or recoded change, or a
country coverage error. A successful run reports 1,520 upstream endpoint rows,
581 ranking rows, and the maximum numerical reconciliation error.

## Validation ownership by file

| Stage | Code |
|---|---|
| Direct original-source reconciliation | `scripts/validate_indicator_source_lineage.py` |
| Endpoint, direction, recoding, rank, and CI checks | `R/data_prep.R`, `R/risk_alignment_validation.R` |
| Threshold distribution audit | `R/threshold_distribution.R` |
| End-to-end worsening-count map audit | `R/worsening_count_validation.R`, `scripts/validate_worsening_count_maps.R` |
| Mortality and profile-source checks | `R/profile_assets.R`, `R/data_prep.R` |
| Boundary names, order, location, and hashes | `R/map_validation.R`, `scripts/validate_maps.R` |
| Complete rendered HTML validation | `validate.R` |
