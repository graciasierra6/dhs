command_line <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_line, value = TRUE)
if (length(file_argument) != 1L) {
  stop("Run this script with Rscript from the project folder.", call. = FALSE)
}

script_path <- normalizePath(
  sub("^--file=", "", file_argument),
  winslash = "/",
  mustWork = TRUE
)
project_root <- dirname(dirname(script_path))
details <- "--details" %in% commandArgs(trailingOnly = TRUE)

source(file.path(project_root, "R", "data_prep.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "html_helpers.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "worsening_count_validation.R"), encoding = "UTF-8")

reports <- prepare_all_report_data(
  input_file = file.path(project_root, "data", "count_map_input_combined_master.csv"),
  composite_file = file.path(project_root, "data", "composite_indicator_rankings.csv"),
  indicator_file = file.path(project_root, "data", "subnational_indicator_rankings.csv"),
  mortality_file = file.path(project_root, "data", "mortalityunder5.csv"),
  profile_file = file.path(project_root, "data", "profile_indicator_estimates.csv")
)
distribution <- utils::read.csv(
  file.path(project_root, "data", "worsening_count_threshold_distributions.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
result <- validate_worsening_count_maps(
  reports = reports,
  distribution = distribution,
  html_path = file.path(project_root, "output", "goal1_reverse_engineer_test.html"),
  verbose = TRUE
)

print(result$indicators, row.names = FALSE)
if (isTRUE(details)) {
  cat("\nADM1 count-map audit:\n")
  print(result$areas, row.names = FALSE)
}
