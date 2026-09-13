# Build a self-contained HTML report for Ethiopia contraceptive discontinuation.
#
# Inputs are the CSV files created by run_discontinuation_analysis.R. No data or
# JavaScript libraries are loaded from the internet; the resulting HTML can be
# opened directly from disk or uploaded as a single file.

project_dir <- getOption("ethiopia_discontinuation_project_dir")
if (is.null(project_dir)) {
  stop(
    "Run code/run_discontinuation_analysis.R rather than sourcing this file alone.",
    call. = FALSE
  )
}

derived_dir <- file.path(project_dir, "Analyses", "derived")
output_dir <- file.path(project_dir, "output")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

all_cause_file <- file.path(
  derived_dir, "all_cause_life_table_published_groups.csv"
)
reason_file <- file.path(
  derived_dir, "competing_risk_reasons_3_6_9_12_months.csv"
)
predominance_file <- file.path(
  derived_dir, "reason_predominance_by_method_and_horizon.csv"
)
reinitiation_file <- file.path(
  derived_dir, "reinitiation_competing_risk_1_3_6_9_12.csv"
)
reinitiation_monthly_file <- file.path(
  derived_dir, "reinitiation_monthly_competing_risk_1_12.csv"
)
reinitiation_summary_file <- file.path(
  derived_dir, "reinitiation_sample_summary.csv"
)
initiation_mix_file <- file.path(
  derived_dir, "observed_method_initiation_mix.csv"
)
initiation_rate_file <- file.path(
  derived_dir, "observed_method_initiation_rates.csv"
)
annual_initiation_file <- file.path(
  derived_dir, "annual_observed_method_initiation_mix.csv"
)
annual_initiation_wide_file <- file.path(
  derived_dir, "annual_method_initiation_percent.csv"
)
annual_use_file <- file.path(
  derived_dir, "annual_calendar_contraceptive_use.csv"
)
current_use_comparison_file <- file.path(
  derived_dir, "calendar_vs_v312_current_use.csv"
)
monthly_all_hazard_file <- file.path(
  derived_dir, "monthly_all_cause_discontinuation_hazards.csv"
)
monthly_cause_hazard_file <- file.path(
  derived_dir, "monthly_cause_specific_discontinuation_hazards.csv"
)
reason_timing_file <- file.path(
  derived_dir, "reason_timing_share_of_12_month_cif.csv"
)
transition_matrix_file <- file.path(
  derived_dir, "post_discontinuation_transition_matrix.csv"
)
destination_conditional_file <- file.path(
  derived_dir, "post_discontinuation_destination_among_reinitiators.csv"
)
gap_distribution_file <- file.path(
  derived_dir, "post_discontinuation_gap_distribution.csv"
)
modern_protection_pathways_file <- file.path(
  derived_dir, "post_discontinuation_modern_protection_pathways.csv"
)
effectiveness_transition_file <- file.path(
  derived_dir, "post_discontinuation_effectiveness_transition.csv"
)
reason_outcomes_file <- file.path(
  derived_dir, "reason_post_discontinuation_outcomes.csv"
)
reason_method_outcomes_file <- file.path(
  derived_dir, "reason_previous_method_post_discontinuation_outcomes.csv"
)
leaky_bucket_file <- file.path(
  derived_dir, "leaky_bucket_discontinuation_comparison.csv"
)
switching_pathways_file <- file.path(
  derived_dir, "reinitiation_switching_pathways.csv"
)

required_files <- c(
  all_cause_file, reason_file, predominance_file,
  reinitiation_file, reinitiation_monthly_file, reinitiation_summary_file,
  initiation_mix_file, initiation_rate_file, annual_initiation_file,
  annual_initiation_wide_file, annual_use_file, current_use_comparison_file,
  monthly_all_hazard_file, monthly_cause_hazard_file, reason_timing_file,
  transition_matrix_file, destination_conditional_file, gap_distribution_file,
  modern_protection_pathways_file,
  effectiveness_transition_file, reason_outcomes_file,
  reason_method_outcomes_file, leaky_bucket_file, switching_pathways_file
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop(
    "Missing required analysis outputs:\n- ",
    paste(missing_files, collapse = "\n- "),
    call. = FALSE
  )
}

all_cause <- read.csv(all_cause_file, check.names = FALSE)
reasons <- read.csv(reason_file, check.names = FALSE)
predominance <- read.csv(predominance_file, check.names = FALSE)
reinitiation <- read.csv(reinitiation_file, check.names = FALSE)
reinitiation_monthly <- read.csv(
  reinitiation_monthly_file, check.names = FALSE
)
reinitiation_summary <- read.csv(
  reinitiation_summary_file, check.names = FALSE
)
initiation_mix <- read.csv(initiation_mix_file, check.names = FALSE)
initiation_rates <- read.csv(initiation_rate_file, check.names = FALSE)
annual_initiation <- read.csv(annual_initiation_file, check.names = FALSE)
annual_initiation_wide <- read.csv(
  annual_initiation_wide_file, check.names = FALSE
)
annual_use <- read.csv(annual_use_file, check.names = FALSE)
current_use_comparison <- read.csv(
  current_use_comparison_file, check.names = FALSE
)
monthly_all_hazard <- read.csv(monthly_all_hazard_file, check.names = FALSE)
monthly_cause_hazard <- read.csv(
  monthly_cause_hazard_file, check.names = FALSE
)
reason_timing <- read.csv(reason_timing_file, check.names = FALSE)
transition_matrix <- read.csv(transition_matrix_file, check.names = FALSE)
destination_conditional <- read.csv(
  destination_conditional_file, check.names = FALSE
)
gap_distribution <- read.csv(gap_distribution_file, check.names = FALSE)
modern_protection_pathways <- read.csv(
  modern_protection_pathways_file, check.names = FALSE
)
effectiveness_transition <- read.csv(
  effectiveness_transition_file, check.names = FALSE
)
reason_outcomes <- read.csv(reason_outcomes_file, check.names = FALSE)
reason_method_outcomes <- read.csv(
  reason_method_outcomes_file, check.names = FALSE
)
leaky_bucket <- read.csv(leaky_bucket_file, check.names = FALSE)
switching_pathways <- read.csv(
  switching_pathways_file, check.names = FALSE
)

method_order <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception",
  "Other", "All methods"
)
method_detail_order <- c(
  "Injectables", "Implants", "Pill", "Other",
  "Emergency contraception"
)
horizon_order <- c("3 months", "6 months", "9 months", "12 months")
reason_columns <- c(
  "Method failure",
  "Desire to become pregnant",
  "Other fertility-related reasons",
  "Changes in menstrual bleeding",
  "Other side effects/health concerns",
  "Wanted more effective method",
  "Other method-related reasons",
  "Husband/partner disapproved",
  "Other reasons"
)

stopifnot(identical(as.character(all_cause$Method), method_order))
stopifnot(all(method_order %in% reasons$Method))
stopifnot(all(horizon_order %in% reasons$Duration))
stopifnot(all(reason_columns %in% names(reasons)))

escape_html <- function(x) {
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

fmt_pct <- function(x) sprintf("%.1f", as.numeric(x))
fmt_pct_or_dash <- function(x) {
  ifelse(is.finite(as.numeric(x)), sprintf("%.1f", as.numeric(x)), "&mdash;")
}
fmt_n <- function(x) format(round(as.numeric(x)), big.mark = ",", scientific = FALSE)

# Reliability flags for post-discontinuation tables are based on the
# unweighted number of eligible discontinued episodes in each method row.
# They describe denominator support, not the number of events in each outcome
# cell. The thresholds deliberately mirror the cautious presentation used for
# DHS life-table estimates.
reinitiation_support <- setNames(
  as.numeric(
    reinitiation_summary$`Eligible discontinued episodes (unweighted)`
  ),
  reinitiation_summary$Method
)
support_flag <- function(method_name) {
  n <- unname(reinitiation_support[method_name])
  if (length(n) == 0L || !is.finite(n) || method_name == "All methods") "" else
    if (n < 125) "&#8225;" else if (n < 250) "&#8224;" else ""
}
support_assessment <- function(method_name) {
  n <- unname(reinitiation_support[method_name])
  if (length(n) == 0L || !is.finite(n) || method_name == "All methods") {
    "Overall"
  } else if (n < 125) {
    "Limited; interpret cautiously"
  } else if (n < 250) {
    "Use caution"
  } else {
    "No count-based flag"
  }
}
supported_method_label <- function(method_name) {
  paste0(escape_html(method_name), "<sup>", support_flag(method_name), "</sup>")
}
reliability_note <- paste0(
  "<p class='note reliability-note'><strong>Reliability flags:</strong> ",
  "&#8224; 125&ndash;249 eligible discontinued episodes; ",
  "&#8225; fewer than 125. ",
  "Flags refer to the starting method-row denominator. Rare destination ",
  "cells may still be unstable even when the row itself is not flagged. ",
  "Confidence intervals that incorporate the complex survey design and ",
  "repeated episodes per woman are not yet available.</p>"
)

section_explanation <- function(question, population, interpretation, relevance) {
  paste0(
    "<div class='section-explanation'><div><h3>What this section answers</h3><p>",
    question, "</p><h3>Who or what is represented</h3><p>", population,
    "</p></div><div><h3>How to interpret the results</h3><p>",
    interpretation, "</p><h3>Why this matters programmatically</h3><p>",
    relevance, "</p></div></div>"
  )
}

table_guide <- function(rows, columns, totals, numerator, denominator, method, why) {
  paste0(
    "<details class='table-guide' open><summary>How to read and calculate this output</summary>",
    "<div class='table-guide-grid'><div><h4>Rows</h4><p>", rows,
    "</p><h4>Columns</h4><p>", columns,
    "</p><h4>What should add up?</h4><p>", totals,
    "</p></div><div><h4>Numerator</h4><p>", numerator,
    "</p><h4>Denominator</h4><p>", denominator,
    "</p></div><div><h4>Statistical method and why</h4><p>", method,
    "</p><h4>Programmatic use</h4><p>", why,
    "</p></div></div></details>"
  )
}

section_intro <- list(
  initiation = section_explanation(
    "How contraceptive use varies by calendar year, which methods are being started, how frequently starts occur, and whether methods with many starts are also discontinued quickly.",
    "Annual use is measured in observed woman-months. Initiation uses observed contraceptive episode starts reconstructed from the monthly calendar; a woman may contribute more than one start. Starts already underway when the calendar observation window begins cannot be counted as observed initiations.",
    "Annual calendar-based prevalence is the weighted share of observed woman-months with contraceptive use. Initiation mix is the composition of observed starts, and initiation rate is their frequency per observed calendar woman-time. These measures have different denominators.",
    "This separates demand or uptake patterns from continuity problems. A method may account for many starts because it is preferred or available, yet still require stronger counseling, resupply, or switching support if discontinuation is also high."
  ),
  all_cause = section_explanation(
    "How rapidly method-use episodes end for any reason and during which months the conditional risk of stopping is highest.",
    "The unit is an eligible contraceptive-use episode. Episodes enter the DHS life table when observed and at risk, and leave after discontinuation or censoring. A woman may contribute multiple episodes.",
    "Cumulative discontinuation answers whether an episode has ended by a milestone. Monthly hazard answers the conditional probability of ending during a particular month among episodes still continuing at that month's start. These are related but are not additive.",
    "The timing identifies when follow-up, anticipatory counseling, side-effect support, or resupply should occur and which method groups may need the most continuity support."
  ),
  predominance = section_explanation(
    "Which stated discontinuation reasons contribute the largest absolute probabilities for each method and follow-up milestone.",
    "The unit is an eligible method-use episode in the DHS discontinuation life table. Reasons are mutually exclusive competing endpoints attached to the end of an episode.",
    "The listed values are cause-specific cumulative incidences, not percentages among discontinuers. A reason can rank first because it represents a comparatively large absolute probability even when most episodes have not discontinued.",
    "Ranking reasons helps identify whether program attention should focus on side effects, bleeding, method preference, fertility intentions, partner opposition, access-related reasons, or other barriers."
  ),
  dhs = section_explanation(
    "What the DHS Table 7.11 structure looks like at 3, 6, 9, and 12 months when the same competing-risk definitions are applied.",
    "Rows are the DHS aggregate method categories and all methods combined. The analytic unit is an eligible method-use episode; columns represent mutually exclusive reasons for discontinuation.",
    "Each reason is an absolute cumulative probability from the original episode risk set. The reason columns sum to Any reason within a row before rounding. Switching is reported separately because it can overlap with a stated reason.",
    "The familiar DHS format supports report validation and lets programs compare method-specific levels and reason patterns consistently across time horizons."
  ),
  method_incidence = section_explanation(
    "For each method, how the absolute probability of each reason accumulates and which months contribute most strongly.",
    "The unit is an eligible use episode for the displayed method. All episodes still continuing and observable contribute to the monthly risk set, whether or not they later discontinue.",
    "Cumulative-incidence tables show absolute probability; monthly cause-specific hazards show conditional risk during a month; timing-share tables show how much of the 12-month cause-specific total had accumulated earlier. These quantities answer different questions.",
    "This indicates both what problem is most common and when it emerges, allowing counseling and follow-up to be timed to the observed pattern rather than applied uniformly."
  ),
  reason_distribution = section_explanation(
    "Among estimated discontinuations by a given milestone, what percentage is attributable to each stated reason.",
    "The unit remains the episode, but each displayed percentage is a ratio of life-table cumulative incidences rather than a simple count among observed discontinuers.",
    "This is a composition. Within each method and time point, the mutually exclusive reason shares sum to 100% before rounding. It should not be confused with the absolute probability of discontinuation shown in Sections 04 and 05.",
    "The composition shows which causes account for the greatest share of stopping and can guide the balance of counseling, service-quality, access, and reproductive-intention responses."
  ),
  reinitiation = section_explanation(
    "After a non-pregnancy-related discontinuation, how quickly any contraceptive method is started and how often pregnancy occurs first.",
    "The starting unit is an observed discontinued episode excluding method failure/pregnancy while using and desire to become pregnant. Follow-up begins when the episode ends; a woman may contribute multiple episodes.",
    "Reinitiation and pregnancy are competing first events. No observed event is the estimated probability of remaining free of either event through the milestone, accounting for interview censoring. At a single horizon the three states sum to 100%; cumulative columns across horizons do not.",
    "This identifies protection gaps, pregnancy exposure before restarting, and windows for same-day switching, referral, commodity continuity, and active follow-up."
  ),
  destinations = section_explanation(
    "Which method is first adopted after eligible discontinuation and whether early and later reinitiators choose different destination methods.",
    "The unit is an eligible discontinued episode from Section 07. The primary matrix conditions on estimated reinitiation; the expanded matrix retains all eligible episodes and also shows pregnancy and no observed event.",
    "In the primary matrix, each row sums to 100% across destination methods. In the expanded matrix, destination probabilities, pregnancy, and no event sum to 100%. These matrices therefore use different denominators.",
    "This tests whether programs make preferred replacement methods available and whether discontinuation is followed by method switching, return to the same method, traditional use, pregnancy, or continued non-use."
  ),
  gaps = section_explanation(
    "How long the interval lasts between an eligible discontinuation and the first subsequent contraceptive start.",
    "The unit is an eligible non-pregnancy-intent discontinued episode. Reinitiation intervals, pregnancy before restart, and no observed event are mutually exclusive first-year outcomes.",
    "The time bands are increments of the cumulative-incidence curve, not crude counts. All five restart intervals plus pregnancy and no observed event sum to 100% within each previous-method row before rounding.",
    "Long gaps indicate where same-day switching, rapid referral, resupply, side-effect management, or proactive outreach could reduce time without contraceptive protection when continued prevention is desired."
  ),
  effectiveness = section_explanation(
    "Whether the first subsequent method falls in a higher, equal, or lower programmatic effectiveness tier than the discontinued method.",
    "The unit is an eligible discontinued episode. Outcomes include four reinitiation classifications, pregnancy before restart, and no observed event by 12 months.",
    "The categories form a complete 12-month partition and sum to 100% within each row. Higher or lower refers only to a population-level effectiveness tier, not personal suitability, quality, autonomy, or whether a woman's choice was correct.",
    "This compact view can reveal whether method-switching pathways preserve access to effective options, while the actual destination matrix should remain the primary evidence for method choice."
  ),
  reason_outcomes = section_explanation(
    "How subsequent reinitiation, pregnancy, and event-free status differ according to the stated reason an episode ended.",
    "The unit is an observed discontinued episode. All nine DHS reason groups are retained, including method failure and desire for pregnancy, so their distinct pathways remain visible.",
    "For each reason and horizon, reinitiation, pregnancy before reinitiation, and no observed event are mutually exclusive modeled states that sum to 100%. Compare reasons at the same horizon or follow one outcome across time.",
    "Connecting the stated reason to what happens next distinguishes prompt switching from prolonged gaps and pregnancy, helping target reason-specific counseling, referral, access, and follow-up responses."
  ),
  method_reason = section_explanation(
    "Whether the pathway following a stated reason differs according to the method that was discontinued.",
    "Each cell begins with episodes in one previous-method and reason subgroup. Cells with fewer than 25 eligible episodes are suppressed; those with 25&ndash;49 are flagged because their point estimates are unstable.",
    "The selected outcome is a cumulative probability by the selected month. Within the same method-reason subgroup and horizon, reinitiation, pregnancy, and no event sum to 100%, although only one outcome is displayed at a time.",
    "The same reason may require different support for different methods&mdash;for example, injectable side-effect management versus referral after stopping a pill to obtain a preferred longer-acting option."
  ),
  leaky_bucket = section_explanation(
    "How results change when the analysis is restricted to episodes whose method start is observed inside the calendar, and how quickly those episodes lead to a different-method switch or same-method restart after discontinuation.",
    "The primary DHS-style population includes eligible episodes observed at risk in the analysis window and allows delayed entry for an episode that began earlier in the recorded calendar. The observed-start cohort requires both the start and immediately preceding calendar state to be observed.",
    "The observed-start cohort is a complementary uptake-to-discontinuation view. It should not replace the DHS-comparable life table because it answers a narrower question and may differ through cohort composition and available follow-up.",
    "Together, the views show whether newly observed starts are retained, how much method use is lost, and whether subsequent recovery occurs through a different method, the same method, pregnancy first, or no observed event."
  )
)

reading_guide <- list(
  initiation_mix = table_guide(
    "Each row is a method category. The All methods row is the total across categories.",
    "Weighted starts are survey-weighted episode starts; share is the percentage distribution of starts; the rate is starts per 1,000 observed calendar woman-months.",
    "Method shares add to 100% across mutually exclusive method rows before rounding. Counts and rates do not add to 100%.",
    "Weighted observed starts assigned to the row method.",
    "All weighted observed method starts for the share; all weighted observed calendar woman-months for the rate.",
    "Survey-weighted descriptive totals and ratios are used because this table summarizes observed starts rather than time to an event.",
    "Shows the method mix being initiated and how frequently new episodes begin."
  ),
  initiation_discontinuation = table_guide(
    "Each row is one method category; the initiation and discontinuation values are aligned by method but are not the same cohort denominator.",
    "The first numeric column is share of observed starts. The next four columns are cumulative discontinuation probabilities by duration since method initiation.",
    "Initiation shares add to 100% across methods. The four discontinuation columns are nested milestones and must not be added.",
    "For initiation, weighted starts of the row method; for discontinuation, weighted stopping events contributing month by month.",
    "All observed starts for initiation mix; the weighted life-table risk set of eligible episodes for discontinuation.",
    "A descriptive initiation ratio is placed beside weighted life-table estimates. The life table handles episodes with unequal observed duration and censoring.",
    "Reveals methods with substantial uptake but poor continuation, a potential signal for method-fit, counseling, resupply, or switching support."
  ),
  annual_mix = table_guide(
    "Each row is a calendar year in which episode starts were observed.",
    "Method columns are each method's share of starts within that year; the final column is the weighted total number of starts observed that year.",
    "Method-share columns add to 100% within each year before rounding. Weighted-start totals are counts and are not percentages.",
    "Weighted observed starts for one method in the year.",
    "All weighted observed method starts in that same year.",
    "Survey-weighted annual cross-tabulation is appropriate because the question concerns composition of observed starts, not survival after initiation.",
    "Shows whether the mix of methods being initiated changed during the calendar period; partial boundary years require caution."
  ),
  annual_use = table_guide(
    "Each row is a calendar year represented in the 3-62 months-before-interview analysis window.",
    "Use columns are weighted annual average monthly prevalence. Support columns show observed woman-months and whether the year has full or partial sample coverage.",
    "Any-method use equals modern plus traditional method use before rounding. Percentages are not summed across years.",
    "Weighted observed woman-months coded as contraceptive use, or specifically as modern-method use.",
    "All valid observed woman-months in the same calendar year, including non-use and pregnancy-related states; unknown calendar states are excluded.",
    "Survey-weighted woman-month ratios summarize average use across the months observed in a year. This is not a point-in-time DHS current-use estimate.",
    "Shows how the prevalence of use changed across calendar years while making partial boundary-year coverage visible."
  ),
  annual_mix_wide = table_guide(
    "Each row is a discontinuation method category and each column is a calendar year.",
    "Cells show the percentage of all observed contraceptive episode starts in that year that used the row method.",
    "The five method rows add to 100% within every year before rounding.",
    "Survey-weighted observed starts for the row method in that calendar year.",
    "All survey-weighted observed contraceptive starts in the same calendar year.",
    "A survey-weighted annual cross-tabulation describes the method composition of starts; no life table or hazard model is used.",
    "Makes annual shifts in the mix of initiated methods easy to compare across method rows."
  ),
  current_use_comparison = table_guide(
    "Rows are interview years and an overall survey row. Each woman contributes once, at her interview date.",
    "Survey columns use v312 current method and the DHS modern-method classification; calendar columns use vcal_1 in the same interview month. Difference columns are calendar minus survey-question percentage points.",
    "These are alternative measurements of the same interview-month status and are not added together. Differences should be close to zero.",
    "Survey-weighted women classified as using any method or a modern method at interview.",
    "All women with valid survey current-use fields and a valid calendar state in the interview month.",
    "Survey-weighted prevalence and a paired measurement comparison are used. No survival or hazard model is involved.",
    "Validates that the retrospective calendar reproduces the cross-sectional current-use measure before it is used for annual retrospective summaries."
  ),
  all_cause = table_guide(
    "Each row is a DHS aggregate method category; All methods pools eligible episodes across categories.",
    "Columns are cumulative probabilities that an episode discontinued for any reason by 3, 6, 9, or 12 months, plus weighted episode support.",
    "Milestone percentages are cumulative and must not be added. Each later value should be at least as large as the earlier value.",
    "At month t, the survey-weighted number of episodes discontinuing for any reason in that month.",
    "The survey-weighted episodes still observed and continuing at the start of month t, with DHS delayed-entry and censoring rules applied.",
    "A weighted discrete-time life table estimates 1 minus survival. It is used because episodes contribute different amounts of observable follow-up.",
    "Compares continuation across methods and shows how rapidly discontinuation accumulates."
  ),
  monthly_hazard = table_guide(
    "Each row is a method category and each cell describes one month since that method episode began.",
    "M1&ndash;M12 are conditional monthly discontinuation hazards, not cumulative probabilities.",
    "Monthly hazards do not add to the cumulative discontinuation percentage because each month uses a changing risk set and survival is multiplicative.",
    "Weighted all-cause discontinuations occurring during the displayed month.",
    "Weighted episodes still observed and not yet discontinued at the beginning of that month.",
    "A nonparametric discrete-time hazard is used to identify when risk is elevated without imposing a fitted hazard shape.",
    "Identifies specific months when follow-up or resupply support may be most valuable."
  ),
  leading_reasons = table_guide(
    "Each row is a method category. Inside each time cell, reasons are ordered from the largest to the third-largest cumulative incidence.",
    "Columns are 3-, 6-, 9-, and 12-month horizons; percentages are absolute cause-specific cumulative incidences.",
    "The three displayed reasons are only the leaders and do not add to Any reason unless they happen to exhaust all causes. Rankings should not be added across horizons.",
    "Weighted discontinuations attributed to a particular reason, accumulated through the selected horizon with survival weighting.",
    "The weighted risk set of method episodes still at risk of any discontinuation at each contributing month.",
    "Weighted Aalen-Johansen competing-risk cumulative incidence is used because an episode can end for only one first recorded reason and other reasons preclude that outcome.",
    "Provides a concise view of the reasons most likely to merit program attention for each method and duration."
  ),
  dhs_reason = table_guide(
    "Each row is a DHS method category; All methods combines all eligible episodes.",
    "Reason columns are mutually exclusive cause-specific cumulative incidences; Any reason is their sum. Switching is an overlapping behavioral outcome and weighted episodes describe support.",
    "The nine reason columns add to Any reason before rounding. Switching must not be added because an episode can both report a reason and switch.",
    "Weighted discontinuations attributed to the displayed reason during each month through the selected horizon.",
    "Weighted episodes still continuing and observable at the beginning of each month.",
    "The weighted Aalen-Johansen estimator preserves competing risks and censoring and mirrors the DHS Table 7.11 approach.",
    "Supports direct comparison with the published DHS structure while extending it to earlier milestones."
  ),
  reason_cif = table_guide(
    "Each method card contains one row per mutually exclusive reason plus an Any reason row.",
    "Columns show absolute cause-specific cumulative incidence at 3, 6, 9, and 12 months.",
    "Within a method and horizon, reason rows add to Any reason. Values across horizons are cumulative and must not be added.",
    "Weighted discontinuations for the row reason that occur by each month, adjusted by the probability of remaining event-free beforehand.",
    "Weighted episodes still at risk of any discontinuation at each month.",
    "Aalen-Johansen competing-risk estimation is used because discontinuation for one reason prevents first discontinuation for another reason.",
    "Shows the absolute size and timing of each reason-specific discontinuation problem."
  ),
  cause_hazard = table_guide(
    "Within each method panel, rows are discontinuation reasons and columns are months since initiation.",
    "Cells are cause-specific monthly hazards; darker color denotes a larger hazard within that method panel.",
    "Hazards neither add across months nor equal reason distributions. The sum across reasons in one month equals that month's all-cause hazard before rounding.",
    "Weighted discontinuations for the displayed reason occurring in that month.",
    "All weighted episodes for that method still at risk of discontinuation at the month's start.",
    "Nonparametric cause-specific monthly hazards preserve the observed timing and avoid imposing a regression model.",
    "Locates the months when specific problems such as bleeding or side effects are most likely to appear."
  ),
  reason_timing = table_guide(
    "Each method card has one row per reason.",
    "The first value is the reason's 12-month cumulative incidence. The remaining columns are the percentage of that 12-month amount already accumulated by months 3, 6, and 9.",
    "Timing shares for different milestones are nested and must not be added. Each share can range from 0% to 100% of its own reason-specific 12-month total.",
    "The reason-specific cumulative incidence by month 3, 6, or 9.",
    "That same reason's 12-month cumulative incidence.",
    "Ratios of Aalen-Johansen cumulative incidences are used to summarize how early each cause-specific burden develops.",
    "Distinguishes reasons requiring very early support from those that continue accumulating later."
  ),
  reason_distribution = table_guide(
    "In the method view, rows are reasons and columns are horizons. In the time-point view, rows are methods and columns are reasons; both layouts contain the same estimates.",
    "Cells show each reason's percentage share of estimated discontinuation for that method and horizon.",
    "Across the nine mutually exclusive reasons, shares add to 100% within a method and horizon before rounding.",
    "The weighted cause-specific cumulative incidence for one reason.",
    "The weighted cumulative incidence of discontinuation for Any reason for the same method and horizon.",
    "A ratio of competing-risk cumulative incidences is used so the composition remains consistent with the life-table estimates rather than relying on raw event counts.",
    "Shows which reasons account for the greatest portion of discontinuation among estimated discontinuations."
  ),
  reinitiation_summary = table_guide(
    "Each row is the method that was discontinued; All methods pools all eligible non-pregnancy-related discontinuations.",
    "The first five columns are cumulative reinitiation probabilities. The next two are pregnancy first and no event at 12 months; final columns show weighted and unweighted support.",
    "Only reinitiated by 12 months + pregnancy before reinitiation by 12 months + no observed event at 12 months add to 100%. The five reinitiation milestones are nested and must not be added.",
    "At month t, weighted first reinitiations; pregnancy uses weighted first pregnancy-related events before restarting.",
    "Weighted episodes still observed and free of both outcomes at the start of month t.",
    "Weighted Aalen-Johansen competing-risk cumulative incidence is used because pregnancy prevents observing reinitiation first and censoring varies across episodes.",
    "Compares how quickly protection resumes after different methods and quantifies pregnancy occurring before restart."
  ),
  reinitiation_monthly = table_guide(
    "Each curve or exact-value row represents the method that was discontinued.",
    "Months 1&ndash;12 show cumulative probability of having started any subsequent contraceptive method.",
    "Monthly cumulative values do not add; they can only stay the same or increase. The difference between successive months is the additional probability accumulated in that interval.",
    "Weighted first reinitiations occurring in each month, incorporated into the cumulative incidence.",
    "Weighted episodes still under observation and free of reinitiation and pregnancy at that month's start.",
    "Aalen-Johansen estimation produces a cumulative curve while correctly treating pregnancy as a competing event.",
    "Shows whether reinitiation is concentrated immediately after stopping or continues gradually throughout the year."
  ),
  pregnancy = table_guide(
    "Each row is the method discontinued before follow-up began.",
    "Columns show cumulative incidence of pregnancy, birth, or termination observed before contraceptive reinitiation by each milestone.",
    "Horizons are cumulative and must not be added. At a single horizon, pregnancy is one component of the reinitiation/pregnancy/no-event partition.",
    "Weighted first pregnancy-related events occurring before reinitiation in each month.",
    "Weighted episodes still observed and free of both reinitiation and pregnancy at that month's start.",
    "Aalen-Johansen competing-risk estimation is required because reinitiation and pregnancy are mutually exclusive first observed outcomes.",
    "Highlights methods after which pregnancy occurs before contraceptive protection resumes; intention cannot be inferred from this outcome alone."
  ),
  destination = table_guide(
    "Each row is the discontinued method and each column is the first method subsequently initiated.",
    "Cells show destination shares among episodes estimated to have reinitiated by the selected milestone.",
    "Destination columns add to 100% within each row before rounding. Pregnancy and no event are absent because the matrix is conditional on reinitiation.",
    "Destination-specific Aalen-Johansen cumulative incidence.",
    "Sum of cumulative incidence across all reinitiation destinations for the same row and horizon.",
    "Destination-specific competing-risk probabilities are normalized among reinitiators, preserving censoring and the timing of competing pregnancy.",
    "Shows which replacement methods programs must make available and whether the destination mix changes between early and later reinitiators."
  ),
  destination_complete = table_guide(
    "Each row is the discontinued method; columns include all first reinitiation destinations, pregnancy before restart, and no observed event.",
    "Cells are absolute cumulative probabilities among all eligible discontinued episodes by the selected month.",
    "Every outcome column adds to 100% within a row before rounding.",
    "Weighted first events assigned to each destination or pregnancy cause; no event is the remaining state probability.",
    "All eligible discontinued episodes represented by that row, with the monthly risk set adjusted for censoring.",
    "A multi-cause Aalen-Johansen partition is used because destination methods and pregnancy compete as first outcomes.",
    "Places method choice in context by retaining episodes that have not restarted or experience pregnancy first."
  ),
  gap = table_guide(
    "Each row is the discontinued method.",
    "Columns are mutually exclusive restart intervals, pregnancy before restart by month 12, and no observed event by month 12.",
    "All columns add to 100% within each row before rounding.",
    "For a restart interval, the increment in reinitiation cumulative incidence between its boundaries; for pregnancy and no event, the corresponding 12-month state probability.",
    "All eligible non-pregnancy-intent discontinued episodes in the row method, handled through monthly weighted risk sets.",
    "Differences between Aalen-Johansen cumulative-incidence milestones produce mutually exclusive gap intervals while retaining competing pregnancy and censoring.",
    "Shows how much reinitiation is prompt versus delayed and where prolonged gaps are concentrated."
  ),
  modern_protection = table_guide(
    "Each row is an eligible discontinued modern-method episode group; a woman may contribute more than one episode.",
    "Columns form mutually exclusive first post-discontinuation pathways through month 12: immediate modern reinitiation, modern reinitiation in months 2-3, modern reinitiation in months 4-12, first traditional-method use, pregnancy first, or neither event observed.",
    "The six pathway columns add to 100% within each row before rounding.",
    "Weighted first events assigned to the applicable modern restart band, traditional-method start, or pregnancy cause; the event-free probability is the remaining state.",
    "All eligible discontinued modern-method episodes in the row, handled through monthly survey-weighted risk sets.",
    "A multi-cause Aalen-Johansen cumulative-incidence partition retains competing pregnancy and right-censoring while making the pathways mutually exclusive.",
    "Distinguishes successful prompt continuation of modern protection from short gaps, prolonged gaps, movement to traditional use, pregnancy, and no observed return."
  ),
  effectiveness = table_guide(
    "Each row is the discontinued method.",
    "Columns classify the first subsequent method relative to the previous method's effectiveness tier, plus pregnancy, no event, the unweighted eligible-episode denominator, and a count-based reliability flag.",
    "All columns add to 100% within each row before rounding.",
    "Weighted destination-specific cumulative incidence grouped into the displayed transition category.",
    "All eligible discontinued episodes in the row, handled through the competing-risk risk sets.",
    "Aalen-Johansen destination probabilities are aggregated by a predefined effectiveness-tier mapping to retain timing, pregnancy, and censoring.",
    "Offers a compact pathway summary, but should be interpreted alongside actual method destinations and women's preferences."
  ),
  reason_outcome = table_guide(
    "Each row is one DHS reason for discontinuation across all previous methods.",
    "For every horizon, the three outcomes are reinitiation, pregnancy before reinitiation, and no observed event. Heat maps display the same values separately by outcome.",
    "Within each reason and horizon, the three outcome probabilities add to 100%. Horizons are cumulative and must not be added.",
    "Weighted first reinitiations or weighted first pregnancy-related events in each month; no event is the remaining state probability.",
    "Weighted episodes discontinued for the row reason and still free of both outcomes at each month's start.",
    "Reason-stratified Aalen-Johansen competing-risk estimation accounts for differential censoring and the fact that pregnancy precludes reinitiation as the first outcome.",
    "Connects why use ended to what happens next, identifying reason-specific gaps and opportunities for tailored support."
  ),
  method_reason = table_guide(
    "Rows are previous methods and columns are DHS reasons. Each cell represents one previous-method &times; reason subgroup.",
    "The controls select one cumulative outcome and one horizon. Color intensity and the printed value represent that cell's estimated probability.",
    "For a given method-reason cell and horizon, reinitiation + pregnancy first + no event add to 100%, although the interface displays one outcome at a time. Cells across reasons should not be added.",
    "Weighted first events for the selected outcome within the method-reason subgroup; no event is the remaining state probability.",
    "Weighted episodes in that method-reason subgroup still free of both outcomes at the beginning of each contributing month.",
    "Separate Aalen-Johansen competing-risk estimates are fit descriptively within each subgroup. Sparse cells are suppressed because unstable estimates can be misleading.",
    "Shows whether the same stated reason leads to different pathways depending on the method that ended."
  ),
  leaky_discontinuation = table_guide(
    "Each row is a method category. The paired columns compare the primary DHS-style life-table population with episodes whose starts are directly observed in the calendar.",
    "For each population, columns show cumulative all-cause discontinuation by 3, 6, 9, and 12 months.",
    "Milestones are cumulative and must not be added. Values can be compared across populations at the same method and milestone.",
    "Weighted episodes discontinuing in each month since initiation.",
    "Weighted episodes still continuing and observable at the beginning of that month, under the displayed cohort definition.",
    "Separate survey-weighted discrete-time life tables estimate one minus survival in each population.",
    "Shows whether observed new starts have continuation patterns similar to the broader DHS-comparable population."
  ),
  switching_pathways = table_guide(
    "Rows identify a cohort and follow-up milestone. The method-specific table below fixes the milestone at 12 months.",
    "Columns separate switch to a different method, restart of the same method, any-method reinitiation, pregnancy before reinitiation, and no observed event.",
    "Different-method switch plus same-method restart equals any-method reinitiation. Different-method switch, same-method restart, pregnancy, and no observed event sum to 100% at each row and milestone.",
    "Weighted first events assigned to a different-method start, same-method start, or pregnancy before either restart.",
    "Weighted eligible discontinued episodes still observed and free of all competing outcomes at the start of each month.",
    "Survey-weighted Aalen-Johansen competing-risk cumulative incidence separates destination type while accounting for pregnancy and interview censoring.",
    "Distinguishes rapid recovery of contraceptive use from true method switching and identifies where same-method return or persistent gaps dominate."
  )
)

all_cause_rows <- vapply(seq_len(nrow(all_cause)), function(i) {
  method_class <- if (all_cause$Method[i] == "All methods") " total-row" else ""
  paste0(
    "<tr class='", method_class, "'><th scope='row'>",
    escape_html(all_cause$Method[i]), "</th>",
    paste0(
      "<td><span class='value-pill'>", fmt_pct(all_cause[i, horizon_order]),
      "%</span></td>",
      collapse = ""
    ),
    "<td>", fmt_n(all_cause$`Weighted episodes`[i]), "</td></tr>"
  )
}, character(1))

predominance_rows <- vapply(method_order, function(method_name) {
  method_data <- predominance[predominance$Method == method_name,]
  method_data <- method_data[match(horizon_order, method_data$Duration),]
  cells <- vapply(seq_len(nrow(method_data)), function(i) {
    paste0(
      "<td><ol class='reason-list'>",
      "<li><strong>", escape_html(method_data$`Leading reason`[i]),
      "</strong><span>", fmt_pct(method_data$`Leading cumulative incidence (%)`[i]), "%</span></li>",
      "<li>", escape_html(method_data$`Second reason`[i]),
      "<span>", fmt_pct(method_data$`Second cumulative incidence (%)`[i]), "%</span></li>",
      "<li>", escape_html(method_data$`Third reason`[i]),
      "<span>", fmt_pct(method_data$`Third cumulative incidence (%)`[i]), "%</span></li>",
      "</ol></td>"
    )
  }, character(1))
  row_class <- if (method_name == "All methods") " total-row" else ""
  paste0(
    "<tr class='", row_class, "'><th scope='row'>", escape_html(method_name),
    "</th>", paste0(cells, collapse = ""), "</tr>"
  )
}, character(1))

reason_labels <- c(
  "Method<br>failure",
  "Desire to<br>become pregnant",
  "Other fertility-<br>related reasons",
  "Changes in<br>menstrual bleeding",
  "Other side effects/<br>health concerns",
  "Wanted a more<br>effective method",
  "Other method-<br>related reasons",
  "Husband/partner<br>disapproved",
  "Other<br>reasons"
)

full_table <- function(horizon, index) {
  dat <- reasons[reasons$Duration == horizon,]
  dat <- dat[match(method_order, dat$Method),]
  rows <- vapply(seq_len(nrow(dat)), function(i) {
    reason_cells <- paste0(
      "<td>", fmt_pct(unlist(dat[i, reason_columns], use.names = FALSE)), "</td>",
      collapse = ""
    )
    row_class <- if (dat$Method[i] == "All methods") " total-row" else ""
    paste0(
      "<tr class='", row_class, "'><th scope='row'>", escape_html(dat$Method[i]),
      "</th>", reason_cells,
      "<td class='any-reason'>", fmt_pct(dat$`Any reason`[i]), "</td>",
      "<td>", fmt_pct(dat$`Switched to another method`[i]), "</td>",
      "<td>", fmt_n(dat$`Weighted episodes`[i]), "</td></tr>"
    )
  }, character(1))

  paste0(
    "<section class='duration-panel", if (index == 1L) " active" else "",
    "' id='duration-", index, "' role='tabpanel'>",
    "<div class='panel-heading'><div><p class='eyebrow'>DHS Table 7.11 structure</p>",
    "<h3>", escape_html(horizon), "</h3></div>",
    "<p>Cumulative percentage of episodes discontinued by this duration</p></div>",
    "<div class='table-scroll'><table class='reason-table'><thead>",
    "<tr><th rowspan='2'>Method</th><th colspan='9'>Reason for discontinuation</th>",
    "<th rowspan='2'>Any<br>reason</th><th rowspan='2'>Switched to<br>another method</th>",
    "<th rowspan='2'>Weighted<br>episodes</th></tr><tr>",
    paste0("<th>", reason_labels, "</th>", collapse = ""),
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></section>"
  )
}

full_tables <- paste0(
  mapply(full_table, horizon_order, seq_along(horizon_order), USE.NAMES = FALSE),
  collapse = ""
)

# Create method-specific matrices with reasons in rows and duration in columns.
# These are also exported as CSV files so every number displayed in Sections 4
# and 5 can be independently reviewed outside the HTML.
method_reason_matrix <- function(method_name, distribution = FALSE) {
  dat <- reasons[reasons$Method == method_name,]
  dat <- dat[match(horizon_order, dat$Duration),]

  if (!distribution) {
    row_names <- c(reason_columns, "Any reason")
    values <- t(as.matrix(dat[, row_names, drop = FALSE]))
    colnames(values) <- horizon_order
    return(data.frame(
      Method = method_name,
      Reason = row_names,
      values,
      check.names = FALSE,
      row.names = NULL
    ))
  }

  reason_values <- as.matrix(dat[, reason_columns, drop = FALSE])
  denominators <- as.numeric(dat$`Any reason`)
  shares <- sweep(reason_values, 1L, denominators, "/") * 100
  shares[!is.finite(shares)] <- NA_real_
  values <- t(shares)
  colnames(values) <- horizon_order
  out <- data.frame(
    Method = method_name,
    Reason = reason_columns,
    values,
    check.names = FALSE,
    row.names = NULL
  )
  total <- data.frame(
    Method = method_name,
    Reason = "All discontinuation reasons",
    t(setNames(rep(100, length(horizon_order)), horizon_order)),
    check.names = FALSE,
    row.names = NULL
  )
  names(total) <- names(out)
  rbind(out, total)
}

cumulative_matrices <- do.call(
  rbind,
  lapply(method_detail_order, method_reason_matrix, distribution = FALSE)
)
distribution_matrices <- do.call(
  rbind,
  lapply(method_detail_order, method_reason_matrix, distribution = TRUE)
)

write.csv(
  cumulative_matrices,
  file.path(derived_dir, "cumulative_incidence_by_method_3_6_9_12.csv"),
  row.names = FALSE
)
write.csv(
  distribution_matrices,
  file.path(derived_dir, "reason_distribution_among_discontinued_3_6_9_12.csv"),
  row.names = FALSE
)

matrix_card <- function(method_name, matrix_data, distribution = FALSE) {
  dat <- matrix_data[matrix_data$Method == method_name,]
  rows <- vapply(seq_len(nrow(dat)), function(i) {
    is_total <- dat$Reason[i] %in% c(
      "Any reason", "All discontinuation reasons"
    )
    values <- as.numeric(dat[i, horizon_order])
    paste0(
      "<tr", if (is_total) " class='total-row'" else "", "><th scope='row'>",
      escape_html(dat$Reason[i]), "</th>",
      paste0("<td>", fmt_pct(values), "%</td>", collapse = ""),
      "</tr>"
    )
  }, character(1))

  paste0(
    "<article class='method-card'><h3>", escape_html(method_name), "</h3>",
    "<div class='table-scroll'><table class='matrix-table'><thead><tr>",
    "<th>", if (distribution) "Reason among discontinued episodes" else "Reason for discontinuation", "</th>",
    paste0("<th>", horizon_order, "</th>", collapse = ""),
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></article>"
  )
}

cumulative_cards <- paste0(
  vapply(
    method_detail_order,
    matrix_card,
    character(1),
    matrix_data = cumulative_matrices,
    distribution = FALSE
  ),
  collapse = ""
)
distribution_cards <- paste0(
  vapply(
    method_detail_order,
    matrix_card,
    character(1),
    matrix_data = distribution_matrices,
    distribution = TRUE
  ),
  collapse = ""
)

# Section 5 also presents the same reason distributions with methods in rows
# and reasons in columns. This is a transpose/reorganization of the method-card
# tables above, not a different estimator.
distribution_horizon_table <- function(horizon, open = FALSE) {
  dat <- distribution_matrices[
    distribution_matrices$Reason %in% reason_columns,
  ]
  rows <- vapply(method_detail_order, function(method_name) {
    method_dat <- dat[dat$Method == method_name,]
    method_dat <- method_dat[match(reason_columns, method_dat$Reason),]
    values <- as.numeric(method_dat[[horizon]])
    paste0(
      "<tr><th scope='row'>", escape_html(method_name), "</th>",
      paste0("<td>", fmt_pct(values), "%</td>", collapse = ""),
      "<td class='total-share'>100.0%</td></tr>"
    )
  }, character(1))

  paste0(
    "<details class='distribution-layout'", if (open) " open" else "", ">",
    "<summary>", escape_html(horizon), " distribution table</summary>",
    "<div class='table-scroll'><table class='reason-table distribution-wide'>",
    "<thead><tr><th>Method</th>",
    paste0("<th>", reason_labels, "</th>", collapse = ""),
    "<th>Total</th></tr></thead><tbody>",
    paste0(rows, collapse = ""),
    "</tbody></table></div></details>"
  )
}

distribution_horizon_tables <- paste0(
  mapply(
    distribution_horizon_table,
    horizon_order,
    seq_along(horizon_order) == 1L,
    USE.NAMES = FALSE
  ),
  collapse = ""
)

injectable_12 <- reasons[
  reasons$Method == "Injectables" & reasons$Duration == "12 months",
]
example_numerator <- injectable_12$`Desire to become pregnant`
example_denominator <- injectable_12$`Any reason`
example_share <- example_numerator / example_denominator * 100

# Section 1: initiation mix and observed method-start rates.
initiation_mix_rows <- vapply(method_order, function(method_name) {
  dat <- initiation_mix[initiation_mix$Method == method_name,]
  rate_dat <- initiation_rates[initiation_rates$Method == method_name,]
  row_class <- if (method_name == "All methods") " total-row" else ""
  paste0(
    "<tr class='", row_class, "'><th scope='row'>", escape_html(method_name),
    "</th><td>", fmt_n(dat$`Observed starts (weighted)`),
    "</td><td>", fmt_pct(dat$`Share of observed starts (%)`), "%</td>",
    "<td>",
    fmt_pct(
      rate_dat$`Observed starts per 1,000 weighted calendar woman-months`
    ),
    "</td></tr>"
  )
}, character(1))

initiation_discontinuation_rows <- vapply(
  method_order,
  function(method_name) {
    mix_dat <- initiation_mix[initiation_mix$Method == method_name,]
    discontinuation_dat <- all_cause[all_cause$Method == method_name,]
    row_class <- if (method_name == "All methods") " total-row" else ""
    paste0(
      "<tr class='", row_class, "'><th scope='row'>",
      escape_html(method_name), "</th>",
      "<td>", fmt_pct(mix_dat$`Share of observed starts (%)`), "%</td>",
      paste0(
        "<td>", fmt_pct(discontinuation_dat[, horizon_order]), "%</td>",
        collapse = ""
      ),
      "</tr>"
    )
  },
  character(1)
)

annual_years <- sort(unique(annual_initiation$Year))
annual_mix_rows <- vapply(annual_years, function(year_value) {
  dat <- annual_initiation[annual_initiation$Year == year_value,]
  shares <- vapply(method_detail_order, function(method_name) {
    value <- dat$`Share of starts within year (%)`[dat$Method == method_name]
    if (length(value) == 0L) 0 else value[1]
  }, numeric(1))
  total_starts <- unique(dat$`All weighted starts`)[1]
  paste0(
    "<tr><th scope='row'>", year_value, "</th>",
    paste0("<td>", fmt_pct(shares), "%</td>", collapse = ""),
    "<td>", fmt_n(total_starts), "</td></tr>"
  )
}, character(1))

annual_use_rows <- vapply(seq_len(nrow(annual_use)), function(i) {
  paste0(
    "<tr><th scope='row'>", annual_use$`Calendar year`[i], "</th>",
    "<td>", fmt_pct(annual_use$`Any contraceptive method use (%)`[i]),
    "%</td>",
    "<td>", fmt_pct(
      annual_use$`Modern contraceptive method use (%)`[i]
    ), "%</td>",
    "<td>", fmt_pct_or_dash(
      annual_use$`v312 any-method current use (%)`[i]
    ), ifelse(
      is.finite(annual_use$`v312 any-method current use (%)`[i]), "%", ""
    ), "</td>",
    "<td>", fmt_pct_or_dash(
      annual_use$`v312/v313 modern-method current use (%)`[i]
    ), ifelse(
      is.finite(
        annual_use$`v312/v313 modern-method current use (%)`[i]
      ), "%", ""
    ), "</td>",
    "<td>", fmt_n(
      annual_use$`Observed calendar woman-months (weighted)`[i]
    ), "</td>",
    "<td>", escape_html(annual_use$Coverage[i]), "</td></tr>"
  )
}, character(1))

current_use_comparison_rows <- vapply(
  seq_len(nrow(current_use_comparison)),
  function(i) {
    paste0(
      "<tr", if (current_use_comparison$`Interview period`[i] ==
        "All interviews") " class='total-row'" else "", "><th scope='row'>",
      escape_html(current_use_comparison$`Interview period`[i]), "</th>",
      "<td>", fmt_pct(
        current_use_comparison$`v312 any-method current use (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        current_use_comparison$`Calendar interview-month any-method use (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        current_use_comparison$`Calendar minus v312 any-method difference (percentage points)`[i]
      ), "</td>",
      "<td>", fmt_pct(
        current_use_comparison$`v312/v313 modern-method current use (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        current_use_comparison$`Calendar interview-month modern-method use (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        current_use_comparison$`Calendar minus survey modern-method difference (percentage points)`[i]
      ), "</td>",
      "<td>", fmt_n(current_use_comparison$`Women (weighted)`[i]),
      "</td></tr>"
    )
  },
  character(1)
)

annual_initiation_years <- setdiff(
  names(annual_initiation_wide), "Method"
)
annual_mix_wide_rows <- vapply(
  method_detail_order,
  function(method_name) {
    dat <- annual_initiation_wide[
      annual_initiation_wide$Method == method_name,
    ]
    stopifnot(nrow(dat) == 1L)
    paste0(
      "<tr><th scope='row'>", escape_html(method_name), "</th>",
      paste0(
        "<td>", fmt_pct(unlist(
          dat[1, annual_initiation_years, drop = FALSE],
          use.names = FALSE
        )), "%</td>",
        collapse = ""
      ),
      "</tr>"
    )
  },
  character(1)
)

leaky_bucket_rows <- vapply(seq_len(nrow(leaky_bucket)), function(i) {
  method_class <- if (leaky_bucket$Method[i] == "All methods") {
    " class='total-row'"
  } else {
    ""
  }
  primary_values <- unlist(
    leaky_bucket[i, paste0(
      horizon_order, " - DHS-style population"
    ), drop = FALSE],
    use.names = FALSE
  )
  observed_start_values <- unlist(
    leaky_bucket[i, paste0(
      horizon_order, " - observed-start cohort"
    ), drop = FALSE],
    use.names = FALSE
  )
  paste0(
    "<tr", method_class, "><th scope='row'>",
    escape_html(leaky_bucket$Method[i]), "</th>",
    paste0("<td>", fmt_pct(primary_values), "%</td>", collapse = ""),
    paste0(
      "<td>", fmt_pct(observed_start_values), "%</td>",
      collapse = ""
    ),
    "</tr>"
  )
}, character(1))

switching_overall <- switching_pathways[
  switching_pathways$Method == "All methods",
]
switching_overall <- switching_overall[order(
  match(
    switching_overall$Cohort,
    c(
      "DHS-style eligible discontinuations",
      "Observed-start leaky-bucket cohort"
    )
  ),
  switching_overall$Month
),]
switching_timing_rows <- vapply(
  seq_len(nrow(switching_overall)),
  function(i) {
    paste0(
      "<tr><th scope='row'>", escape_html(switching_overall$Cohort[i]),
      "</th><td>", switching_overall$Month[i], " months</td>",
      "<td>", fmt_pct(
        switching_overall$`Switched to different method (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        switching_overall$`Restarted same method (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        switching_overall$`Any-method reinitiation (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        switching_overall$`Pregnancy before reinitiation (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        switching_overall$`No observed event (%)`[i]
      ), "%</td></tr>"
    )
  },
  character(1)
)

leaky_switching_12 <- switching_pathways[
  switching_pathways$Cohort == "Observed-start leaky-bucket cohort" &
    switching_pathways$Month == 12L,
]
leaky_switching_12 <- leaky_switching_12[
  match(method_order, leaky_switching_12$Method),
]
leaky_switching_method_rows <- vapply(
  seq_len(nrow(leaky_switching_12)),
  function(i) {
    method_class <- if (leaky_switching_12$Method[i] == "All methods") {
      " class='total-row'"
    } else {
      ""
    }
    paste0(
      "<tr", method_class, "><th scope='row'>",
      escape_html(leaky_switching_12$Method[i]), "</th>",
      "<td>", fmt_pct(
        leaky_switching_12$`Switched to different method (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        leaky_switching_12$`Restarted same method (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        leaky_switching_12$`Any-method reinitiation (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        leaky_switching_12$`Pregnancy before reinitiation (%)`[i]
      ), "%</td>",
      "<td>", fmt_pct(
        leaky_switching_12$`No observed event (%)`[i]
      ), "%</td>",
      "<td>", fmt_n(
        leaky_switching_12$`Weighted eligible episodes`[i]
      ), "</td><td>", fmt_n(
        leaky_switching_12$`Unweighted eligible episodes`[i]
      ), "</td></tr>"
    )
  },
  character(1)
)

# Section 6: cumulative incidence of contraceptive reinitiation following an
# observed non-pregnancy-related discontinuation.
reinitiation_horizons <- c(
  "1 month", "3 months", "6 months", "9 months", "12 months"
)
stopifnot(all(method_order %in% reinitiation$Method))
stopifnot(all(reinitiation_horizons %in% reinitiation$Horizon))

reinitiation_table_rows <- vapply(method_order, function(method_name) {
  dat <- reinitiation[reinitiation$Method == method_name,]
  dat <- dat[match(reinitiation_horizons, dat$Horizon),]
  month_12 <- dat[dat$Horizon == "12 months",]
  sample_row <- reinitiation_summary[
    reinitiation_summary$Method == method_name,
  ]
  row_class <- if (method_name == "All methods") " total-row" else ""
  paste0(
    "<tr class='", row_class, "'><th scope='row'>", supported_method_label(method_name),
    "</th>",
    paste0(
      "<td>", fmt_pct(dat$`Reinitiated (%)`), "%</td>",
      collapse = ""
    ),
    "<td class='outcome-partition'>",
    fmt_pct(month_12$`Pregnancy competing event (%)`), "%</td>",
    "<td class='outcome-partition'>",
    fmt_pct(month_12$`No observed event (%)`), "%</td>",
    "<td>",
    fmt_n(sample_row$`Eligible discontinued episodes (weighted)`),
    "</td><td>",
    format(
      sample_row$`Eligible discontinued episodes (unweighted)`,
      big.mark = ",", scientific = FALSE
    ),
    "</td></tr>"
  )
}, character(1))

pregnancy_table_rows <- vapply(method_order, function(method_name) {
  dat <- reinitiation[reinitiation$Method == method_name,]
  dat <- dat[match(reinitiation_horizons, dat$Horizon),]
  row_class <- if (method_name == "All methods") " total-row" else ""
  paste0(
    "<tr class='", row_class, "'><th scope='row'>", supported_method_label(method_name),
    "</th>",
    paste0(
      "<td>", fmt_pct(dat$`Pregnancy competing event (%)`), "%</td>",
      collapse = ""
    ),
    "</tr>"
  )
}, character(1))

overall_reinitiation_12 <- reinitiation$`Reinitiated (%)`[
  reinitiation$Method == "All methods" &
    reinitiation$Horizon == "12 months"
]
overall_reinitiation_1 <- reinitiation$`Reinitiated (%)`[
  reinitiation$Method == "All methods" &
    reinitiation$Horizon == "1 month"
]

# Month-by-month time to the next contraceptive start. These are cumulative
# incidence estimates, not the proportion restarting in the individual month.
reinitiation_months <- 1L:12L
reinitiation_month_labels <- paste0(
  reinitiation_months,
  ifelse(reinitiation_months == 1L, " month", " months")
)
stopifnot(all(reinitiation_month_labels %in% reinitiation_monthly$Horizon))

reinitiation_monthly_rows <- vapply(method_order, function(method_name) {
  dat <- reinitiation_monthly[reinitiation_monthly$Method == method_name,]
  dat <- dat[match(reinitiation_month_labels, dat$Horizon),]
  row_class <- if (method_name == "All methods") " total-row" else ""
  paste0(
    "<tr class='", row_class, "'><th scope='row'>",
    escape_html(method_name), "</th>",
    paste0("<td>", fmt_pct(dat$`Reinitiated (%)`), "%</td>", collapse = ""),
    "</tr>"
  )
}, character(1))

reinitiation_colors <- setNames(
  c("#0f766e", "#7c3aed", "#c66a14", "#b42318", "#64748b", "#243746"),
  method_order
)

reinitiation_curve_card <- function(method_name) {
  dat <- reinitiation_monthly[reinitiation_monthly$Method == method_name,]
  dat <- dat[match(reinitiation_month_labels, dat$Horizon),]
  values <- as.numeric(dat$`Reinitiated (%)`)
  y_max <- max(10, ceiling(max(values, na.rm = TRUE) / 10) * 10)
  x <- 48 + (reinitiation_months - 1) / 11 * 342
  y <- 20 + (1 - values / y_max) * 145
  points <- paste0(sprintf("%.1f,%.1f", x, y), collapse = " ")
  circles <- paste0(
    "<circle cx='", sprintf("%.1f", x), "' cy='", sprintf("%.1f", y),
    "' r='3.3'><title>By month ", reinitiation_months, ": ",
    fmt_pct(values), "% reinitiated</title></circle>",
    collapse = ""
  )
  x_ticks <- c(1L, 3L, 6L, 9L, 12L)
  x_tick_values <- 48 + (x_ticks - 1) / 11 * 342
  ticks <- paste0(
    "<text x='", sprintf("%.1f", x_tick_values),
    "' y='187' text-anchor='middle'>", x_ticks, "</text>",
    collapse = ""
  )
  color <- unname(reinitiation_colors[method_name])
  paste0(
    "<article class='hazard-card'><h4>", escape_html(method_name), "</h4>",
    "<svg viewBox='0 0 420 205' role='img' aria-label='Cumulative reinitiation after discontinuing ",
    escape_html(method_name), "'><line x1='48' y1='20' x2='48' y2='165'/>",
    "<line x1='48' y1='165' x2='390' y2='165'/>",
    "<line class='gridline' x1='48' y1='20' x2='390' y2='20'/>",
    "<text x='42' y='25' text-anchor='end'>", y_max, "%</text>",
    "<text x='42' y='169' text-anchor='end'>0%</text>", ticks,
    "<text x='219' y='202' text-anchor='middle'>Months since discontinuation</text>",
    "<polyline points='", points, "' style='stroke:", color, "'/>",
    "<g style='fill:", color, "'>", circles, "</g></svg></article>"
  )
}

reinitiation_curve_cards <- paste0(
  vapply(method_order, reinitiation_curve_card, character(1)),
  collapse = ""
)

# Section 8: post-discontinuation pathways. The transition matrix is a
# cumulative competing-risk partition at each milestone. Gap categories are
# increments of the reinitiation CIF, and effectiveness transitions compare
# the programmatic tier of the next method with the discontinued method.
transition_horizons <- c(1L, 3L, 6L, 9L, 12L)
transition_columns <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception",
  "Other modern", "Traditional method", "Pregnancy before reinitiation",
  "No observed event"
)
transition_labels <- c(
  "Injectable", "Implant", "Pill", "EC", "Other modern", "Traditional",
  "Pregnancy", "No event"
)

transition_table <- function(horizon) {
  dat <- transition_matrix[transition_matrix$Month == horizon,]
  dat <- dat[match(method_order, dat$`Discontinued method`),]
  rows <- vapply(seq_len(nrow(dat)), function(i) {
    values <- as.numeric(dat[i, transition_columns])
    cells <- paste0(
      "<td class='transition-cell' style='--cell-alpha:",
      sprintf("%.3f", pmin(0.72, 0.05 + values / 100 * 0.8)),
      "'>", fmt_pct(values), "%</td>", collapse = ""
    )
    row_class <- if (dat$`Discontinued method`[i] == "All methods")
      " total-row" else ""
    paste0(
      "<tr class='", row_class, "'><th scope='row'>",
      supported_method_label(dat$`Discontinued method`[i]), "</th>", cells, "</tr>"
    )
  }, character(1))
  paste0(
    "<div class='path-horizon-panel", if (horizon == 12L) " active" else "",
    "' id='path-horizon-", horizon, "'><div class='table-scroll'>",
    "<table class='pathway-table'><thead><tr><th>Discontinued method</th>",
    paste0("<th>", transition_labels, "</th>", collapse = ""),
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></div>"
  )
}
transition_tables <- paste0(
  vapply(transition_horizons, transition_table, character(1)),
  collapse = ""
)

destination_table <- function(horizon) {
  dat <- destination_conditional[destination_conditional$Month == horizon,]
  dat <- dat[match(method_order, dat$`Discontinued method`),]
  destination_only <- transition_columns[1:6]
  destination_only_labels <- transition_labels[1:6]
  rows <- vapply(seq_len(nrow(dat)), function(i) {
    values <- as.numeric(dat[i, destination_only])
    cells <- paste0(
      "<td class='transition-cell' style='--cell-alpha:",
      sprintf("%.3f", pmin(0.72, 0.05 + values / 100 * 0.8)),
      "'>", fmt_pct(values), "%</td>", collapse = ""
    )
    row_class <- if (dat$`Discontinued method`[i] == "All methods")
      " total-row" else ""
    paste0(
      "<tr class='", row_class, "'><th scope='row'>",
      supported_method_label(dat$`Discontinued method`[i]), "</th>", cells, "</tr>"
    )
  }, character(1))
  paste0(
    "<div class='destination-horizon-panel",
    if (horizon == 12L) " active" else "",
    "' id='destination-horizon-", horizon, "'><div class='table-scroll'>",
    "<table class='pathway-table'><thead><tr><th>Method discontinued</th>",
    paste0("<th>", destination_only_labels, "</th>", collapse = ""),
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></div>"
  )
}
destination_display_horizons <- c(3L, 6L, 9L, 12L)
destination_tables <- paste0(
  vapply(destination_display_horizons, destination_table, character(1)),
  collapse = ""
)

gap_columns <- c(
  "Next month", "Months 2-3", "Months 4-6", "Months 7-9",
  "Months 10-12", "Pregnancy before reinitiation",
  "No observed event by 12 months"
)
gap_labels <- c(
  "Next month", "Months 2-3", "Months 4-6", "Months 7-9",
  "Months 10-12", "Pregnancy", "No event"
)
gap_colors <- c(
  "#0f766e", "#2563a6", "#b7791f", "#7c3aed", "#b42318",
  "#64748b", "#243746"
)
effect_columns <- c(
  "Higher-effectiveness method", "Different method, same tier",
  "Same method restarted", "Lower-effectiveness method",
  "Pregnancy before reinitiation", "No observed event"
)
effect_labels <- c(
  "Higher effectiveness", "Different method, same tier", "Same method",
  "Lower effectiveness", "Pregnancy", "No event"
)
effect_colors <- c(
  "#0f766e", "#2563a6", "#b7791f", "#b42318", "#64748b", "#243746"
)

stacked_path_rows <- function(dat, value_columns, colors) {
  dat <- dat[match(method_order, dat$`Discontinued method`),]
  paste0(vapply(seq_len(nrow(dat)), function(i) {
    values <- as.numeric(dat[i, value_columns])
    segments <- paste0(vapply(seq_along(values), function(j) {
      label <- if (values[j] >= 7) paste0(fmt_pct(values[j]), "%") else ""
      paste0(
        "<span class='path-segment' style='width:",
        sprintf("%.4f", values[j]), "%;background:", colors[j],
        "' aria-label='", escape_html(value_columns[j]), ": ",
        fmt_pct(values[j]), " percent'>", label, "</span>"
      )
    }, character(1)), collapse = "")
    paste0(
      "<div class='path-bar-row'><strong>",
      supported_method_label(dat$`Discontinued method`[i]),
      "</strong><div class='path-stack'>", segments, "</div></div>"
    )
  }, character(1)), collapse = "")
}

path_legend <- function(labels, colors) {
  paste0(
    "<div class='path-legend'>",
    paste0(
      "<span><i style='background:", colors, "'></i>", labels, "</span>",
      collapse = ""
    ),
    "</div>"
  )
}

gap_bar_rows <- stacked_path_rows(gap_distribution, gap_columns, gap_colors)
gap_legend <- path_legend(gap_labels, gap_colors)
effect_12 <- effectiveness_transition[effectiveness_transition$Month == 12L,]
effect_bar_rows <- stacked_path_rows(effect_12, effect_columns, effect_colors)
effect_legend <- path_legend(effect_labels, effect_colors)

partition_table_rows <- function(dat, value_columns) {
  dat <- dat[match(method_order, dat$`Discontinued method`),]
  paste0(vapply(seq_len(nrow(dat)), function(i) {
    values <- as.numeric(dat[i, value_columns])
    row_class <- if (dat$`Discontinued method`[i] == "All methods")
      " total-row" else ""
    paste0(
      "<tr class='", row_class, "'><th scope='row'>",
      supported_method_label(dat$`Discontinued method`[i]), "</th>",
      paste0("<td>", fmt_pct(values), "%</td>", collapse = ""),
      "</tr>"
    )
  }, character(1)), collapse = "")
}

gap_table_rows <- partition_table_rows(gap_distribution, gap_columns)
effect_table_rows <- partition_table_rows(effect_12, effect_columns)

# The Section 10 table shows its row denominators and caution labels directly.
# These flags assess denominator support only; rare outcome cells can still be
# imprecise even when the overall method row is not flagged.
effect_table_rows <- paste0(vapply(seq_len(nrow(effect_12)), function(i) {
  method_name <- effect_12$`Discontinued method`[i]
  values <- as.numeric(effect_12[i, effect_columns])
  row_class <- if (method_name == "All methods") " total-row" else ""
  n <- unname(reinitiation_support[method_name])
  assessment <- support_assessment(method_name)
  assessment_class <- if (assessment == "No count-based flag" || assessment == "Overall") {
    ""
  } else {
    " class='caution-cell'"
  }
  paste0(
    "<tr class='", row_class, "'><th scope='row'>",
    supported_method_label(method_name), "</th>",
    paste0("<td>", fmt_pct(values), "%</td>", collapse = ""),
    "<td>", if (is.finite(n)) format(round(n), big.mark = ",") else "&mdash;", "</td>",
    "<td", assessment_class, ">", escape_html(assessment), "</td></tr>"
  )
}, character(1)), collapse = "")

modern_pathway_columns <- c(
  "Continued modern protection",
  "Temporary non-use then modern reinitiation",
  "Prolonged gap then modern reinitiation",
  "Traditional-method use",
  "Pregnancy first",
  "No reinitiation or pregnancy observed by 12 months"
)
modern_pathway_labels <- c(
  "Continued modern protection: next month<sup>1</sup>",
  "Temporary non-use: modern method in months 2&ndash;3<sup>2</sup>",
  "Prolonged gap: modern method in months 4&ndash;12<sup>3</sup>",
  "Traditional-method use<sup>4</sup>",
  "Pregnancy first<sup>5</sup>",
  "No restart observed by 12 months<sup>6</sup>"
)
modern_pathway_order <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception",
  "Other modern", "All modern methods"
)
modern_pathway_rows <- paste0(vapply(
  modern_pathway_order,
  function(method_name) {
    dat <- modern_protection_pathways[
      modern_protection_pathways$`Discontinued modern method` == method_name,
    ]
    if (nrow(dat) != 1L) {
      stop("Modern-protection pathway output has a missing or duplicate method row.")
    }
    values <- as.numeric(dat[1, modern_pathway_columns])
    row_class <- if (method_name == "All modern methods") " total-row" else ""
    display_name <- switch(
      method_name,
      "Other modern" = "Other modern methods",
      "All modern methods" = "All modern-method episodes",
      method_name
    )
    paste0(
      "<tr class='", row_class, "'><th scope='row'>",
      escape_html(display_name), "</th>",
      paste0("<td>", fmt_pct(values), "%</td>", collapse = ""),
      "<td><strong>100.0%</strong></td></tr>"
    )
  },
  character(1)
), collapse = "")

# Reason-linked post-discontinuation outcomes.
reason_outcome_columns <- c(
  "Reinitiated (%)", "Pregnancy before reinitiation (%)",
  "No observed event (%)"
)
reason_outcome_labels <- c(
  "Reinitiated contraception", "Pregnancy before reinitiation",
  "No observed event"
)
reason_outcome_slugs <- c("restart", "pregnancy", "no-event")
reason_outcome_rgb <- c("15,118,110", "180,35,24", "36,55,70")
reason_followup_horizons <- c(1L, 3L, 6L, 12L)

heat_cell <- function(value, rgb, suffix = "%", flag = "") {
  if (!is.finite(value)) return("<td class='suppressed-cell'>&mdash;</td>")
  alpha <- pmin(0.88, 0.08 + value / 100 * 0.88)
  color <- if (alpha > 0.52) "#ffffff" else "#1f2933"
  paste0(
    "<td class='outcome-heat-cell' style='background:rgba(", rgb, ",",
    sprintf("%.3f", alpha), ");color:", color, "'>",
    fmt_pct(value), suffix, flag, "</td>"
  )
}

reason_heatmap_card <- function(outcome_index) {
  outcome <- reason_outcome_columns[outcome_index]
  rows <- vapply(reason_columns, function(reason_name) {
    dat <- reason_outcomes[reason_outcomes$Reason == reason_name, ]
    dat <- dat[match(reason_followup_horizons, dat$Month), ]
    n <- unique(dat$`Eligible episodes (unweighted)`)
    flag <- if (length(n) == 1L && n < 25) "&#8225;" else
      if (length(n) == 1L && n < 50) "&#8224;" else ""
    paste0(
      "<tr><th scope='row'>", escape_html(reason_name), "</th>",
      paste0(vapply(dat[[outcome]], function(value) {
        heat_cell(value, reason_outcome_rgb[outcome_index], flag = flag)
      }, character(1)), collapse = ""), "</tr>"
    )
  }, character(1))
  paste0(
    "<article class='reason-heatmap-card'><h3>",
    escape_html(reason_outcome_labels[outcome_index]), "</h3>",
    "<div class='table-scroll'><table><thead><tr><th>Reason</th>",
    paste0("<th>", reason_followup_horizons, "m</th>", collapse = ""),
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></article>"
  )
}
reason_heatmaps <- paste0(
  vapply(seq_along(reason_outcome_columns), reason_heatmap_card, character(1)),
  collapse = ""
)

reason_exact_rows <- vapply(reason_columns, function(reason_name) {
  dat <- reason_outcomes[reason_outcomes$Reason == reason_name, ]
  dat <- dat[match(reason_followup_horizons, dat$Month), ]
  cells <- paste0(vapply(seq_len(nrow(dat)), function(i) {
    paste0(
      "<td>", fmt_pct(dat$`Reinitiated (%)`[i]), "%</td>",
      "<td>", fmt_pct(dat$`Pregnancy before reinitiation (%)`[i]), "%</td>",
      "<td>", fmt_pct(dat$`No observed event (%)`[i]), "%</td>"
    )
  }, character(1)), collapse = "")
  paste0(
    "<tr><th scope='row'>", escape_html(reason_name), "</th>", cells,
    "<td>", fmt_n(dat$`Eligible episodes (weighted)`[1]), "</td>",
    "<td>", dat$`Eligible episodes (unweighted)`[1], "</td></tr>"
  )
}, character(1))

method_reason_panel <- function(outcome_index, horizon) {
  outcome <- reason_outcome_columns[outcome_index]
  dat_h <- reason_method_outcomes[reason_method_outcomes$Month == horizon, ]
  rows <- vapply(method_detail_order, function(method_name) {
    cells <- vapply(reason_columns, function(reason_name) {
      cell <- dat_h[
        dat_h$`Discontinued method` == method_name &
          dat_h$Reason == reason_name,
      ]
      if (nrow(cell) == 0L || cell$`Eligible episodes (unweighted)`[1] < 25L) {
        return("<td class='suppressed-cell' title='Fewer than 25 eligible episodes'>&mdash;</td>")
      }
      flag <- if (cell$`Eligible episodes (unweighted)`[1] < 50L) "&#8224;" else ""
      heat_cell(cell[[outcome]][1], reason_outcome_rgb[outcome_index], flag = flag)
    }, character(1))
    paste0(
      "<tr><th scope='row'>", escape_html(method_name), "</th>",
      paste0(cells, collapse = ""), "</tr>"
    )
  }, character(1))
  paste0(
    "<div class='method-reason-panel",
    if (outcome_index == 1L && horizon == 12L) " active" else "",
    "' id='method-reason-", reason_outcome_slugs[outcome_index], "-", horizon,
    "'><div class='table-scroll'><table class='method-reason-table'><thead><tr>",
    "<th>Previous method</th>",
    paste0("<th>", reason_labels, "</th>", collapse = ""),
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></div>"
  )
}
method_reason_panels <- paste0(
  unlist(lapply(seq_along(reason_outcome_columns), function(outcome_index) {
    vapply(reason_followup_horizons, function(horizon) {
      method_reason_panel(outcome_index, horizon)
    }, character(1))
  })),
  collapse = ""
)

# Monthly all-cause hazard table and small-multiple hazard curves.
month_columns <- 1L:12L
monthly_hazard_rows <- vapply(method_order, function(method_name) {
  dat <- monthly_all_hazard[monthly_all_hazard$Method == method_name,]
  dat <- dat[match(month_columns, dat$Month),]
  row_class <- if (method_name == "All methods") " total-row" else ""
  paste0(
    "<tr class='", row_class, "'><th scope='row'>", escape_html(method_name),
    "</th>",
    paste0(
      "<td>", fmt_pct(dat$`All-cause monthly hazard (%)`), "%</td>",
      collapse = ""
    ),
    "</tr>"
  )
}, character(1))

hazard_colors <- setNames(
  c("#0f766e", "#7c3aed", "#c66a14", "#b42318", "#64748b", "#243746"),
  method_order
)

hazard_curve_card <- function(method_name) {
  dat <- monthly_all_hazard[monthly_all_hazard$Method == method_name,]
  dat <- dat[match(month_columns, dat$Month),]
  values <- as.numeric(dat$`All-cause monthly hazard (%)`)
  y_max <- max(1, ceiling(max(values, na.rm = TRUE) * 1.12))
  x <- 48 + (month_columns - 1) / 11 * 342
  y <- 20 + (1 - values / y_max) * 145
  points <- paste0(sprintf("%.1f,%.1f", x, y), collapse = " ")
  circles <- paste0(
    "<circle cx='", sprintf("%.1f", x), "' cy='", sprintf("%.1f", y),
    "' r='3.3'><title>Month ", month_columns, ": ", fmt_pct(values),
    "%</title></circle>",
    collapse = ""
  )
  x_ticks <- c(1L, 3L, 6L, 9L, 12L)
  x_tick_values <- 48 + (x_ticks - 1) / 11 * 342
  ticks <- paste0(
    "<text x='", sprintf("%.1f", x_tick_values),
    "' y='187' text-anchor='middle'>", x_ticks, "</text>",
    collapse = ""
  )
  color <- unname(hazard_colors[method_name])
  paste0(
    "<article class='hazard-card'><h4>", escape_html(method_name), "</h4>",
    "<svg viewBox='0 0 420 205' role='img' aria-label='Monthly discontinuation hazard for ",
    escape_html(method_name), "'><line x1='48' y1='20' x2='48' y2='165'/>",
    "<line x1='48' y1='165' x2='390' y2='165'/>",
    "<line class='gridline' x1='48' y1='20' x2='390' y2='20'/>",
    "<text x='42' y='25' text-anchor='end'>", y_max, "%</text>",
    "<text x='42' y='169' text-anchor='end'>0%</text>", ticks,
    "<text x='219' y='202' text-anchor='middle'>Month since initiation</text>",
    "<polyline points='", points, "' style='stroke:", color, "'/>",
    "<g style='fill:", color, "'>", circles, "</g></svg></article>"
  )
}

hazard_curve_cards <- paste0(
  vapply(method_order, hazard_curve_card, character(1)),
  collapse = ""
)

# Cause-specific monthly hazard heatmaps. Each method receives its own table;
# color intensity is scaled within that method to preserve visibility.
cause_hazard_card <- function(method_name) {
  dat <- monthly_cause_hazard[monthly_cause_hazard$Method == method_name,]
  max_value <- max(dat$`Cause-specific monthly hazard (%)`, na.rm = TRUE)
  rows <- vapply(reason_columns, function(reason_name) {
    reason_dat <- dat[dat$Reason == reason_name,]
    reason_dat <- reason_dat[match(month_columns, reason_dat$Month),]
    values <- as.numeric(reason_dat$`Cause-specific monthly hazard (%)`)
    cells <- vapply(values, function(value) {
      intensity <- if (max_value > 0) value / max_value else 0
      alpha <- 0.07 + 0.82 * intensity
      text_color <- if (alpha > 0.53) "#ffffff" else "#1f2933"
      paste0(
        "<td style='background:rgba(15,118,110,", sprintf("%.3f", alpha),
        ");color:", text_color, "'>", fmt_pct(value), "%</td>"
      )
    }, character(1))
    paste0(
      "<tr><th scope='row'>", escape_html(reason_name), "</th>",
      paste0(cells, collapse = ""), "</tr>"
    )
  }, character(1))
  paste0(
    "<details class='distribution-layout'><summary>",
    escape_html(method_name), " monthly cause-specific hazards</summary>",
    "<div class='table-scroll'><table class='heatmap-table'><thead><tr><th>Reason</th>",
    paste0("<th>M", month_columns, "</th>", collapse = ""),
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></details>"
  )
}

cause_hazard_cards <- paste0(
  vapply(method_order, cause_hazard_card, character(1)),
  collapse = ""
)

reason_timing_card <- function(method_name) {
  dat <- reason_timing[reason_timing$Method == method_name,]
  dat <- dat[match(reason_columns, dat$Reason),]
  rows <- vapply(seq_len(nrow(dat)), function(i) {
    paste0(
      "<tr><th scope='row'>", escape_html(dat$Reason[i]), "</th>",
      "<td>", fmt_pct(dat$`12-month cause-specific cumulative incidence (%)`[i]), "%</td>",
      "<td>", fmt_pct(dat$`Accumulated by month 3 (%)`[i]), "%</td>",
      "<td>", fmt_pct(dat$`Accumulated by month 6 (%)`[i]), "%</td>",
      "<td>", fmt_pct(dat$`Accumulated by month 9 (%)`[i]), "%</td></tr>"
    )
  }, character(1))
  paste0(
    "<article class='method-card'><h3>", escape_html(method_name), "</h3>",
    "<div class='table-scroll'><table class='matrix-table timing-table'><thead><tr>",
    "<th>Reason</th><th>12-month CIF</th><th>By M3</th><th>By M6</th><th>By M9</th>",
    "</tr></thead><tbody>", paste0(rows, collapse = ""),
    "</tbody></table></div></article>"
  )
}

reason_timing_cards <- paste0(
  vapply(method_order, reason_timing_card, character(1)),
  collapse = ""
)

html <- paste0(
"<!doctype html><html lang='en'><head><meta charset='utf-8'>",
"<meta name='viewport' content='width=device-width,initial-scale=1'>",
"<title>Ethiopia contraceptive discontinuation</title><style>",
":root{--ink:#1f2933;--muted:#667085;--paper:#fff;--wash:#f5f3ee;--line:#ded8cc;--teal:#0f766e;--teal2:#dff4ef;--gold:#b7791f;--navy:#243746}",
"*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--wash);color:var(--ink);font-family:Arial,Helvetica,sans-serif;line-height:1.45}",
"header{background:var(--navy);color:#fff;padding:44px max(24px,calc((100% - 1460px)/2));border-bottom:5px solid #d2a84a}",
"header .eyebrow{color:#d9e7e8}h1{font-family:Georgia,serif;font-size:clamp(32px,5vw,54px);line-height:1.05;margin:8px 0 14px}header p{max-width:850px;margin:0;color:#e7eef0;font-size:17px}",
"nav{position:sticky;top:0;z-index:10;background:#fff;border-bottom:1px solid var(--line);padding:0 max(20px,calc((100% - 1460px)/2));display:flex;gap:8px;overflow:auto}",
"nav a{color:var(--ink);font-weight:700;text-decoration:none;padding:15px 14px;white-space:nowrap;border-bottom:3px solid transparent}nav a:hover,nav a:focus{color:var(--teal);border-color:var(--teal)}",
"main{max-width:1460px;margin:0 auto;padding:26px 20px 60px}.report-section{background:var(--paper);border:1px solid var(--line);border-radius:12px;margin:0 0 24px;padding:28px;box-shadow:0 3px 14px rgba(31,41,51,.05)}",
".section-number,.eyebrow{margin:0;color:var(--teal);font-size:12px;font-weight:800;letter-spacing:.14em;text-transform:uppercase}.section-head{display:flex;align-items:end;justify-content:space-between;gap:20px;margin-bottom:20px}.section-head h2{font-family:Georgia,serif;font-size:30px;margin:5px 0 0}.section-head>p{max-width:620px;color:var(--muted);margin:0}",
".table-scroll{overflow:auto;border:1px solid var(--line);border-radius:9px}table{border-collapse:separate;border-spacing:0;width:100%;font-size:14px}th,td{padding:11px 12px;border-right:1px solid #e9e5dc;border-bottom:1px solid #e9e5dc;text-align:right;vertical-align:top}thead th{background:#eef2f1;color:#344054;font-size:12px;text-align:center;vertical-align:middle}tbody th{text-align:left;background:#faf9f6;white-space:nowrap}tr:last-child>*{border-bottom:0}tr>*:last-child{border-right:0}.total-row>*{font-weight:800;background:#eaf5f2}.value-pill{display:inline-block;min-width:58px;padding:5px 8px;border-radius:999px;background:var(--teal2);color:#115e59;font-weight:800}.note{color:var(--muted);font-size:13px;margin:13px 0 0}",
".reason-list{list-style-position:inside;margin:0;padding:0;min-width:210px}.reason-list li{display:flex;justify-content:space-between;gap:9px;margin-bottom:5px;font-size:12px;text-align:left}.reason-list span{color:var(--teal);font-weight:800;white-space:nowrap}",
".method-table-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}.method-card{border:1px solid var(--line);border-radius:10px;overflow:hidden;background:#fff}.method-card h3{font-family:Georgia,serif;font-size:22px;margin:0;padding:16px 18px;background:#f7f6f2;border-bottom:1px solid var(--line)}.method-card:last-child:nth-child(odd){grid-column:1/-1}.matrix-table{font-size:12px}.matrix-table th,.matrix-table td{padding:8px 9px}.matrix-table thead th:first-child{min-width:220px;text-align:left}.matrix-table tbody th{white-space:normal;min-width:220px}.matrix-table td{white-space:nowrap}",
".definition-box{display:grid;grid-template-columns:1fr 1fr;gap:18px;background:#f2f8f7;border:1px solid #cfe5e1;border-left:5px solid var(--teal);border-radius:9px;padding:18px 20px;margin:0 0 22px}.definition-box h3{font-family:Georgia,serif;font-size:20px;margin:0 0 8px}.definition-box p{margin:5px 0;color:#344054}.formula{font-weight:800;color:#115e59!important;background:#fff;border:1px solid #dce9e6;border-radius:7px;padding:10px 12px}.subsection-title{font-family:Georgia,serif;font-size:24px;margin:28px 0 5px}.subsection-intro{color:var(--muted);margin:0 0 14px}.distribution-layout{border:1px solid var(--line);border-radius:9px;margin:0 0 12px;background:#fff;overflow:hidden}.distribution-layout summary{cursor:pointer;font-weight:800;padding:14px 16px;background:#f7f6f2}.distribution-layout[open] summary{border-bottom:1px solid var(--line)}.distribution-wide{min-width:1390px}.total-share{background:#eaf5f2;font-weight:800}",
".section-explanation{display:grid;grid-template-columns:1fr 1fr;gap:22px;background:#f8fafb;border:1px solid #d7e0e5;border-top:4px solid var(--navy);border-radius:9px;padding:20px 22px;margin:0 0 24px}.section-explanation h3{font-family:Georgia,serif;font-size:18px;margin:0 0 5px;color:var(--navy)}.section-explanation h3:not(:first-child){margin-top:16px}.section-explanation p{font-size:15px;line-height:1.58;margin:0;color:#344054}.table-guide{border:1px solid #d9dfe3;border-radius:8px;margin:10px 0 22px;background:#fbfcfd;overflow:hidden}.table-guide summary{cursor:pointer;padding:12px 15px;background:#eef2f4;color:var(--navy);font-size:14px;font-weight:800}.table-guide[open] summary{border-bottom:1px solid #d9dfe3}.table-guide-grid{display:grid;grid-template-columns:1fr 1fr 1.15fr;gap:22px;padding:17px 18px}.table-guide h4{margin:0 0 4px;color:#344054;font-size:14px}.table-guide h4:not(:first-child){margin-top:13px}.table-guide p{margin:0;color:#475467;font-size:14px;line-height:1.52}",
".table-equivalence-note{background:#fff8e8;border:1px solid #ead7a5;border-left:5px solid var(--gold);border-radius:9px;padding:14px 16px;margin:0 0 16px;color:#4f4329}.table-equivalence-note strong{color:#3d3420}",
".method-footnote{background:#f7f8fa;border-top:1px solid var(--line);margin:18px 0 0;padding:13px 15px;color:#475467;font-size:13px;border-radius:0 0 8px 8px}.method-footnote strong{color:#243746}.other-category-note{color:#667085;font-size:12px;line-height:1.45;margin:7px 2px 15px}.other-category-note strong{color:#475467}.hazard-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.hazard-card{border:1px solid var(--line);border-radius:9px;padding:12px;background:#fff}.hazard-card h4{font-family:Georgia,serif;font-size:19px;margin:0 0 4px}.hazard-card svg{width:100%;height:auto}.hazard-card svg line{stroke:#98a2b3;stroke-width:1}.hazard-card svg .gridline{stroke:#e4e7ec}.hazard-card svg polyline{fill:none;stroke-width:3;stroke-linejoin:round;stroke-linecap:round}.hazard-card svg text{font-size:10px;fill:#667085}.heatmap-table{min-width:1420px;font-size:11px}.heatmap-table tbody th{min-width:240px;white-space:normal}.heatmap-table td{font-weight:700;text-align:center}.timing-table thead th:first-child{min-width:235px}.path-tabs{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 18px;border-bottom:1px solid var(--line)}.path-tab-button{border:0;border-bottom:3px solid transparent;background:#fff;color:#667085;padding:11px 13px;font-weight:800;cursor:pointer}.path-tab-button.active,.path-tab-button:hover,.path-tab-button:focus{color:var(--teal);border-color:var(--teal)}.path-panel,.path-horizon-panel,.destination-horizon-panel{display:none}.path-panel.active,.path-horizon-panel.active,.destination-horizon-panel.active{display:block}.path-toolbar{display:flex;justify-content:space-between;align-items:end;gap:14px;margin:0 0 13px}.path-toolbar h3{font-family:Georgia,serif;font-size:24px;margin:0}.path-toolbar label{font-size:12px;color:#667085;font-weight:700}.path-toolbar select{margin-left:6px;padding:7px 28px 7px 9px;border:1px solid var(--line);border-radius:6px;background:#fff;color:var(--ink)}.pathway-table{min-width:1120px}.transition-cell{background:rgba(15,118,110,var(--cell-alpha));font-weight:700}.path-bars{display:grid;gap:13px}.path-bar-row{display:grid;grid-template-columns:190px 1fr;gap:12px;align-items:center}.path-bar-row>strong{font-size:13px}.path-stack{height:30px;display:flex;background:#eef2f1;overflow:hidden;border-radius:4px}.path-segment{display:flex;align-items:center;justify-content:center;color:#fff;font-size:11px;font-weight:800;white-space:nowrap;overflow:hidden}.path-legend{display:flex;flex-wrap:wrap;gap:8px 16px;margin:14px 0;color:#667085;font-size:12px}.path-legend span{display:inline-flex;align-items:center;gap:6px}.path-legend i{display:inline-block;width:11px;height:11px}",
".tabs{display:flex;gap:8px;flex-wrap:wrap;margin:0 0 16px}.tab-button{border:1px solid var(--line);background:#fff;color:var(--ink);border-radius:999px;padding:9px 16px;font-weight:800;cursor:pointer}.tab-button.active,.tab-button:hover,.tab-button:focus{background:var(--navy);border-color:var(--navy);color:#fff}.duration-panel{display:none}.duration-panel.active{display:block}.panel-heading{display:flex;align-items:end;justify-content:space-between;margin:0 0 10px;gap:20px}.panel-heading h3{font-family:Georgia,serif;font-size:27px;margin:3px 0}.panel-heading>p{color:var(--muted);margin:0}.reason-table{min-width:1480px}.reason-table .any-reason{background:#fff7df;font-weight:800}",
".reason-heatmap-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:15px}.reason-heatmap-card{border:1px solid var(--line);border-radius:9px;overflow:hidden}.reason-heatmap-card h3{font-family:Georgia,serif;font-size:19px;margin:0;padding:13px 14px;background:#f7f6f2}.reason-heatmap-card table{font-size:11px}.reason-heatmap-card tbody th{white-space:normal;min-width:170px}.outcome-heat-cell{font-weight:800;text-align:center}.suppressed-cell{background:#f2f4f7!important;color:#98a2b3!important;text-align:center;font-weight:700}.caution-cell{background:#fff4dc;color:#7a4b00;font-weight:800;text-align:left}.method-reason-panel{display:none}.method-reason-panel.active{display:block}.method-reason-table{min-width:1500px;font-size:11px}.method-reason-table tbody th{min-width:180px}.method-reason-table thead th{min-width:125px}.outcome-controls{display:flex;gap:18px;align-items:end;flex-wrap:wrap;margin:0 0 14px;padding:14px 16px;border:1px solid var(--line);border-radius:8px;background:#faf9f6}.outcome-controls label{display:grid;gap:5px;color:#667085;font-size:12px;font-weight:800}.outcome-controls select{min-width:215px;padding:8px 30px 8px 10px;border:1px solid var(--line);border-radius:6px;background:#fff;color:var(--ink)}",
"footer{max-width:1460px;margin:0 auto 40px;padding:0 20px;color:var(--muted);font-size:12px}@media(max-width:1100px){.reason-heatmap-grid,.table-guide-grid{grid-template-columns:1fr}}@media(max-width:900px){.method-table-grid,.definition-box,.hazard-grid,.section-explanation{grid-template-columns:1fr}.method-card:last-child:nth-child(odd){grid-column:auto}}@media(max-width:800px){header{padding-top:30px;padding-bottom:30px}.report-section{padding:20px}.section-head,.panel-heading,.path-toolbar{display:block}.section-head>p,.panel-heading>p{margin-top:8px}.path-toolbar label{display:block;margin-top:8px}th,td{padding:9px}.reason-list{min-width:190px}.path-bar-row{grid-template-columns:1fr;gap:5px}}",
"</style></head><body><header><p class='eyebrow'>Ethiopia DHS 2024-25</p>",
"<h1>Contraceptive discontinuation over time</h1>",
"<p>Weighted life-table estimates at 3, 6, 9, and 12 months, using the DHS aggregate method categories and a competing-risk framework for discontinuation reasons.</p></header>",
"<nav aria-label='Report sections'><a href='#initiation'>01 Initiation</a><a href='#all-cause'>02 All-cause</a><a href='#predominance'>03 Main reasons</a><a href='#dhs-tables'>04 DHS-format tables</a><a href='#method-incidence'>05 Method incidence</a><a href='#reason-distribution'>06 Reason distribution</a><a href='#reinitiation'>07 Reinitiation</a><a href='#destinations'>08 Destinations</a><a href='#gaps'>09 Gaps</a><a href='#effectiveness'>10 Effectiveness</a><a href='#reason-outcomes'>11 Reason outcomes</a><a href='#method-reason-outcomes'>12 Method &times; reason</a><a href='#calendar-validation'>13 Calendar validation</a></nav><main>",
"<section class='report-section' id='initiation'><div class='section-head'><div><p class='section-number'>Section 01</p><h2>Observed method initiation and dynamic method mix</h2></div><p>Which contraceptive methods were started during the calendar period, their relative mix, and how frequently starts occurred over observed calendar time.</p></div>",
section_intro$initiation,
"<h3 class='subsection-title'>Annual calendar-based contraceptive use</h3><p class='subsection-intro'>Average monthly prevalence across the valid calendar woman-months observed in each year. Survey-question values are shown only for an overlapping interview year because v312 is measured once at interview and does not provide historical annual estimates.</p>",
"<div class='table-scroll'><table><thead><tr><th>Calendar year</th><th>Any use: calendar annual average</th><th>Modern use: calendar annual average</th><th>Any current use: v312 at interview</th><th>Modern current use: survey at interview</th><th>Weighted observed woman-months</th><th>Coverage</th></tr></thead><tbody>",
paste0(annual_use_rows, collapse = ""), "</tbody></table></div>", reading_guide$annual_use,
"<div class='definition-box'><div><h3>Initiation mix</h3><p>Describes the composition of all observed contraceptive episode starts. It answers: Of the methods that were started, what share corresponded to each method?</p><p class='formula'>Method mix (%) = weighted starts of a method / weighted starts of all methods x 100</p></div><div><h3>Initiation rate</h3><p>Describes how frequently observed method-start episodes occurred during calendar follow-up. Unlike the mix, the rate has observed calendar woman-time in its denominator.</p><p class='formula'>Initiation rate = weighted observed starts / weighted observed calendar woman-months x 1,000</p></div></div>",
"<h3 class='subsection-title'>Initiation mix and initiation rate</h3><p class='subsection-intro'>The mix describes the composition of starts; the rate describes their frequency. One woman may contribute more than one observed start.</p>",
"<div class='table-scroll'><table><thead><tr><th>Method started</th><th>Weighted observed starts</th><th>Share of observed starts</th><th>Starts per 1,000 observed calendar woman-months</th></tr></thead><tbody>",
paste0(initiation_mix_rows, collapse = ""), "</tbody></table></div>", reading_guide$initiation_mix,
"<h3 class='subsection-title'>Initiation mix and discontinuation over time</h3><p class='subsection-intro'>A method-level comparison of which methods account for observed starts and how quickly method-use episodes are discontinued.</p>",
"<div class='table-scroll'><table><thead><tr><th>Method</th><th>Share of observed episode starts</th><th>Discontinued by 3 months</th><th>Discontinued by 6 months</th><th>Discontinued by 9 months</th><th>Discontinued by 12 months</th></tr></thead><tbody>",
paste0(initiation_discontinuation_rows, collapse = ""),
"</tbody></table></div>", reading_guide$initiation_discontinuation,
"<div class='table-equivalence-note'><strong>Different denominators:</strong> Initiation mix uses method episodes whose starts are observed within the calendar analysis period; episodes already underway when the calendar began cannot be counted as starts. Discontinuation percentages are weighted life-table probabilities among eligible method-use episodes at risk. That risk set includes episodes that discontinue and episodes that continue or are censored. Episodes beginning before the 62-month analysis boundary may contribute through delayed entry when they remain in use into the window, but episodes already ongoing at the oldest calendar boundary are excluded. The two measures are complementary method-level summaries and should not be read as a single cohort fraction.</div>",
"<h3 class='subsection-title'>Method initiation mix by calendar year</h3><p class='subsection-intro'>Rows are the method categories used in the discontinuation analysis. Each year column is the percentage distribution of observed starts and sums to 100% before rounding.</p>",
"<div class='table-scroll'><table><thead><tr><th>Method started</th>",
paste0("<th>", annual_initiation_years, "</th>", collapse = ""),
"</tr></thead><tbody>",
paste0(annual_mix_wide_rows, collapse = ""), "</tbody></table></div>", reading_guide$annual_mix_wide,
"<div class='method-footnote'><strong>Statistical method:</strong> annual use is a survey-weighted ratio of contraceptive-use woman-months to all valid observed woman-months; initiation outputs are survey-weighted descriptive episode-start counts, shares, and incidence density. No life table or regression model is used for these measures. <strong>Annual-use numerator:</strong> weighted use-coded woman-months. <strong>Annual-use denominator:</strong> all valid observed woman-months in the year. <strong>Initiation numerator:</strong> weighted observed starts for the displayed method. <strong>Initiation denominator:</strong> all weighted observed starts for method mix, or weighted observed calendar woman-months for the initiation rate. <strong>Programmatic relevance:</strong> distinguishes the level of use, the mix of methods being started, and continuity after initiation. Only starts with an observed preceding state are included; first and last calendar years have partial respondent coverage.</div></section>",
"<section class='report-section' id='all-cause'><div class='section-head'><div><p class='section-number'>Section 02</p><h2>Discontinuation at 3, 6, 9, and 12 months</h2></div><p>The cumulative percentage of episodes discontinued for any reason by each duration.</p></div>",
section_intro$all_cause,
"<div class='table-equivalence-note'><strong>Which episodes are included?</strong> The primary results show <strong>overall all-cause discontinuation in the DHS-style eligible episode population</strong>, not only discontinuation among episodes that started inside the 3&ndash;62-month analysis window. The life table includes eligible episodes observed at risk during that window, including delayed-entry episodes that started earlier within the recorded calendar and continued into the window. Episodes already in progress at the oldest recorded calendar boundary are excluded because their true start and duration are unknown. Section 14 separately reports the narrower sensitivity analysis restricted to episodes whose starts and immediately preceding calendar states are observed inside the analysis period.</div>",
"<div class='table-scroll'><table><thead><tr><th>Method</th>",
paste0("<th>", horizon_order, "</th>", collapse = ""),
"<th>Weighted episodes</th></tr></thead><tbody>", paste0(all_cause_rows, collapse = ""),
"</tbody></table></div>", reading_guide$all_cause,
"<h3 class='subsection-title'>Monthly all-cause discontinuation hazard</h3><p class='subsection-intro'>The conditional probability of stopping during each month among episodes still at risk at the beginning of that month.</p>",
"<div class='table-scroll'><table class='heatmap-table'><thead><tr><th>Method</th>",
paste0("<th>M", month_columns, "</th>", collapse = ""),
"</tr></thead><tbody>", paste0(monthly_hazard_rows, collapse = ""),
"</tbody></table></div>", reading_guide$monthly_hazard,
"<h3 class='subsection-title'>Monthly hazard curves</h3><p class='subsection-intro'>Peaks identify months when stopping risk is relatively elevated for that method. Each panel has its own vertical scale; use the table above for comparisons across methods.</p>",
"<div class='hazard-grid'>", hazard_curve_cards, "</div>", reading_guide$monthly_hazard,
"<div class='method-footnote'><strong>Statistical method:</strong> weighted discrete-time life table; these are nonparametric estimates, not fitted regression hazards. <strong>Numerator:</strong> weighted all-cause discontinuations in month t. <strong>Denominator:</strong> weighted episodes still at risk at the start of month t. Cumulative discontinuation is 1 minus survival. <strong>Programmatic relevance:</strong> identifies methods and months where continuation support, anticipatory counseling, or follow-up may be most useful.</div></section>",
"<section class='report-section' id='predominance'><div class='section-head'><div><p class='section-number'>Section 03</p><h2>Main reasons at each time point</h2></div><p>The three largest cause-specific cumulative incidences for every method and duration.</p></div>",
section_intro$predominance,
"<div class='table-scroll'><table><thead><tr><th>Method</th>",
paste0("<th>", horizon_order, "</th>", collapse = ""),
"</tr></thead><tbody>", paste0(predominance_rows, collapse = ""),
"</tbody></table></div>", reading_guide$leading_reasons,
"<div class='method-footnote'><strong>Statistical method:</strong> weighted Aalen-Johansen competing-risk cumulative incidence, ranked within each method and horizon. <strong>Numerator contribution:</strong> weighted discontinuations for the specified reason in month t. <strong>Denominator:</strong> weighted episodes still at risk of any discontinuation at the start of month t. <strong>Programmatic relevance:</strong> identifies the most prominent drivers to prioritize for counseling, method choice, side-effect support, or access interventions. These are not shares among discontinuers; switching is excluded because it can overlap with a reason.</div></section>",
"<section class='report-section' id='dhs-tables'><div class='section-head'><div><p class='section-number'>Section 04</p><h2>Discontinuation by reason and method</h2></div><p>Each duration uses the same method categories and column structure as DHS Table 7.11.</p></div>",
section_intro$dhs,
"<div class='table-equivalence-note'><strong>Equivalent of DHS Table 7.11:</strong> This section reproduces the 12-month Table 7.11 structure used earlier and extends the same method categories, reason definitions, weighting, and competing-risk life-table approach to 3, 6, and 9 months. The DHS report publishes the 12-month table; the earlier horizons are corresponding estimates reconstructed from the public-use calendar data.</div>",
"<div class='tabs' role='tablist'>",
paste0("<button class='tab-button", ifelse(seq_along(horizon_order)==1," active",""), "' data-panel='duration-", seq_along(horizon_order), "'>", horizon_order, "</button>", collapse=""),
"</div>", full_tables, reading_guide$dhs_reason,
"<div class='method-footnote'><strong>Statistical method:</strong> weighted Aalen-Johansen competing-risk life table. <strong>Numerator contribution:</strong> weighted discontinuations for each mutually exclusive reason in month t. <strong>Denominator:</strong> weighted episodes still at risk of discontinuation at the start of month t. <strong>Programmatic relevance:</strong> compares the absolute first-year probability of different discontinuation reasons across method categories. The reason columns sum to Any reason; switching is separate and must not be added. DHS publishes the 12-month table; earlier horizons are parallel reconstructions.</div></section>",
"<section class='report-section' id='method-incidence'><div class='section-head'><div><p class='section-number'>Section 05</p><h2>Cumulative incidence by method and reason</h2></div><p>Within each method, rows are competing reasons and columns show the cumulative incidence by 3, 6, 9, and 12 months.</p></div>",
section_intro$method_incidence,
"<div class='method-table-grid'>", cumulative_cards, "</div>", reading_guide$reason_cif,
"<h3 class='subsection-title'>Monthly cause-specific hazards</h3><p class='subsection-intro'>Open a method to see the probability of discontinuing for each reason during each month among episodes still at risk. Darker cells mark higher hazards within that method.</p>",
cause_hazard_cards, reading_guide$cause_hazard,
"<h3 class='subsection-title'>When do reason-specific discontinuations accumulate?</h3><p class='subsection-intro'>For every method and reason, these tables show the percentage of the 12-month cause-specific cumulative incidence already accumulated by months 3, 6, and 9.</p>",
"<div class='method-table-grid'>", reason_timing_cards, "</div>", reading_guide$reason_timing,
"<div class='method-footnote'><strong>Statistical method:</strong> weighted Aalen-Johansen cumulative incidence and nonparametric monthly cause-specific hazards. <strong>Numerator:</strong> weighted events for the selected cause and month; timing-share numerators are that cause's CIF by month 3, 6, or 9. <strong>Denominator:</strong> the all-cause risk set for monthly hazards and the same cause's 12-month CIF for timing shares. <strong>Programmatic relevance:</strong> shows which reasons dominate, when they emerge, and whether support must occur early or throughout the first year.</div></section>",
"<section class='report-section' id='reason-distribution'><div class='section-head'><div><p class='section-number'>Section 06</p><h2>Distribution of reasons among discontinued episodes</h2></div><p>For each method and duration, each reason's cumulative incidence is divided by cumulative discontinuation for any reason.</p></div>",
section_intro$reason_distribution,
"<div class='definition-box'><div><h3>What does this percentage show?</h3><p><strong>Numerator:</strong> the weighted competing-risk cumulative incidence of discontinuation for one specified reason by the selected month.</p><p><strong>Denominator:</strong> the weighted cumulative incidence of discontinuation for any reason for the same method and month.</p><p class='formula'>Reason distribution (%) = reason-specific cumulative incidence / any-reason cumulative incidence x 100</p></div>",
"<div><h3>Example: injectables at 12 months</h3><p>", fmt_pct(example_numerator), "% discontinued because the woman desired pregnancy, while ", fmt_pct(example_denominator), "% discontinued for any reason.</p><p class='formula'>", fmt_pct(example_numerator), " / ", fmt_pct(example_denominator), " x 100 = ", fmt_pct(example_share), "%</p><p>Therefore, wanting pregnancy accounts for approximately ", fmt_pct(example_share), "% of estimated injectable discontinuations occurring by 12 months.</p></div></div>",
"<h3 class='subsection-title'>View by method</h3><p class='subsection-intro'>One method per table, with time points in columns.</p>",
"<div class='method-table-grid'>", distribution_cards, "</div>", reading_guide$reason_distribution,
"<h3 class='subsection-title'>View by time point</h3><p class='subsection-intro'>The same estimates reorganized with methods in rows and reasons in columns. These tables are mathematically equivalent to the method tables above.</p>",
distribution_horizon_tables, reading_guide$reason_distribution,
"<div class='method-footnote'><strong>Statistical method:</strong> ratio of weighted cause-specific cumulative incidences. <strong>Numerator:</strong> CIF for one reason by the selected horizon. <strong>Denominator:</strong> Any reason CIF for the same method and horizon. <strong>Programmatic relevance:</strong> shows the composition of discontinuation and therefore which responses account for the greatest share of stopping among discontinuers. Rows total 100% before rounding; switching is excluded because it can overlap with a reason.</div></section>",
"<section class='report-section' id='reinitiation'><div class='section-head'><div><p class='section-number'>Section 07</p><h2>Time to contraceptive reinitiation</h2></div><p>How quickly contraceptive use resumes after a method is discontinued for a non-pregnancy-related reason.</p></div>",
section_intro$reinitiation,
"<div class='definition-box'><div><h3>Starting analytic sample</h3><p>Observed contraceptive episodes discontinued for reasons other than <strong>method failure/pregnancy while using</strong> or <strong>desire to become pregnant</strong>.</p><p>Time begins at the end of the discontinued episode. Starting another contraceptive method is the event of interest.</p></div><div><h3>Competing-risk method</h3><p>A subsequent pregnancy, birth, or termination before reinitiation is treated as a competing event. Episodes reaching the interview without either outcome are right censored.</p><p class='formula'>Weighted Aalen-Johansen cumulative incidence of reinitiation</p><p>Across all methods, ", fmt_pct(overall_reinitiation_12), "% had reinitiated by 12 months after accounting for the competing pregnancy outcome.</p></div></div>",
"<div class='definition-box'><div><h3>Numerator and denominator</h3><p>This is not a single crude numerator divided by a fixed denominator. At each month, the <strong>numerator contribution</strong> is the survey-weighted number of first reinitiations occurring in that month. The <strong>denominator</strong> is the survey-weighted risk set still under observation and free of both reinitiation and pregnancy at the beginning of that month.</p><p>After a reinitiation or competing pregnancy, that episode leaves later risk sets. Interview censoring removes an episode only after its final observed month.</p></div><div><h3>How the table is calculated</h3><p>For month t, Aalen-Johansen adds the event-free probability immediately before t multiplied by the weighted reinitiation hazard at t.</p><p class='formula'>CIF(t) = sum through t of S(u-) x weighted reinitiations(u) / weighted risk set(u)</p><p>The displayed cell is therefore the estimated cumulative probability of reinitiating by the stated month, accounting for the competing pregnancy outcome.</p></div></div>",
"<h3 class='subsection-title'>Timing to any reinitiation by discontinued method</h3><p class='subsection-intro'>Rows identify the method that ended. Columns show the cumulative percentage estimated to have initiated any subsequent contraceptive method by 1, 3, 6, 9, or 12 months.</p>",
"<div class='table-scroll'><table><thead><tr><th rowspan='2'>Discontinued method</th><th colspan='5'>Cumulative reinitiation</th><th colspan='2'>Other 12-month outcomes</th><th colspan='2'>Eligible episodes</th></tr><tr>",
paste0("<th>", reinitiation_horizons, "</th>", collapse = ""),
"<th>Pregnancy before reinitiation</th><th>No observed event</th><th>Weighted</th><th>Unweighted</th></tr></thead><tbody>",
paste0(reinitiation_table_rows, collapse = ""),
"</tbody></table></div>", reading_guide$reinitiation_summary,
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted Aalen-Johansen competing-risk cumulative incidence. At each month, the numerator contribution is the weighted first reinitiations in that month and the denominator is the weighted episodes still observed and free of both reinitiation and pregnancy at the start of that month. Pregnancy before reinitiation is a competing event; interview is right censoring. <strong>What totals 100%:</strong> only the three 12-month outcome columns&mdash;reinitiated by 12 months, pregnancy before reinitiation by 12 months, and no observed event at 12 months&mdash;form a mutually exclusive partition and sum to 100% before rounding. The earlier reinitiation columns are cumulative milestones and must not be added together.</div>",
"<div class='table-equivalence-note'><strong>How to interpret:</strong> Read each row across time. A value of ", fmt_pct(overall_reinitiation_1), "% in the All methods row at 1 month means that an estimated ", fmt_pct(overall_reinitiation_1), "% of eligible discontinued episodes had initiated a subsequent contraceptive method by the next calendar month. By 12 months, the cumulative estimate is ", fmt_pct(overall_reinitiation_12), "%. Differences between columns show when reinitiation accumulated; differences between rows show how timing varied according to the method that was discontinued. These are survey-weighted point estimates, not percentages calculated only among observed restarters.</div>",
"<div class='definition-box'><div><h3>Questions this table can answer</h3><p>How quickly does contraceptive use resume after discontinuation? Which discontinued methods are followed by the longest gaps? What share has reinitiated by the next month or by three months? What share experiences pregnancy before restarting? Where does reinitiation appear to plateau?</p></div><div><h3>Potential program responses</h3><p>Same-day switching and anticipatory counseling; follow-up during the first month; side-effect management; referral to a preferred replacement method; commodity continuity; community resupply; and targeted re-engagement for groups still without an observed event after three or six months.</p><p>These estimates identify patterns and intervention windows but do not, by themselves, establish why a gap occurred.</p></div></div>",
"<h3 class='subsection-title'>Month-by-month time to next method adoption</h3><p class='subsection-intro'>Each point is the cumulative percentage that had initiated a subsequent contraceptive method by that many months after discontinuation. The subsequent method may be the same method or a different method.</p>",
"<div class='hazard-grid'>", reinitiation_curve_cards, "</div>",
"<details class='distribution-layout'><summary>View exact monthly estimates</summary><div class='table-scroll'><table class='heatmap-table'><thead><tr><th>Discontinued method</th>",
paste0("<th>M", reinitiation_months, "</th>", collapse = ""),
"</tr></thead><tbody>", paste0(reinitiation_monthly_rows, collapse = ""),
"</tbody></table></div></details>", reading_guide$reinitiation_monthly,
"<h3 class='subsection-title'>Cumulative incidence of pregnancy before reinitiation</h3><p class='subsection-intro'>Competing pregnancy-related calendar events observed before contraceptive use resumed.</p>",
"<div class='table-scroll'><table><thead><tr><th>Discontinued method</th>",
paste0("<th>", reinitiation_horizons, "</th>", collapse = ""),
"</tr></thead><tbody>", paste0(pregnancy_table_rows, collapse = ""),
"</tbody></table></div>", reading_guide$pregnancy,
"<div class='method-footnote'><strong>Statistical method:</strong> weighted Aalen-Johansen competing-risk cumulative incidence, with reinitiation as the event, pregnancy as a competing event, and interview as censoring. <strong>Numerator contribution:</strong> weighted first reinitiations or pregnancy events in month t. <strong>Denominator:</strong> weighted eligible episodes still free of both outcomes at the start of month t. <strong>Programmatic relevance:</strong> identifies how quickly protection resumes and where follow-up or same-day switching could shorten gaps. An immediate next-calendar-month start is month 1.</div></section>",
reliability_note,
"<section class='report-section' id='destinations'><div class='section-head'><div><p class='section-number'>Section 08</p><h2>Method used upon reinitiation</h2></div><p>Where episodes transition after contraceptive use resumes.</p></div>",
section_intro$destinations,
"<div class='definition-box'><div><h3>Analytic unit</h3><p>Each row begins with one eligible discontinued contraceptive episode. A woman may contribute more than one episode.</p><p>The next contraceptive start may be the same method or a different method. Traditional methods are kept separate from other modern methods.</p></div><div><h3>Outcome framework</h3><p>Reinitiation destinations and pregnancy before reinitiation are competing outcomes. Interview is censoring.</p><p class='formula'>12 months is the default program view; 1, 3, 6, and 9 months remain selectable.</p></div></div>",
"<div class='path-toolbar'><h3>Destination among episodes that reinitiated</h3><label for='destination-horizon-select'>Reinitiated by<select id='destination-horizon-select'><option value='3'>3 months</option><option value='6'>6 months</option><option value='9'>9 months</option><option value='12' selected>12 months</option></select></label></div>",
"<div class='definition-box'><div><h3>Rows and columns</h3><p>Each row is the method that was discontinued. Each column is the first contraceptive method subsequently initiated by the selected milestone.</p><p>Other modern and traditional methods remain separate so movement into traditional use is visible.</p></div><div><h3>Numerator and denominator</h3><p><strong>Numerator:</strong> destination-specific Aalen-Johansen cumulative incidence by the selected month.</p><p><strong>Denominator:</strong> cumulative incidence of reinitiation with any method by the same month, summed across all destinations.</p><p class='formula'>Destination share = destination CIF / any-method reinitiation CIF x 100</p></div></div>",
destination_tables, reading_guide$destination,
reliability_note,
"<p class='note'>Each row totals 100% before rounding and describes method choice among episodes estimated to have reinitiated by that milestone. It does not describe all discontinued episodes.</p>",
"<div class='table-equivalence-note'><strong>How to interpret:</strong> Select a milestone and read across a row. The cells show where reinitiating episodes went after discontinuing that row's method. Comparing 3 with 12 months shows whether early reinitiators chose a different mix of methods than later reinitiators.</div>",
"<details class='distribution-layout'><summary>View outcomes among all eligible discontinued episodes</summary><div style='padding:16px'><div class='path-toolbar'><h3>Next observed outcome</h3><label for='path-horizon-select'>By month<select id='path-horizon-select'><option value='1'>1</option><option value='3'>3</option><option value='6'>6</option><option value='9'>9</option><option value='12' selected>12</option></select></label></div>",
transition_tables, reading_guide$destination_complete,
"<p class='note'>Unlike the matrix above, this denominator is all eligible discontinued episodes. Reinitiation destinations, pregnancy, and no observed event partition the outcome and total 100% within each row.</p></div></details>",
"<p class='note'><strong>Display choice:</strong> The matrix is used for the main evidence because it preserves exact values and comparisons across milestones. A 12-month alluvial can be a supplementary overview, but it is less effective for precise comparison.</p>",
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted Aalen-Johansen competing-risk cumulative incidence. <strong>Numerator:</strong> destination-specific CIF. <strong>Denominator:</strong> any-method reinitiation CIF in the main conditional matrix, or all eligible discontinued episodes in the expanded outcome partition. <strong>Programmatic relevance:</strong> shows whether services enable movement to the method subsequently chosen and where pathways lead to traditional use, pregnancy, or no observed event. Point estimates use DHS weights; design-adjusted confidence intervals are not yet shown.</div></section>",
"<section class='report-section' id='gaps'><div class='section-head'><div><p class='section-number'>Section 09</p><h2>Gap duration after discontinuation</h2></div><p>How long eligible discontinued episodes remain without a subsequent contraceptive start.</p></div>",
section_intro$gaps,
"<div class='definition-box'><div><h3>What the categories mean</h3><p>The reinitiation groups are mutually exclusive: next calendar month, months 2-3, months 4-6, months 7-9, or months 10-12. Pregnancy before reinitiation and no observed event by 12 months are separate outcomes.</p><p><strong>No observed event</strong> means neither reinitiation nor pregnancy was observed within 12 months before interview censoring; it does not prove permanent exit from contraception.</p></div><div><h3>How gaps are calculated</h3><p>Each reinitiation interval is the increment between cumulative-incidence estimates. For example, months 4-6 equals the reinitiation cumulative incidence at month 6 minus that at month 3.</p><p class='formula'>All five reinitiation intervals + pregnancy by 12 months + no observed event by 12 months = 100%</p></div></div>",
"<div class='table-scroll'><table><thead><tr><th>Discontinued method</th>", paste0("<th>", gap_labels, "</th>", collapse = ""), "</tr></thead><tbody>", paste0(gap_table_rows, collapse = ""), "</tbody></table></div>", reading_guide$gap,
"<h3 class='subsection-title'>Visual distribution</h3><div class='path-bars'>", gap_bar_rows, "</div>", gap_legend,
"<div class='definition-box'><div><h3>Questions this table can answer</h3><p>Which discontinued methods are followed by prompt restarting? Where are prolonged contraceptive gaps most common? What proportion reinitiates within one month, later in the year, experiences pregnancy first, or has neither outcome observed?</p></div><div><h3>Potential program responses</h3><p>Offer same-day method switching, schedule early follow-up, strengthen side-effect counseling and management, ensure referral and commodity continuity, and target re-engagement to method groups with large later-gap or no-event shares.</p><p>The table identifies intervention windows; it does not establish the reason for every gap.</p></div></div>",
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted Aalen-Johansen competing-risk cumulative incidence, differenced to form mutually exclusive intervals. <strong>Numerator:</strong> weighted probability contribution assigned to the displayed interval or competing outcome. <strong>Denominator:</strong> all eligible non-pregnancy-intent discontinuation episodes in the row method. <strong>Programmatic relevance:</strong> identifies when protection gaps occur and which previous methods may benefit from same-day switching, early outreach, or improved method availability. Rows sum to 100% before rounding.</div></section>",
reliability_note,
"<section class='report-section' id='modern-protection-pathways'><div class='section-head'><div><p class='section-number'>Section 09A</p><h2>Integrated post-discontinuation protection pathways</h2></div><p>What happens to modern-method protection during the 12 months after an eligible modern-method episode ends.</p></div>",
"<div class='definition-box'><div><h3>Why it is programmatically useful</h3><p>The ordinary discontinuation rate treats very different outcomes as equivalent. This matrix shows whether discontinuation produced:</p><ul><li>A successful and immediate modern-method transition;</li><li>A short interruption that might be prevented through follow-up;</li><li>A prolonged gap in contraceptive protection;</li><li>Movement from a modern to a traditional method;</li><li>Pregnancy before contraception resumed; or</li><li>No observed return to contraception.</li></ul></div><div><h3>Population and interpretation</h3><p>The analytic unit is an eligible discontinued modern-method episode. One woman may contribute more than one episode. Each episode is assigned to its first observed pathway through month 12, and the six pathway columns sum to 100% within each row before rounding.</p><p>This is a modern-protection view: adopting a traditional method is retained as a separate pathway rather than counted as restoration of modern-method protection.</p></div></div>",
"<div class='table-scroll'><table class='pathway-table'><thead><tr><th>Modern method discontinued</th>",
paste0("<th>", modern_pathway_labels, "</th>", collapse = ""),
"<th>Total</th></tr></thead><tbody>",
modern_pathway_rows, "</tbody></table></div>", reading_guide$modern_protection,
"<div class='definition-box'><div><h3>Column definitions</h3><p><sup>1</sup> <strong>Continued modern protection:</strong> the first subsequent method is modern and begins in the immediately following calendar month.</p><p><sup>2</sup> <strong>Temporary non-use:</strong> the first subsequent method is modern and begins in post-discontinuation month 2 or 3.</p><p><sup>3</sup> <strong>Prolonged gap followed by reinitiation:</strong> the first subsequent method is modern and begins in months 4&ndash;12.</p></div><div><h3>Other first outcomes</h3><p><sup>4</sup> <strong>Traditional-method use:</strong> the first subsequent contraceptive method within 12 months is traditional.</p><p><sup>5</sup> <strong>Pregnancy first:</strong> pregnancy, birth, or termination is observed before any subsequent contraceptive start.</p><p><sup>6</sup> <strong>No restart observed by 12 months:</strong> neither reinitiation nor pregnancy is observed by month 12 under the cumulative-incidence estimator. Pregnancy is excluded because it is reported separately in column 5. This does not prove permanent exit from contraception.</p></div></div>",
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted multi-cause Aalen-Johansen cumulative incidence, with the first modern reinitiation band, first traditional-method start, and pregnancy as competing outcomes and interview as right censoring. <strong>Numerator:</strong> weighted first events assigned to each pathway. <strong>Denominator:</strong> eligible discontinued modern-method episodes still observed and free of all pathways at the start of each month. <strong>Timing convention:</strong> month 1 is the immediately following calendar month; months 2&ndash;3 are the remaining prompt-reinitiation window; months 4&ndash;12 are an operational prolonged-gap band. Multi-country DHS research commonly evaluates prompt switching within three months because most switching occurs in that period. The 4&ndash;12-month grouping is a program-facing summary rather than a universal clinical cutoff; Section 09 retains the more detailed 4&ndash;6, 7&ndash;9, and 10&ndash;12-month bands.</div></section>",
"<section class='report-section' id='effectiveness'><div class='section-head'><div><p class='section-number'>Section 10</p><h2>Method-effectiveness transition</h2></div><p>Whether the first method adopted after discontinuation is in a higher, equal, or lower programmatic effectiveness tier.</p></div>",
section_intro$effectiveness,
"<div class='definition-box'><div><h3>Why this is separate</h3><p>This view summarizes destination pathways by method-effectiveness tier, while Section 08 preserves the actual destination method. Same-method restart is retained as its own category.</p></div><div><h3>Interpret with care</h3><p>Higher- or lower-effectiveness describes a population-level method tier, not whether a method is personally better or worse for an individual. Method preference, contraindications, reproductive intentions, and autonomy remain central.</p></div></div>",
"<div class='table-scroll'><table><thead><tr><th>Discontinued method</th>", paste0("<th>", effect_labels, "</th>", collapse = ""), "<th>Eligible episodes<br>(unweighted)</th><th>Reliability</th></tr></thead><tbody>", effect_table_rows, "</tbody></table></div>", reading_guide$effectiveness,
"<h3 class='subsection-title'>Visual distribution</h3><div class='path-bars'>", effect_bar_rows, "</div>", effect_legend,
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted Aalen-Johansen competing-risk cumulative incidence at 12 months. <strong>Numerator:</strong> weighted CIF assigned to each next-method tier, pregnancy, or no-event category. <strong>Denominator:</strong> all eligible discontinued episodes. <strong>Programmatic relevance:</strong> provides a compact signal of whether reinitiation pathways preserve, raise, or lower contraceptive effectiveness while retaining same-method restart and non-reinitiation outcomes. These are descriptive pathways, not judgments about individual preference or causal effects.</div></section>",
reliability_note,
"<section class='report-section' id='reason-outcomes'><div class='section-head'><div><p class='section-number'>Section 11</p><h2>What happens after discontinuation, by reason?</h2></div><p>Connects why an episode ended with whether contraceptive use resumed, pregnancy occurred first, or neither event was observed.</p></div>",
section_intro$reason_outcomes,
"<div class='definition-box'><div><h3>Numerator and denominator</h3><p><strong>Starting denominator:</strong> all observed discontinued episodes assigned to the reason in that row, across all previous methods. At each month, the model denominator is the survey-weighted risk set still observed and free of both reinitiation and pregnancy.</p><p><strong>Numerator contribution:</strong> the weighted first reinitiations&mdash;or first pregnancy-related competing events&mdash;occurring in that month. No observed event is the estimated event-free probability.</p></div><div><h3>Statistical model and interpretation</h3><p>Survey-weighted Aalen-Johansen competing-risk cumulative incidence at 1, 3, 6, and 12 months. The three outcomes within a reason and time point sum to 100% before rounding.</p><p>Method failure and desire for pregnancy are retained so every DHS reason is visible, but they represent different reproductive contexts and should not be interpreted as failures to retain a method.</p></div></div>",
"<div class='table-equivalence-note'><strong>Programmatic relevance:</strong> This connects a stated reason to its subsequent pathway. It can distinguish reasons commonly followed by prompt switching from reasons associated with prolonged gaps or pregnancy before restarting, helping target counseling, side-effect management, referral, resupply, and follow-up. The estimates are descriptive and do not prove that the stated reason caused the subsequent outcome.</div>",
"<h3 class='subsection-title'>Outcome heat maps</h3><p class='subsection-intro'>Darker cells indicate a larger cumulative probability within that outcome. Read across a row to see how outcomes accumulate over time; compare the three panels at the same month to see the complete outcome partition.</p>",
"<div class='reason-heatmap-grid'>", reason_heatmaps, "</div>", reading_guide$reason_outcome,
"<p class='note'>&#8224; 25&ndash;49 eligible episodes; &#8225; fewer than 25 eligible episodes. These estimates are displayed to preserve all reason categories but require cautious interpretation.</p>",
"<details class='distribution-layout'><summary>View exact estimates and episode counts</summary><div class='table-scroll'><table class='reason-table'><thead><tr><th rowspan='2'>Reason for discontinuation</th>",
paste0("<th colspan='3'>", reason_followup_horizons, " months</th>", collapse = ""),
"<th rowspan='2'>Weighted episodes</th><th rowspan='2'>Unweighted episodes</th></tr><tr>",
paste0(rep(c("<th>Reinitiated</th><th>Pregnancy first</th><th>No event</th>"), length(reason_followup_horizons)), collapse = ""),
"</tr></thead><tbody>", paste0(reason_exact_rows, collapse = ""), "</tbody></table></div></details>", reading_guide$reason_outcome,
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted Aalen-Johansen competing-risk cumulative incidence. <strong>Unit:</strong> discontinued episode; a woman may contribute multiple episodes. <strong>Censoring:</strong> interview before either event. <strong>How to use:</strong> compare reasons at the same horizon or follow one reason across time. Point estimates use DHS weights; design-adjusted confidence intervals are not yet shown.</div></section>",
"<section class='report-section' id='method-reason-outcomes'><div class='section-head'><div><p class='section-number'>Section 12</p><h2>Does the pathway differ by previous method and reason?</h2></div><p>Tests whether the same reason is followed by different outcomes depending on the method that was discontinued.</p></div>",
section_intro$method_reason,
"<div class='definition-box'><div><h3>Numerator and denominator</h3><p><strong>Starting denominator:</strong> discontinued episodes in the selected previous-method &times; reason cell. The monthly denominator is that cell's weighted risk set still free of reinitiation and pregnancy.</p><p><strong>Numerator contribution:</strong> weighted first reinitiations or first pregnancy-related events in the selected month. The no-event value is the complementary event-free probability.</p></div><div><h3>Statistical model</h3><p>Separate survey-weighted Aalen-Johansen competing-risk estimates are calculated within each previous-method &times; reason subgroup at 1, 3, 6, and 12 months.</p><p>Cells with fewer than 25 eligible episodes are suppressed; cells with 25&ndash;49 episodes are marked &#8224;. This prevents sparse estimates from appearing equally reliable.</p></div></div>",
"<div class='table-equivalence-note'><strong>Programmatic relevance:</strong> The same reason may imply a different response depending on the method. For example, side-effect discontinuation after an injectable may call for anticipatory counseling and ready access to alternatives, while a desire for a more effective method can reveal whether referral pathways actually lead to a preferred replacement.</div>",
"<div class='outcome-controls'><label for='method-reason-outcome-select'>Outcome<select id='method-reason-outcome-select'><option value='restart' selected>Reinitiated contraception</option><option value='pregnancy'>Pregnancy before reinitiation</option><option value='no-event'>No observed event</option></select></label><label for='method-reason-horizon-select'>By month<select id='method-reason-horizon-select'><option value='1'>1 month</option><option value='3'>3 months</option><option value='6'>6 months</option><option value='12' selected>12 months</option></select></label></div>",
method_reason_panels,
reading_guide$method_reason,
"<p class='note'>Darker cells indicate larger probabilities within the selected outcome. &mdash; indicates fewer than 25 eligible episodes; &#8224; indicates 25&ndash;49. Emergency contraception should be interpreted separately because it is episodic rather than a continuously used method.</p>",
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted Aalen-Johansen competing-risk cumulative incidence stratified by previous method and DHS reason group. <strong>Interpretation:</strong> each visible cell is the estimated cumulative probability of the selected outcome by the selected month among episodes in that method&ndash;reason subgroup. These are descriptive associations, not causal effects; unmeasured fertility intentions, access, preferences, and service experiences may differ across cells.</div></section>",
"<section class='report-section' id='calendar-validation'><div class='section-head'><div><p class='section-number'>Section 13</p><h2>Calendar use and initiation validation</h2></div><p>Compares the calendar with the cross-sectional survey question at interview and consolidates the annual calendar-use and initiation-mix results.</p></div>",
"<div class='definition-box'><div><h3>Why two comparisons are needed</h3><p>The annual calendar table averages use across all valid observed woman-months in each year. In contrast, v312 records the method used only at the interview date and cannot estimate historical annual prevalence.</p><p>The like-for-like validation therefore compares v312 with vcal_1 in the same interview month. Values close to zero in the difference columns indicate agreement.</p></div><div><h3>Interpretation</h3><p>Annual calendar estimates describe retrospective patterns over time. The v312 comparison tests measurement consistency at interview, not whether every historical annual estimate equals the survey-date prevalence.</p><p class='formula'>Difference = calendar interview-month prevalence - survey-question prevalence</p></div></div>",
"<h3 class='subsection-title'>Current use at interview: calendar versus survey question</h3>",
"<div class='table-scroll'><table><thead><tr><th>Interview period</th><th>Any use: v312</th><th>Any use: calendar interview month</th><th>Difference (pp)</th><th>Modern use: survey</th><th>Modern use: calendar interview month</th><th>Difference (pp)</th><th>Weighted women</th></tr></thead><tbody>",
paste0(current_use_comparison_rows, collapse = ""), "</tbody></table></div>", reading_guide$current_use_comparison,
"<h3 class='subsection-title'>Annual calendar-based contraceptive use</h3>",
"<div class='table-scroll'><table><thead><tr><th>Calendar year</th><th>Any use: calendar annual average</th><th>Modern use: calendar annual average</th><th>Any current use: v312 at interview</th><th>Modern current use: survey at interview</th><th>Weighted observed woman-months</th><th>Coverage</th></tr></thead><tbody>",
paste0(annual_use_rows, collapse = ""), "</tbody></table></div>", reading_guide$annual_use,
"<h3 class='subsection-title'>Method initiation mix by calendar year</h3><p class='subsection-intro'>Each year column sums to 100% across the five method categories before rounding.</p>",
"<div class='table-scroll'><table><thead><tr><th>Method started</th>", paste0("<th>", annual_initiation_years, "</th>", collapse = ""), "</tr></thead><tbody>",
paste0(annual_mix_wide_rows, collapse = ""), "</tbody></table></div>", reading_guide$annual_mix_wide,
"<div class='method-footnote'><strong>Statistical method:</strong> survey-weighted prevalence ratios and annual weighted cross-tabulations. <strong>v312 denominator:</strong> women interviewed with valid current-use and calendar fields. <strong>Annual calendar denominator:</strong> valid observed calendar woman-months in each year. <strong>Initiation denominator:</strong> all observed weighted contraceptive episode starts in the year. These are descriptive estimates; no life table or hazard model is used in this section.</div></section>",
"<section class='report-section' id='leaky-bucket'><div class='section-head'><div><p class='section-number'>Section 14</p><h2>Observed-start cohort and contraceptive recovery</h2></div><p>A complementary leaky-bucket view of whether newly observed starts are retained and what happens after they discontinue.</p></div>",
section_intro$leaky_bucket,
"<div class='definition-box'><div><h3>What the primary analysis includes</h3><p>The DHS-style analysis includes eligible episodes observed at risk during the analysis window. An episode that began earlier in the recorded calendar may enter the risk set later through delayed entry if it remains in use. Episodes already underway at the first recorded calendar month are excluded because their initiation date is unknown.</p></div><div><h3>What the observed-start cohort adds</h3><p>The leaky-bucket cohort requires the method start and the immediately preceding calendar state to be observed. It follows those starts into discontinuation and, for eligible non-pregnancy-intent discontinuations, into a different-method switch, same-method restart, pregnancy first, or no observed event.</p></div></div>",
"<h3 class='subsection-title'>Cumulative discontinuation: DHS-style versus observed-start cohort</h3><p class='subsection-intro'>The first four columns retain the main DHS-comparable estimates. The second four restrict the life table to observed starts.</p>",
"<div class='table-scroll'><table><thead><tr><th rowspan='2'>Method</th><th colspan='4'>DHS-style population</th><th colspan='4'>Observed-start cohort</th></tr><tr>",
paste0("<th>", horizon_order, "</th>", collapse = ""), paste0("<th>", horizon_order, "</th>", collapse = ""), "</tr></thead><tbody>",
paste0(leaky_bucket_rows, collapse = ""), "</tbody></table></div>", reading_guide$leaky_discontinuation,
"<h3 class='subsection-title'>How quickly does contraceptive use recover or switch?</h3><p class='subsection-intro'>All-method cumulative pathways at 1, 3, 6, 9, and 12 months. Any-method reinitiation is shown for continuity with Section 07 and is also separated into different-method switching and same-method restarting.</p>",
"<div class='table-scroll'><table><thead><tr><th>Cohort</th><th>By month</th><th>Different-method switch</th><th>Same-method restart</th><th>Any-method reinitiation</th><th>Pregnancy first</th><th>No observed event</th></tr></thead><tbody>",
paste0(switching_timing_rows, collapse = ""), "</tbody></table></div>", reading_guide$switching_pathways,
"<h3 class='subsection-title'>Observed-start cohort pathways at 12 months, by method initiated</h3><p class='subsection-intro'>Rows identify the method originally started and subsequently discontinued for an eligible non-pregnancy-intent reason.</p>",
"<div class='table-scroll'><table><thead><tr><th>Method initially started</th><th>Different-method switch</th><th>Same-method restart</th><th>Any-method reinitiation</th><th>Pregnancy first</th><th>No observed event</th><th>Weighted episodes</th><th>Unweighted episodes</th></tr></thead><tbody>",
paste0(leaky_switching_method_rows, collapse = ""), "</tbody></table></div>", reading_guide$switching_pathways,
"<div class='method-footnote'><strong>Statistical methods:</strong> survey-weighted discrete-time life tables for all-cause discontinuation and survey-weighted Aalen-Johansen competing-risk cumulative incidence for post-discontinuation pathways. <strong>Reinitiation</strong> includes both the same method and a different method. <strong>Switching</strong> means the first subsequent contraceptive method differs from the method that ended. Pregnancy before reinitiation is a competing event and interview is right censoring. This observed-start analysis complements rather than replaces the DHS-style estimates.</div></section>",
"<section class='report-section' id='cohort-timing-guide'><div class='section-head'><div><p class='section-number'>Section 15</p><h2>How to interpret the episode cohorts and time horizons</h2></div><p>A guide to which episodes enter each analysis, when follow-up begins, and how the discontinuation and switching estimates are calculated.</p></div>",
"<div class='definition-box'><div><h3>The five-year window selects episode starts</h3><p>The observed-start sensitivity cohort contains contraceptive episodes beginning 3&ndash;62 months before each woman&rsquo;s interview, provided that the immediately preceding calendar state is also observed. This is an approximately five-year rolling window relative to interview, rather than one common set of calendar dates for every respondent.</p><p>The primary DHS-style analysis is broader: it includes observed starts and also permits delayed entry for an episode that began before the 62-month analysis boundary but remained in use inside the analysis window. It does not include episodes already underway at the oldest recorded calendar month, because their initiation date and full duration are unknown.</p></div><div><h3>The 12-month horizon measures follow-up</h3><p>For discontinuation, time zero is method initiation and estimates are accumulated through months 3, 6, 9, and 12 of use. For switching and reinitiation, time zero is the end of an eligible discontinued episode and outcomes are accumulated through months 1, 3, 6, 9, and 12 afterward.</p><p>An episode does not need 12 complete months of observable follow-up to enter. It contributes while observed and at risk, then is right-censored when observation ends.</p></div></div>",
"<h3 class='subsection-title'>Analysis populations, numerators, denominators, and clocks</h3>",
"<div class='table-scroll'><table><thead><tr><th>Analysis</th><th>Starting population</th><th>Time zero and horizon</th><th>Numerator</th><th>Denominator / risk set</th></tr></thead><tbody>",
"<tr><td><strong>Primary DHS-style discontinuation</strong></td><td>Eligible contraceptive episodes observed at risk in the 3&ndash;62 months-before-interview window, including eligible delayed-entry episodes. Episodes already underway at the oldest recorded calendar boundary are excluded.</td><td>Episode initiation; cumulative discontinuation by months 3, 6, 9, and 12 of use.</td><td>Survey-weighted discontinuations occurring in each month of use.</td><td>Survey-weighted episodes still observed, using the method, and at risk at the start of that month. Delayed entry and right-censoring are applied.</td></tr>",
"<tr><td><strong>Observed-start discontinuation sensitivity</strong></td><td>Episodes whose method initiation and immediately preceding calendar state are both observed within 3&ndash;62 months before interview.</td><td>Observed method initiation; cumulative discontinuation by months 3, 6, 9, and 12 of use.</td><td>Survey-weighted discontinuations among observed-start episodes occurring in each month of use.</td><td>Survey-weighted observed-start episodes still observed, using the method, and at risk at the start of that month. Incomplete follow-up is right-censored.</td></tr>",
"<tr><td><strong>Post-discontinuation switching and reinitiation</strong></td><td>Observed-start episodes that discontinued for an eligible reason; method failure/pregnancy while using and desire for pregnancy are excluded.</td><td>End of the discontinued episode; cumulative outcomes by months 1, 3, 6, 9, and 12 afterward.</td><td>First different-method start, first same-method restart, or pregnancy occurring first, accumulated separately.</td><td>Survey-weighted eligible discontinued episodes still observed and free of reinitiation and pregnancy at the start of that post-discontinuation month.</td></tr>",
"</tbody></table></div>",
"<div class='definition-box'><div><h3>What adds to 100%</h3><p>At each post-discontinuation horizon, different-method switching, same-method restarting, pregnancy before reinitiation, and no observed event form a mutually exclusive competing-risk partition and sum to 100% before rounding. Any-method reinitiation equals different-method switching plus same-method restarting.</p></div><div><h3>Why both discontinuation populations are shown</h3><p>The primary analysis preserves comparability with the DHS discontinuation approach. The observed-start sensitivity analysis asks a narrower program-flow question: among starts that can be seen entering the system, how much use is retained during the first year and how much is recovered through restarting or switching after discontinuation?</p></div></div>",
"<div class='method-footnote'><strong>Statistical methods:</strong> discontinuation uses survey-weighted discrete-time life tables, so cumulative estimates are constructed from changing monthly risk sets rather than a single crude numerator divided by all episodes. Post-discontinuation pathways use survey-weighted Aalen-Johansen cumulative incidence with pregnancy as a competing event and interview as right censoring. These are descriptive weighted estimates; this implementation does not estimate regression-adjusted causal effects.</div></section></main>",
"<footer>Source: Ethiopia DHS 2024-25 Individual Recode contraceptive calendar. Estimates reconstructed from the public-use IR file using documented DHS discontinuation rules.</footer>",
"<script>document.querySelectorAll('.tab-button').forEach(function(button){button.addEventListener('click',function(){document.querySelectorAll('.tab-button').forEach(function(x){x.classList.remove('active')});document.querySelectorAll('.duration-panel').forEach(function(x){x.classList.remove('active')});button.classList.add('active');document.getElementById(button.dataset.panel).classList.add('active')})});document.getElementById('path-horizon-select').addEventListener('change',function(){document.querySelectorAll('.path-horizon-panel').forEach(function(x){x.classList.remove('active')});document.getElementById('path-horizon-'+this.value).classList.add('active')});document.getElementById('destination-horizon-select').addEventListener('change',function(){document.querySelectorAll('.destination-horizon-panel').forEach(function(x){x.classList.remove('active')});document.getElementById('destination-horizon-'+this.value).classList.add('active')});function updateMethodReason(){document.querySelectorAll('.method-reason-panel').forEach(function(x){x.classList.remove('active')});var outcome=document.getElementById('method-reason-outcome-select').value;var month=document.getElementById('method-reason-horizon-select').value;document.getElementById('method-reason-'+outcome+'-'+month).classList.add('active')}document.getElementById('method-reason-outcome-select').addEventListener('change',updateMethodReason);document.getElementById('method-reason-horizon-select').addEventListener('change',updateMethodReason);document.querySelectorAll('table').forEach(function(table){var note=document.createElement('p');note.className='other-category-note';note.innerHTML='<strong>Other method category:</strong> Where shown, Other includes recognized contraceptive methods not displayed as separate rows: IUD, diaphragm, condoms, female or male sterilization, periodic abstinence, withdrawal, other traditional methods, prolonged abstinence, lactational amenorrhea method (LAM), foam or jelly, other modern methods, and the standard days method.';var wrapper=table.closest('.table-scroll')||table;wrapper.insertAdjacentElement('afterend',note)});</script>",
"</body></html>"
)

output_file <- file.path(output_dir, "ethiopia_discontinuation_3_6_9_12.html")
writeLines(enc2utf8(html), output_file, useBytes = TRUE)

if (!file.exists(output_file) || file.info(output_file)$size < 10000) {
  stop("HTML report was not created correctly: ", output_file, call. = FALSE)
}
message("Created HTML report: ", output_file)
