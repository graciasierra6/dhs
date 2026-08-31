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
details <- "--details" %in% commandArgs(trailingOnly = TRUE)

source(file.path(project_root, "R", "map_validation.R"), encoding = "UTF-8")
result <- validate_map_build(project_root = project_root, online = online, verbose = TRUE)

if (isTRUE(details)) {
  detail_columns <- c(
    "country", "dashboard_name", "public_shape_name", "shape_iso", "shape_id",
    "bbox_center_lon", "bbox_center_lat", "render_occurrences"
  )
  print(result$areas[detail_columns], row.names = FALSE)
}
