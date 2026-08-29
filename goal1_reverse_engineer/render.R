command_line <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_line, value = TRUE)
script_file <- if (length(file_argument) == 1L) sub("^--file=", "", file_argument) else "render.R"
script_path <- normalizePath(
  script_file,
  winslash = "/",
  mustWork = TRUE
)
project_root <- dirname(script_path)
args <- commandArgs(trailingOnly = TRUE)
output_file <- if (length(args)) args[[1]] else file.path("output", "goal1_reverse_engineer_test.html")

source(file.path(project_root, "R", "reference_build.R"), encoding = "UTF-8")
rendered <- build_reference_dashboard(output_file = output_file, project_root = project_root)
cat("Rendered and source-validated:", rendered$html, "\n")
cat("Threshold distribution CSV:", rendered$threshold_distribution, "\n")
cat("Profiles: generated in the self-contained HTML from validated source data.\n")
