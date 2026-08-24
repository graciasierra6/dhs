command_line <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_line, value = TRUE)
script_file <- if (length(file_argument) == 1L) sub("^--file=", "", file_argument) else "validate.R"
script_path <- normalizePath(
  script_file,
  winslash = "/",
  mustWork = TRUE
)
project_root <- dirname(script_path)
output_file <- file.path(project_root, "output", "goal1_reverse_engineer_test.html")

source(file.path(project_root, "R", "data_prep.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "html_helpers.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "map_validation.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "reference_validation.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "threshold_distribution.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "risk_alignment_validation.R"), encoding = "UTF-8")

reports <- prepare_all_report_data(
  input_file = file.path(project_root, "data", "count_map_input_combined_master.csv"),
  composite_file = file.path(project_root, "data", "composite_indicator_rankings.csv"),
  indicator_file = file.path(project_root, "data", "subnational_indicator_rankings.csv"),
  mortality_file = file.path(project_root, "data", "mortalityunder5.csv"),
  profile_file = file.path(project_root, "data", "profile_indicator_estimates.csv")
)
risk_alignment_audit <- validate_risk_alignment(reports)

expected <- data.frame(
  country = c("DRC", "Ethiopia", "Nigeria"),
  areas = c(26L, 11L, 37L),
  indicators = c(8L, 7L, 8L),
  indicator_rows = c(208L, 77L, 296L),
  stringsAsFactors = FALSE
)

for (index in seq_len(nrow(expected))) {
  country <- expected$country[index]
  report <- reports[[country]]
  stopifnot(report$rank_max == expected$areas[index])
  stopifnot(report$indicator_count == expected$indicators[index])
  stopifnot(nrow(report$indicators) == expected$indicator_rows[index])
  stopifnot(nrow(report$classifications) == expected$indicator_rows[index])
  stopifnot(!anyDuplicated(report$composite$admin_name))
  stopifnot(!anyDuplicated(report$indicators[c("admin_name", "indicator")]))
  stopifnot(all(report$composite$composite_set != "severe"))
  stopifnot(nrow(report$mortality) == expected$areas[index])
  stopifnot(!anyDuplicated(report$mortality$admin_name))
  stopifnot(setequal(report$mortality$admin_name, report$composite$admin_name))
  stopifnot(!anyNA(report$mortality$u5mr_est_1000))

  for (indicator_id in report$definitions$id) {
    rows <- report$indicators[report$indicators$indicator == indicator_id, , drop = FALSE]
    threshold <- as.numeric(stats::quantile(abs(rows$pp_change_10yr_recoded), 0.25, type = 7))
    stopifnot(abs(threshold - report$thresholds[[indicator_id]]) < 1e-12)
  }
}

distribution_file <- file.path(project_root, "data", "worsening_count_threshold_distributions.csv")
if (!file.exists(distribution_file)) {
  stop("Missing threshold distribution CSV. Run Rscript render.R first.", call. = FALSE)
}
expected_distribution <- build_worsening_threshold_distribution(reports)
actual_distribution <- utils::read.csv(
  distribution_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
validate_worsening_threshold_distribution(actual_distribution, reports)
reference_compare_frames(
  expected_distribution,
  actual_distribution,
  keys = c("country", "indicator", "admin_name"),
  text_fields = c("indicator_label", "direction", "classification", "classification_label"),
  numeric_fields = c(
    "distribution_order_improving_to_worsening", "absolute_change_distribution_rank",
    "areas_in_country_indicator_distribution", "latest_year", "observed_latest_estimate",
    "prevalence_rank", "change_rank", "risk_aligned_change_pp", "absolute_risk_aligned_change_pp",
    "threshold_percentile", "quantile_type", "threshold_t_pp", "improving_cutoff_pp",
    "worsening_cutoff_pp", "improving_count_contribution",
    "non_significant_count_contribution", "worsening_count_contribution"
  ),
  tolerance = 1e-8
)

stopifnot(attr(risk_alignment_audit, "indicator_rows") == 581L)
stopifnot(attr(risk_alignment_audit, "bivariate_pairs") == 77L)

if (!file.exists(output_file)) {
  stop("Missing rendered dashboard. Run Rscript render.R first.", call. = FALSE)
}
rendered_html <- reference_read_utf8(output_file)
for (country in names(reports)) {
  report <- reports[[country]]
  bivariate_html <- reference_extract_section(rendered_html, paste0(report$slug, "-bivariate"))
  stopifnot(reference_fixed_count('<use class="map-region', bivariate_html) == report$rank_max)
  stopifnot(reference_fixed_count("biv-region", bivariate_html) == report$rank_max)
  for (indicator_id in report$definitions$id) {
    stopifnot(reference_fixed_count(paste0('<option value="', indicator_id, '">'), bivariate_html) == 2L)
  }
}
interaction_script <- reference_read_utf8(
  file.path(project_root, "assets", "js", "reference_dashboard.template.js")
)
stopifnot(grepl("ensureBivariateModeControl", interaction_script, fixed = TRUE))
stopifnot(grepl('<option value="prevalence_rank">Current rank</option>', interaction_script, fixed = TRUE))
stopifnot(grepl('modeSelect?.addEventListener("change"', interaction_script, fixed = TRUE))
stopifnot(grepl("updateBivariateSection(section)", interaction_script, fixed = TRUE))
stopifnot(grepl('indicatorRows.filter((row) => row.country === country)', interaction_script, fixed = TRUE))
stopifnot(grepl('classifications.filter((row) => row.country === country)', interaction_script, fixed = TRUE))
stopifnot(grepl('bivariateColors[xr.classification + ":" + yr.classification]', interaction_script, fixed = TRUE))
stopifnot(grepl('prevalenceRankBivariateColors[xb + ":" + yb]', interaction_script, fixed = TRUE))
stopifnot(grepl('mode === "prevalence_rank" ? "prevalence" : "change"', interaction_script, fixed = TRUE))

validate_reference_source_alignment(reports, project_root = project_root, output_file = output_file)
map_result <- validate_map_build(project_root = project_root, online = FALSE, verbose = FALSE)

cat(
  "Validation passed: 74 administrative areas; 581 source-aligned indicator rows; ",
  "581-row worsening-threshold distribution CSV; 581 country- and indicator-specific risk classifications; ",
  "148 embedded profile plots; six composite rank maps, DRC count map, three bivariate sections, ",
  "77 complete country-specific indicator pairs in both bivariate modes; 581 independently risk-aligned endpoint records; ",
  "state-name and geometry joins; ",
  map_result$checks, " boundary checks; no external data requests, absolute paths, or machine identifiers.\n",
  sep = ""
)
