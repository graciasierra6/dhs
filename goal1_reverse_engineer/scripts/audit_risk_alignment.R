command_line <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_line, value = TRUE)
script_file <- if (length(file_argument) == 1L) sub("^--file=", "", file_argument) else "scripts/audit_risk_alignment.R"
project_root <- dirname(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)))

source(file.path(project_root, "R", "data_prep.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "risk_alignment_validation.R"), encoding = "UTF-8")

reports <- prepare_all_report_data(
  input_file = file.path(project_root, "data", "count_map_input_combined_master.csv"),
  composite_file = file.path(project_root, "data", "composite_indicator_rankings.csv"),
  indicator_file = file.path(project_root, "data", "subnational_indicator_rankings.csv"),
  mortality_file = file.path(project_root, "data", "mortalityunder5.csv"),
  profile_file = file.path(project_root, "data", "profile_indicator_estimates.csv")
)

audit <- validate_risk_alignment(reports)
print(audit, row.names = FALSE)
cat(
  "\nRisk-alignment audit passed: ", attr(audit, "indicator_rows"),
  " area-indicator rows and ", attr(audit, "bivariate_pairs"),
  " country-specific indicator pairs.\n",
  sep = ""
)
