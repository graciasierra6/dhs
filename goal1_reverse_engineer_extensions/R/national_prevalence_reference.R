read_national_prevalence_reference <- function(path, indicator_rows) {
  if (!file.exists(path)) stop("Missing national prevalence reference file: ", path, call. = FALSE)
  reference <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8")
  required <- c(
    "country", "indicator", "survey_year", "national_prevalence", "source_type",
    "report_title", "report_id", "table_id", "table_row", "indicator_definition",
    "report_url", "validation_note"
  )
  missing <- setdiff(required, names(reference))
  if (length(missing)) stop("National prevalence reference is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)

  reference$country <- trimws(reference$country)
  reference$indicator <- trimws(reference$indicator)
  reference$survey_year <- suppressWarnings(as.integer(reference$survey_year))
  reference$national_prevalence <- suppressWarnings(as.numeric(reference$national_prevalence))
  reference$country_slug <- tolower(reference$country)
  reference$country_slug[reference$country_slug == "drc"] <- "drc"

  expected <- unique(indicator_rows[c("country", "indicator", "latestYear")])
  names(expected)[names(expected) == "latestYear"] <- "survey_year"
  expected$key <- paste(expected$country, expected$indicator, sep = "|")
  reference$key <- paste(reference$country_slug, reference$indicator, sep = "|")

  if (anyDuplicated(reference$key)) {
    stop("Duplicate country-indicator rows in national prevalence reference: ", paste(unique(reference$key[duplicated(reference$key)]), collapse = ", "), call. = FALSE)
  }
  missing_keys <- setdiff(expected$key, reference$key)
  extra_keys <- setdiff(reference$key, expected$key)
  if (length(missing_keys) || length(extra_keys)) {
    stop(
      "National prevalence coverage mismatch. Missing: ", paste(missing_keys, collapse = ", "),
      "; extra: ", paste(extra_keys, collapse = ", "), call. = FALSE
    )
  }
  reference <- reference[match(expected$key, reference$key), , drop = FALSE]
  if (any(reference$survey_year != expected$survey_year)) {
    bad <- expected$key[reference$survey_year != expected$survey_year]
    stop("National reference year does not match the displayed latest year: ", paste(bad, collapse = ", "), call. = FALSE)
  }
  if (any(!is.finite(reference$national_prevalence)) || any(reference$national_prevalence < 0 | reference$national_prevalence > 100)) {
    stop("National prevalence values must be finite percentages from 0 to 100.", call. = FALSE)
  }
  provenance_columns <- c("source_type", "report_title", "report_id", "table_id", "table_row", "indicator_definition", "report_url", "validation_note")
  if (any(vapply(reference[provenance_columns], function(column) any(!nzchar(trimws(column))), logical(1)))) {
    stop("Every national prevalence row must have complete source and validation provenance.", call. = FALSE)
  }

  output <- data.frame(
    country = reference$country_slug,
    indicator = reference$indicator,
    latestYear = reference$survey_year,
    nationalPrevalence = reference$national_prevalence,
    sourceType = reference$source_type,
    reportTitle = reference$report_title,
    reportId = reference$report_id,
    tableId = reference$table_id,
    tableRow = reference$table_row,
    indicatorDefinition = reference$indicator_definition,
    reportUrl = reference$report_url,
    validationNote = reference$validation_note,
    stringsAsFactors = FALSE
  )
  rownames(output) <- NULL
  output
}
