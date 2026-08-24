validate_risk_alignment <- function(reports, tolerance = 1e-7) {
  audit_rows <- list()
  audit_index <- 0L
  total_pairs <- 0L

  for (country in names(reports)) {
    report <- reports[[country]]
    country_areas <- sort(unique(report$indicators$admin_name))
    definitions <- report$definitions

    indicator_pairs <- utils::combn(definitions$id, 2L)
    total_pairs <- total_pairs + ncol(indicator_pairs)
    for (pair_index in seq_len(ncol(indicator_pairs))) {
      pair <- indicator_pairs[, pair_index]
      paired_areas <- Reduce(intersect, lapply(pair, function(indicator_id) {
        report$indicators$admin_name[report$indicators$indicator == indicator_id]
      }))
      if (!identical(sort(paired_areas), country_areas)) {
        stop(
          country, " bivariate pair ", paste(pair, collapse = " + "),
          " does not contain exactly one record for every mapped area.", call. = FALSE
        )
      }
    }

    for (indicator_id in definitions$id) {
      definition <- definitions[definitions$id == indicator_id, , drop = FALSE]
      rows <- report$indicators[report$indicators$indicator == indicator_id, , drop = FALSE]
      rows <- rows[order(rows$admin_name), , drop = FALSE]
      if (nrow(rows) != report$rank_max || !identical(sort(rows$admin_name), country_areas)) {
        stop(country, " ", indicator_id, " does not contain one record per mapped area.", call. = FALSE)
      }
      if (!identical(unique(as.character(rows$direction)), definition$direction)) {
        stop(
          country, " ", indicator_id, " source direction is not exactly ",
          definition$direction, ".", call. = FALSE
        )
      }

      raw_change <- rows$observed_latest_estimate - rows$baseline_estimate
      source_raw_change <- as.numeric(rows$pp_change_10yr)
      raw_error <- abs(source_raw_change - raw_change)
      if (any(!is.finite(raw_error)) || max(raw_error) > tolerance) {
        stop(country, " ", indicator_id, " raw change does not equal latest minus baseline.", call. = FALSE)
      }

      expected_risk_change <- if (definition$direction == "beneficial") -raw_change else raw_change
      risk_error <- abs(rows$pp_change_10yr_recoded - expected_risk_change)
      if (any(!is.finite(risk_error)) || max(risk_error) > tolerance) {
        stop(country, " ", indicator_id, " is not correctly risk aligned.", call. = FALSE)
      }

      expected_change_rank <- rank(expected_risk_change, ties.method = "min")
      expected_prevalence_rank <- if (definition$direction == "beneficial") {
        rank(-rows$observed_latest_estimate, ties.method = "min")
      } else {
        rank(rows$observed_latest_estimate, ties.method = "min")
      }
      if (!identical(as.numeric(rows$change_rank), as.numeric(expected_change_rank))) {
        stop(country, " ", indicator_id, " change ranks are not ordered best-to-worst by risk-aligned change.", call. = FALSE)
      }
      if (!identical(as.numeric(rows$prevalence_rank), as.numeric(expected_prevalence_rank))) {
        stop(country, " ", indicator_id, " prevalence ranks are not risk ordered.", call. = FALSE)
      }

      baseline_inside_ci <- rows$baseline_estimate >= rows$baseline_ci_l - tolerance &
        rows$baseline_estimate <= rows$baseline_ci_u + tolerance
      latest_inside_ci <- rows$observed_latest_estimate >= rows$latest_ci_l - tolerance &
        rows$observed_latest_estimate <= rows$latest_ci_u + tolerance
      if (any(!baseline_inside_ci) || any(!latest_inside_ci)) {
        stop(country, " ", indicator_id, " profile endpoint estimate falls outside its 95% CI.", call. = FALSE)
      }

      threshold <- as.numeric(stats::quantile(abs(expected_risk_change), 0.25, type = 7))
      expected_classification <- ifelse(
        expected_risk_change < -threshold,
        "improving",
        ifelse(expected_risk_change > threshold, "worsening", "inside_threshold")
      )
      classification_rows <- report$classifications[
        report$classifications$indicator == indicator_id,
        ,
        drop = FALSE
      ]
      classification_rows <- classification_rows[
        match(rows$admin_name, classification_rows$admin_name),
        ,
        drop = FALSE
      ]
      if (anyNA(classification_rows$admin_name) ||
          max(abs(classification_rows$risk_change - expected_risk_change)) > tolerance ||
          !identical(as.character(classification_rows$classification), expected_classification)) {
        stop(country, " ", indicator_id, " threshold classifications are not risk aligned.", call. = FALSE)
      }

      audit_index <- audit_index + 1L
      audit_rows[[audit_index]] <- data.frame(
        country = country,
        indicator = indicator_id,
        direction = definition$direction,
        areas = nrow(rows),
        baseline_year = unique(rows$baseline_year),
        latest_year = unique(rows$latest_year),
        threshold_t_pp = threshold,
        maximum_raw_change_error = max(raw_error),
        maximum_risk_alignment_error = max(risk_error),
        improving = sum(expected_classification == "improving"),
        non_significant = sum(expected_classification == "inside_threshold"),
        worsening = sum(expected_classification == "worsening"),
        stringsAsFactors = FALSE
      )
    }

    for (admin_name in country_areas) {
      rows <- report$classifications[report$classifications$admin_name == admin_name, , drop = FALSE]
      detail <- report$summary[[which(vapply(
        report$summary, function(item) identical(item$admin_name, admin_name), logical(1)
      ))]]
      expected_counts <- c(
        worsening = sum(rows$classification == "worsening"),
        improving = sum(rows$classification == "improving"),
        non_significant = sum(rows$classification == "inside_threshold")
      )
      actual_counts <- c(
        worsening = detail$worsening_count,
        improving = detail$improving_count,
        non_significant = detail$inside_threshold_count
      )
      if (!identical(as.numeric(actual_counts), as.numeric(expected_counts)) ||
          sum(actual_counts) != report$indicator_count) {
        stop(country, " ", admin_name, " worsening-count summary is inconsistent.", call. = FALSE)
      }
    }
  }

  result <- do.call(rbind, audit_rows)
  attr(result, "indicator_rows") <- sum(result$areas)
  attr(result, "bivariate_pairs") <- total_pairs
  result
}
