build_worsening_threshold_distribution <- function(reports) {
  pieces <- list()
  piece_index <- 0L
  classification_labels <- c(
    improving = "Improving",
    inside_threshold = "Non-significant change",
    worsening = "Worsening",
    no_data = "No data"
  )

  for (country in names(reports)) {
    report <- reports[[country]]
    for (indicator_id in report$definitions$id) {
      definition <- report$definitions[report$definitions$id == indicator_id, , drop = FALSE]
      rows <- report$classifications[
        report$classifications$indicator == indicator_id,
        ,
        drop = FALSE
      ]
      ranking_rows <- report$indicators[
        report$indicators$indicator == indicator_id,
        c("admin_name", "prevalence_rank", "change_rank"),
        drop = FALSE
      ]
      rows <- merge(rows, ranking_rows, by = "admin_name", all.x = TRUE, sort = FALSE)
      rows <- rows[order(rows$risk_change, rows$admin_name), , drop = FALSE]
      threshold <- as.numeric(report$thresholds[[indicator_id]])
      piece_index <- piece_index + 1L
      pieces[[piece_index]] <- data.frame(
        country = country,
        admin_level = "ADM1",
        indicator = indicator_id,
        indicator_label = definition$label,
        direction = definition$direction,
        distribution_order_improving_to_worsening = seq_len(nrow(rows)),
        absolute_change_distribution_rank = rank(abs(rows$risk_change), ties.method = "min"),
        areas_in_country_indicator_distribution = nrow(rows),
        admin_name = rows$admin_name,
        latest_year = as.integer(rows$latest_year),
        observed_latest_estimate = as.numeric(rows$latest_estimate),
        prevalence_rank = as.numeric(rows$prevalence_rank),
        change_rank = as.numeric(rows$change_rank),
        risk_aligned_change_pp = as.numeric(rows$risk_change),
        absolute_risk_aligned_change_pp = abs(as.numeric(rows$risk_change)),
        threshold_percentile = 0.25,
        quantile_type = 7L,
        threshold_t_pp = threshold,
        improving_cutoff_pp = -threshold,
        worsening_cutoff_pp = threshold,
        classification = rows$classification,
        classification_label = unname(classification_labels[rows$classification]),
        improving_count_contribution = as.integer(rows$classification == "improving"),
        non_significant_count_contribution = as.integer(rows$classification == "inside_threshold"),
        worsening_count_contribution = as.integer(rows$classification == "worsening"),
        risk_alignment_note = "Positive means worsening; signs for beneficial coverage indicators are reversed",
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, pieces)
}

write_worsening_threshold_distribution <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}

validate_worsening_threshold_distribution <- function(data, reports, tolerance = 1e-10) {
  expected_rows <- sum(vapply(reports, function(report) nrow(report$classifications), integer(1)))
  if (nrow(data) != expected_rows) {
    stop("Threshold distribution expected ", expected_rows, " rows but found ", nrow(data), call. = FALSE)
  }
  if (anyDuplicated(data[c("country", "indicator", "admin_name")])) {
    stop("Threshold distribution contains duplicate country-indicator-area rows.", call. = FALSE)
  }
  if (!all(data$classification %in% c("improving", "inside_threshold", "worsening"))) {
    stop("Threshold distribution contains an unsupported classification.", call. = FALSE)
  }
  for (country in names(reports)) {
    report <- reports[[country]]
    for (indicator_id in report$definitions$id) {
      rows <- data[data$country == country & data$indicator == indicator_id, , drop = FALSE]
      expected_n <- report$rank_max
      if (nrow(rows) != expected_n || any(rows$areas_in_country_indicator_distribution != expected_n)) {
        stop(country, " ", indicator_id, " distribution has the wrong area count.", call. = FALSE)
      }
      expected_threshold <- as.numeric(stats::quantile(
        abs(rows$risk_aligned_change_pp), probs = 0.25, type = 7, na.rm = TRUE
      ))
      if (any(abs(rows$threshold_t_pp - expected_threshold) > tolerance)) {
        stop(country, " ", indicator_id, " threshold does not equal the type-7 25th percentile.", call. = FALSE)
      }
      expected_classification <- ifelse(
        rows$risk_aligned_change_pp < -expected_threshold,
        "improving",
        ifelse(rows$risk_aligned_change_pp > expected_threshold, "worsening", "inside_threshold")
      )
      if (!identical(as.character(rows$classification), expected_classification)) {
        stop(country, " ", indicator_id, " classifications do not match the threshold distribution.", call. = FALSE)
      }
      if (!identical(rows$distribution_order_improving_to_worsening, seq_len(nrow(rows)))) {
        stop(country, " ", indicator_id, " distribution order is not improving-to-worsening.", call. = FALSE)
      }
      if (is.unsorted(rows$risk_aligned_change_pp, strictly = FALSE)) {
        stop(country, " ", indicator_id, " risk-aligned changes are not sorted.", call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}
