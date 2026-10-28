# Parse scripts and Rmd chunks without executing downloads or MCMC.
paths <- list.files(".", pattern = "\\.(R|Rmd)$", recursive = TRUE, full.names = TRUE)
paths <- paths[!grepl("/(work|output)/", paths)]
for (path in paths) {
  if (grepl("\\.Rmd$", path)) {
    extracted <- tempfile(fileext = ".R")
    knitr::purl(path, output = extracted, documentation = 0, quiet = TRUE)
    parse(extracted)
    unlink(extracted)
  } else parse(path)
}
cat("R syntax passed for", length(paths), "files\n")
