packages <- c("rdhs", "dplyr", "tibble", "purrr", "survey", "haven",
  "tidyr", "readr", "readxl", "ggplot2", "scales", "knitr", "rmarkdown",
  "minpack.lm", "rstan", "stringr", "brms", "posterior", "ggrepel")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
