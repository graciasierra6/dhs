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
online <- "--online" %in% commandArgs(trailingOnly = TRUE)

source(file.path(project_root, "R", "map_validation.R"), encoding = "UTF-8")
validate_map_build(project_root = project_root, online = online, verbose = TRUE)
