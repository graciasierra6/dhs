# Production version selected

This package supersedes the presentation-focused package for ongoing production
reporting. The old bundle remains intact for the historical presentation record.

On May 24, 2026, the full canonical report was saved with the production label:
`05__fpet_style_production_exogenous_country_k_canonical_ge2_survey_reporting_model_production`.
Its Rmd and HTML are byte-identical to the root canonical GE2 files. The packaged
`production_report.html` is that same frozen HTML; its source has only portable
path changes. It prefers `joint_histflex_low_persist_global_full_ge2_high_ess.rds`.

The original presentation fit had 700 retained draws; the later fit had 2,000,
then was extended to 4,000 via two additional chains. Recorded final diagnostics:
minimum K ESS 1156.3, median K ESS 3258.2, maximum K Rhat 1.00243, zero divergences.
Adding the last two chains changed country K means by median absolute 0.092 pp
and maximum 0.516 pp. This comparison is between the two later high-ESS stages,
not between the old presentation posterior and the high-ESS posterior.

The Nigeria 27.4% headline identifies the earlier presentation run. A direct
audit of the saved high-ESS posterior gives Nigeria K = 27.98189%, or 28.0%
rounded to one decimal, using the production country/region ordering. It is not a
constraint on the later fit. Changing the saved fit can change K and target-year
estimates. Do not mix the old presentation summaries with the new full report.

The helper's country inclusion is pinned to >=2, obsolete machine-specific
compiler settings are removed, and personal DHS setup fields use placeholders.
The standalone refit explicitly preserves the factor-level ordering used by the
high-ESS fit. It combines independent two-chain fits with the original seeds.
