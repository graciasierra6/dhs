# Ethiopia contraceptive discontinuation code

The project-level `../ethiopia_discontinuation_analysis.Rmd` is the explanatory
and executable R Markdown entry point. It documents the input variables,
calendar-to-episode conversion, DHS window rules, estimators, validation, and
the final HTML build while sourcing the modular scripts in this folder.

## Purpose

This folder contains the portable entry point for reproducing Ethiopia
2024-25 contraceptive discontinuation estimates at 3, 6, 9, and 12 months.
The estimates include:

- observed method initiation mix and method-start rates per calendar
  woman-month;
- annual calendar-based prevalence of any contraceptive use and modern-method
  use, using observed woman-months as the denominator;
- monthly all-cause and cause-specific life-table hazards;
- all-cause discontinuation by DHS aggregate method category;
- reason-specific cumulative incidence by method and duration;
- switching to another method as a separate outcome;
- a 12-month comparison against published DHS Table 7.11; and
- time to contraceptive reinitiation after non-pregnancy-related
  discontinuation, treating subsequent pregnancy as a competing event; and
- episode, method, reason, and boundary-condition diagnostics.

## Required input

Place the Ethiopia Individual Recode Stata file here:

`../input/ETIR8AFL.dta`

The analysis reads the five-year contraceptive calendars in `vcal_1` and
`vcal_2`, together with the interview and calendar timing variables and the DHS
woman weight `v005`. It also reads `v312` and `v313` to validate calendar use
against the survey's interview-date current-use measure.

## How to run

From RStudio, open the project folder and run:

```r
source("code/run_discontinuation_analysis.R")
```

Or run from a terminal:

```text
Rscript code/run_discontinuation_analysis.R
```

The runner determines the project location automatically. It does not require
`setwd()` and can be run after the project folder is moved to another computer.

## Statistical approach

### Episode construction

Contraceptive-use episodes are reconstructed from contiguous runs of method
codes in `vcal_1`. The discontinuation reason recorded at the episode endpoint
is read from `vcal_2`. DHS sampling weights are `v005 / 1,000,000`.

The standard DHS discontinuation-window rules are then applied: episodes that
start at the beginning of the calendar are excluded, the final three months are
censored, episodes ending outside the analysis window are excluded, and older
episodes enter through delayed entry at the 62-month boundary.

### All-cause discontinuation

All discontinuation reasons are treated as one endpoint. The reported value at
each duration is the weighted life-table cumulative probability `1 - S(t)`.

### Discontinuation by reason

Reason-specific estimates use a weighted Aalen-Johansen competing-risk life
table. The nine discontinuation reasons are mutually exclusive competing
events. A value at 12 months is therefore the cumulative probability that an
episode has ended for that particular reason by month 12, accounting for the
possibility of ending earlier for another reason.

The reason-specific estimates sum to the all-cause discontinuation estimate,
subject only to floating-point precision.

### Switching

Switching is calculated separately because it is not a mutually exclusive
reason for discontinuation. A woman may report a reason and also switch to
another method. Consequently, switching must not be added to the reason columns
or to the `Any reason` result.

## DHS aggregate method categories

- Injectables
- Implants
- Pill
- Emergency contraception
- Other
- All methods

`Other` combines methods not displayed as separate rows in the report. The
analysis also exports finer method diagnostics so that sparse methods can be
identified rather than interpreted as precise standalone estimates.

## Principal outputs

All outputs are written to `../derived/`.

- `competing_risk_reasons_3_6_9_12_months.csv`: DHS-style method-by-reason
  estimates for all four horizons.
- `competing_risk_reasons_12_month_validation.csv`: calculated versus published
  Table 7.11 values for every method and reason.
- `reason_predominance_by_method_and_horizon.csv`: the three largest competing
  reasons for every method at each duration.
- `all_cause_life_table_published_groups.csv`: 3-, 6-, 9-, and 12-month
  all-cause estimates for the DHS method groups.
- `single_vs_competing_risk_equivalence.csv`: confirms that the sum of the
  reason-specific cumulative incidences equals all-cause discontinuation.
- `validation_summary.csv`: core input and episode checks.
- `observed_method_initiation_mix.csv`: weighted observed method starts, their
  composition, and whether they follow non-use, a switch, or pregnancy.
- `observed_method_initiation_rates.csv`: observed method starts per 1,000
  weighted observed calendar woman-months.
- `annual_observed_method_initiation_mix.csv`: calendar-year composition of
  observed method starts.
- `annual_method_initiation_percent.csv`: the same annual initiation mix with
  discontinuation method categories as rows and calendar years as columns;
  each year sums to 100% before rounding.
- `annual_calendar_contraceptive_use.csv`: weighted annual average monthly
  prevalence of any contraceptive use, modern-method use, and traditional use,
  with woman-month support and boundary-year coverage fields.
- `annual_calendar_validation.csv`: annual arithmetic checks confirming that
  any-method use equals modern plus traditional use and each year's initiation
  shares sum to 100%.
- `calendar_vs_v312_current_use.csv`: survey-weighted, like-for-like comparison
  of v312 current use and the vcal_1 state in the same interview month, by
  interview year and overall.
- `leaky_bucket_discontinuation_comparison.csv`: cumulative discontinuation in
  the primary DHS-style population beside a cohort restricted to observed
  method starts.
- `reinitiation_switching_pathways.csv`: cumulative post-discontinuation
  pathways separating different-method switching, same-method restarting,
  pregnancy before reinitiation, and no observed event for both populations.
- `leaky_bucket_validation.csv`: cohort-membership and probability-identity
  checks for the observed-start extension.
- `monthly_all_cause_discontinuation_hazards.csv`: weighted monthly stopping
  hazards by method for months 1-12.
- `monthly_cause_specific_discontinuation_hazards.csv`: weighted monthly hazards
  for each method and discontinuation reason.
- `reason_timing_share_of_12_month_cif.csv`: percentage of each reason's
  12-month cumulative incidence accumulated by months 3, 6, and 9.
- `reinitiation_competing_risk_1_3_6_9_12.csv`: cumulative incidence of
  reinitiation and subsequent pregnancy at each horizon.
- `reinitiation_monthly_competing_risk_1_12.csv`: month-by-month cumulative
  incidence of reinitiation, pregnancy before reinitiation, and neither event
  during the first 12 months after an eligible discontinuation.
- `reinitiation_sample_summary.csv`: eligible episodes and observed outcomes by
  discontinued method.
- `reason_post_discontinuation_outcomes.csv`: reinitiation, pregnancy before
  reinitiation, and no-event cumulative probabilities at 1, 3, 6, and 12
  months for every DHS discontinuation-reason group.
- `reason_previous_method_post_discontinuation_outcomes.csv`: the same outcome
  partition within each previous-method and reason subgroup, including the
  eligible weighted and unweighted episode counts used for reliability flags.
- `post_discontinuation_transition_matrix.csv`: cumulative competing-risk
  probabilities of the next-method destination at 1, 3, 6, 9, and 12 months.
- `post_discontinuation_destination_among_reinitiators.csv`: distribution of
  next-method destinations conditional on estimated reinitiation by each
  milestone; destination columns total 100% within each row.
- `post_discontinuation_gap_distribution.csv`: mutually exclusive timing of
  reinitiation, pregnancy before reinitiation, or no observed event by month 12.
- `post_discontinuation_modern_protection_pathways.csv`: mutually exclusive
  12-month pathways after an eligible modern-method discontinuation, separating
  immediate modern continuation, temporary and prolonged gaps followed by a
  modern method, traditional-method use, pregnancy first, and no observed
  reinitiation or pregnancy.
- `post_discontinuation_effectiveness_transition.csv`: cumulative transition to
  a higher, equal, or lower contraceptive-effectiveness tier, including same-
  method restarts, pregnancy, and no observed event.

The same run also creates the self-contained browser report:

`../output/ethiopia_discontinuation_3_6_9_12.html`

The report begins with observed method initiation mix and initiation rates,
then presents all-cause discontinuation, the leading reasons by method and
duration, four DHS Table 7.11-format reason tables, method-specific
cumulative-incidence matrices, and distributions of reasons among episodes
discontinued by each horizon. Section 5 presents those distributions in two
equivalent layouts: one table per method and one table per time point.

The HTML build also exports two audit-ready tables:

- `../derived/cumulative_incidence_by_method_3_6_9_12.csv`
- `../derived/reason_distribution_among_discontinued_3_6_9_12.csv`

## Interpretation

The 3-, 6-, 9-, and 12-month estimates are cumulative since method initiation.
They are not probabilities confined to months 3, 6, 9, or 12, and they are not
the percentage distribution among discontinuers. Comparisons across horizons
show how the cumulative importance of each reason develops as duration of use
increases.
