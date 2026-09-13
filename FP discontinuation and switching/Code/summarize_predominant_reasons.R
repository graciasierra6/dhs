# Summarize the leading reasons for discontinuation by method and horizon.
#
# This script is called automatically by run_discontinuation_analysis.R. It can
# also be sourced after setting the `ethiopia_discontinuation_project_dir`
# option. The summary ranks only the nine mutually exclusive reasons. It
# deliberately excludes `Any reason` and switching because neither is an
# individual competing cause.

project_dir <- getOption("ethiopia_discontinuation_project_dir")
if (is.null(project_dir)) {
  stop(
    "Run code/run_discontinuation_analysis.R rather than sourcing this file alone.",
    call. = FALSE
  )
}

source_file <- file.path(
  project_dir,
  "Analyses",
  "derived",
  "competing_risk_reasons_3_6_9_12_months.csv"
)
output_file <- file.path(
  project_dir,
  "Analyses",
  "derived",
  "reason_predominance_by_method_and_horizon.csv"
)

if (!file.exists(source_file)) {
  stop("Missing reason-specific results: ", source_file, call. = FALSE)
}

reason_results <- read.csv(source_file, check.names = FALSE)
reason_columns <- c(
  "Method failure",
  "Desire to become pregnant",
  "Other fertility-related reasons",
  "Changes in menstrual bleeding",
  "Other side effects/health concerns",
  "Wanted more effective method",
  "Other method-related reasons",
  "Husband/partner disapproved",
  "Other reasons"
)

missing_columns <- setdiff(
  c("Duration", "Method", reason_columns),
  names(reason_results)
)
if (length(missing_columns) > 0L) {
  stop(
    "Reason results are missing required columns: ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

summary_rows <- lapply(seq_len(nrow(reason_results)), function(i) {
  values <- unlist(reason_results[i, reason_columns], use.names = TRUE)
  values <- as.numeric(values)
  names(values) <- reason_columns
  ranked <- sort(values, decreasing = TRUE, na.last = TRUE)

  data.frame(
    Duration = reason_results$Duration[i],
    Method = reason_results$Method[i],
    `Leading reason` = names(ranked)[1],
    `Leading cumulative incidence (%)` = unname(ranked[1]),
    `Second reason` = names(ranked)[2],
    `Second cumulative incidence (%)` = unname(ranked[2]),
    `Third reason` = names(ranked)[3],
    `Third cumulative incidence (%)` = unname(ranked[3]),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
})

reason_summary <- do.call(rbind, summary_rows)
write.csv(reason_summary, output_file, row.names = FALSE)
message("Created reason predominance summary: ", output_file)
