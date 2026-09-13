# Ethiopia 2024-25 contraceptive discontinuation analysis
#
# Purpose
# -------
# Reproduce the DHS-style all-cause and competing-risk discontinuation tables
# at 3, 6, 9, and 12 months from the Ethiopia Individual Recode calendar.
#
# The calculation engine is maintained in `replicate_table_7_11.R` at the
# project root. This runner makes that analysis portable by finding the project
# relative to this script rather than relying on the current working directory.
#
# Run from RStudio:
#   source("code/run_discontinuation_analysis.R")
#
# Run from a terminal opened anywhere:
#   Rscript path/to/code/run_discontinuation_analysis.R

options(stringsAsFactors = FALSE)

script_path <- function() {
  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", command_args, value = TRUE)
  if (length(file_arg) == 1L) {
    return(normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE))
  }

  # `sys.frames()` exposes `ofile` when this script is run with source().
  frames <- sys.frames()
  source_files <- vapply(
    frames,
    function(frame) {
      if (!is.null(frame$ofile)) as.character(frame$ofile) else NA_character_
    },
    character(1)
  )
  source_files <- source_files[!is.na(source_files)]
  if (length(source_files) > 0L) {
    return(normalizePath(tail(source_files, 1L), mustWork = TRUE))
  }

  stop(
    "Could not determine this script's location. Run it with Rscript or source().",
    call. = FALSE
  )
}

code_dir <- dirname(script_path())
project_dir <- normalizePath(file.path(code_dir, ".."), mustWork = TRUE)
analysis_script <- file.path(code_dir, "replicate_table_7_11.R")
input_file <- file.path(project_dir, "Data", "Ethiopia", "ETIR8AFL.dta")

if (!file.exists(analysis_script)) {
  stop("Missing analysis engine: ", analysis_script, call. = FALSE)
}
if (!file.exists(input_file)) {
  stop(
    "Missing Ethiopia IR input file. Expected: ", input_file,
    "\nPlace ETIR8AFL.dta in Data/Ethiopia and rerun.",
    call. = FALSE
  )
}

options(ethiopia_discontinuation_project_dir = project_dir)
source(analysis_script, chdir = FALSE)
source(file.path(code_dir, "analyze_monthly_hazards.R"), chdir = FALSE)
source(file.path(code_dir, "analyze_initiation.R"), chdir = FALSE)
source(file.path(code_dir, "analyze_reinitiation.R"), chdir = FALSE)
source(file.path(code_dir, "analyze_leaky_bucket.R"), chdir = FALSE)
source(file.path(code_dir, "analyze_reason_post_discontinuation.R"),
       chdir = FALSE)
source(file.path(code_dir, "analyze_post_discontinuation_transitions.R"),
       chdir = FALSE)
source(file.path(code_dir, "summarize_predominant_reasons.R"), chdir = FALSE)
source(file.path(code_dir, "build_html_report.R"), chdir = FALSE)
source(file.path(code_dir, "build_programmatic_summary.R"), chdir = FALSE)

expected_outputs <- file.path(
  project_dir,
  file.path("Analyses", "derived"),
  c(
    "all_cause_life_table_published_groups.csv",
    "competing_risk_reasons_3_6_9_12_months.csv",
    "competing_risk_reasons_12_month_validation.csv",
    "reason_predominance_by_method_and_horizon.csv",
    "observed_method_initiation_mix.csv",
    "observed_method_initiation_rates.csv",
    "annual_observed_method_initiation_mix.csv",
    "annual_method_initiation_percent.csv",
    "annual_calendar_contraceptive_use.csv",
    "annual_calendar_validation.csv",
    "calendar_vs_v312_current_use.csv",
    "leaky_bucket_discontinuation_comparison.csv",
    "reinitiation_switching_pathways.csv",
    "leaky_bucket_validation.csv",
    "monthly_all_cause_discontinuation_hazards.csv",
    "monthly_cause_specific_discontinuation_hazards.csv",
    "reason_timing_share_of_12_month_cif.csv",
    "monthly_hazard_identity_validation.csv",
    "reinitiation_competing_risk_1_3_6_9_12.csv",
    "reinitiation_monthly_competing_risk_1_12.csv",
    "reinitiation_sample_summary.csv",
    "reason_post_discontinuation_outcomes.csv",
    "reason_previous_method_post_discontinuation_outcomes.csv",
    "post_discontinuation_transition_matrix.csv",
    "post_discontinuation_destination_among_reinitiators.csv",
    "post_discontinuation_effectiveness_transition.csv",
    "post_discontinuation_gap_distribution.csv",
    "post_discontinuation_modern_protection_pathways.csv",
    "single_vs_competing_risk_equivalence.csv",
    "validation_summary.csv"
  )
)

missing_outputs <- expected_outputs[!file.exists(expected_outputs)]
if (length(missing_outputs) > 0L) {
  stop(
    "Analysis finished without creating all required outputs:\n- ",
    paste(missing_outputs, collapse = "\n- "),
    call. = FALSE
  )
}

message(
  "Analysis completed successfully. Outputs are in: ",
  file.path(project_dir, "Analyses", "derived")
)
message(
  "HTML report: ",
  file.path(project_dir, "output", "ethiopia_discontinuation_3_6_9_12.html")
)
