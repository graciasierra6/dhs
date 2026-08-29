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
source(file.path(project_root, "R", "map_validation.R"), encoding = "UTF-8")

html_path <- file.path(project_root, "output", "goal1_reverse_engineer_test.html")
html <- paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
swapped_html <- sub(
  'data-name="Haut-Uele"',
  'data-name="Ituri"',
  html,
  fixed = TRUE
)
if (identical(swapped_html, html)) {
  stop("Negative-control fixture could not find Haut-Uele in the rendered map.", call. = FALSE)
}

failure <- try(
  validate_map_build(
    project_root = project_root,
    online = FALSE,
    verbose = FALSE,
    html_text = swapped_html
  ),
  silent = TRUE
)
if (!inherits(failure, "try-error")) {
  stop("Negative control failed: an intentionally swapped area label passed validation.", call. = FALSE)
}
if (!grepl("does not point to its own geometry", as.character(failure), fixed = TRUE)) {
  stop("Negative control failed for an unexpected reason: ", as.character(failure), call. = FALSE)
}

cat("Negative control passed: an intentionally swapped Haut-Uele/Ituri label was rejected.\n")
