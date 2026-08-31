worsening_count_validation_check <- function(condition, message, state) {
  if (!isTRUE(condition)) {
    stop("Worsening-count validation failed: ", message, call. = FALSE)
  }
  state$checks <- state$checks + 1L
  invisible(TRUE)
}

worsening_count_section <- function(html, section_id) {
  pattern <- paste0('(?s)<section id="', section_id, '".*?</section>')
  section <- regmatches(html, regexpr(pattern, html, perl = TRUE))
  if (length(section) != 1L || !nzchar(section)) {
    stop("Worsening-count validation failed: rendered section is missing: ", section_id, call. = FALSE)
  }
  section
}

worsening_count_legend_colors <- function(section) {
  pattern <- '<span><i style="background:#[0-9A-Fa-f]{6}"></i>[^<]+</span>'
  entries <- regmatches(section, gregexpr(pattern, section, perl = TRUE))[[1]]
  if (identical(entries, -1L) || length(entries) != 4L) {
    stop("Worsening-count validation failed: count-map legend does not have four categories.", call. = FALSE)
  }
  colors <- sub('.*background:(#[0-9A-Fa-f]{6}).*', '\\1', entries, perl = TRUE)
  labels <- sub('.*</i>([^<]+)</span>', '\\1', entries, perl = TRUE)
  codes <- gsub("[^0-9]", "", labels)
  codes[codes == "1"] <- "01"
  if (!setequal(codes, c("01", "23", "4", "56")) || anyDuplicated(codes) || anyDuplicated(colors)) {
    stop("Worsening-count validation failed: count-map legend categories or colors are ambiguous.", call. = FALSE)
  }
  stats::setNames(colors, codes)
}

worsening_count_code <- function(value) {
  value <- as.integer(value)
  if (value < 0L || value > 6L) {
    stop("Worsening-count validation failed: count is outside the configured 0-6 legend range.", call. = FALSE)
  }
  if (value <= 1L) return("01")
  if (value <= 3L) return("23")
  if (value == 4L) return("4")
  "56"
}

worsening_count_region <- function(section, admin_name) {
  marker <- paste0('data-name="', html_attr(admin_name), '"')
  start <- regexpr(marker, section, fixed = TRUE)[1]
  if (start < 0L) {
    stop("Worsening-count validation failed: count map is missing ", admin_name, call. = FALSE)
  }
  remainder <- substr(section, start, nchar(section))
  finish <- regexpr("></use>", remainder, fixed = TRUE)[1]
  if (finish < 0L) {
    stop("Worsening-count validation failed: count-map region is incomplete: ", admin_name, call. = FALSE)
  }
  substr(remainder, 1L, finish + nchar("></use>") - 1L)
}

validate_worsening_count_maps <- function(
  reports,
  distribution,
  html_text = NULL,
  html_path = NULL,
  tolerance = 1e-10,
  verbose = TRUE
) {
  state <- new.env(parent = emptyenv())
  state$checks <- 0L
  check <- function(condition, message) worsening_count_validation_check(condition, message, state)

  if (is.null(html_text)) {
    check(!is.null(html_path) && file.exists(html_path), "rendered dashboard HTML is missing")
    html <- paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  } else {
    html <- paste(as.character(html_text), collapse = "\n")
  }

  required <- c(
    "country", "indicator", "indicator_label", "admin_name", "risk_aligned_change_pp",
    "threshold_t_pp", "classification", "improving_count_contribution",
    "non_significant_count_contribution", "worsening_count_contribution"
  )
  check(all(required %in% names(distribution)), "threshold distribution is missing required fields")
  check(nrow(distribution) == 581L, "threshold distribution must contain 581 area-indicator rows")
  check(!anyDuplicated(distribution[c("country", "indicator", "admin_name")]), "threshold distribution contains duplicate keys")

  indicator_audits <- list()
  independent_rows <- list()
  indicator_index <- 0L
  independent_index <- 0L

  for (country in names(reports)) {
    report <- reports[[country]]
    for (indicator_id in report$definitions$id) {
      source_rows <- report$indicators[
        report$indicators$indicator == indicator_id,
        c("admin_name", "pp_change_10yr_recoded"),
        drop = FALSE
      ]
      rows <- distribution[
        distribution$country == country & distribution$indicator == indicator_id,
        ,
        drop = FALSE
      ]
      rows <- merge(rows, source_rows, by = "admin_name", all = TRUE, sort = FALSE)
      check(nrow(rows) == report$rank_max, paste(country, indicator_id, "does not have one row per mapped area"))
      check(
        !anyNA(rows$pp_change_10yr_recoded) && !anyNA(rows$risk_aligned_change_pp),
        paste(country, indicator_id, "has an unmatched or missing risk-aligned change")
      )
      change_error <- max(abs(rows$risk_aligned_change_pp - rows$pp_change_10yr_recoded))
      check(
        is.finite(change_error) && change_error <= tolerance,
        paste(country, indicator_id, "audit changes differ from the source rankings")
      )

      threshold <- as.numeric(stats::quantile(
        abs(rows$pp_change_10yr_recoded),
        probs = 0.25,
        type = 7,
        na.rm = FALSE
      ))
      expected_classification <- ifelse(
        rows$pp_change_10yr_recoded < -threshold,
        "improving",
        ifelse(rows$pp_change_10yr_recoded > threshold, "worsening", "inside_threshold")
      )
      check(
        all(abs(rows$threshold_t_pp - threshold) <= tolerance),
        paste(country, indicator_id, "does not use its own type-7 25th-percentile threshold")
      )
      check(
        identical(as.character(rows$classification), expected_classification),
        paste(country, indicator_id, "improving/worsening classifications are incorrect")
      )
      check(
        identical(as.integer(rows$improving_count_contribution), as.integer(expected_classification == "improving")) &&
          identical(as.integer(rows$non_significant_count_contribution), as.integer(expected_classification == "inside_threshold")) &&
          identical(as.integer(rows$worsening_count_contribution), as.integer(expected_classification == "worsening")),
        paste(country, indicator_id, "binary count contributions are incorrect")
      )

      definition <- report$definitions[report$definitions$id == indicator_id, , drop = FALSE]
      indicator_index <- indicator_index + 1L
      indicator_audits[[indicator_index]] <- data.frame(
        country = country,
        indicator = indicator_id,
        indicator_label = definition$label,
        areas = nrow(rows),
        threshold_t_pp = threshold,
        improving = sum(expected_classification == "improving"),
        non_significant = sum(expected_classification == "inside_threshold"),
        worsening = sum(expected_classification == "worsening"),
        maximum_change_error = change_error,
        stringsAsFactors = FALSE
      )

      independent_index <- independent_index + 1L
      independent_rows[[independent_index]] <- data.frame(
        country = country,
        admin_name = rows$admin_name,
        indicator = indicator_id,
        indicator_label = definition$label,
        indicator_order = match(indicator_id, report$definitions$id),
        classification = expected_classification,
        stringsAsFactors = FALSE
      )
    }
  }

  indicator_audit <- do.call(rbind, indicator_audits)
  independent <- do.call(rbind, independent_rows)
  rownames(indicator_audit) <- NULL
  rownames(independent) <- NULL
  check(nrow(indicator_audit) == 23L, "expected 23 country-indicator distributions")
  check(nrow(independent) == 581L, "expected 581 independently classified area-indicator rows")

  area_audits <- list()
  area_index <- 0L
  for (country in names(reports)) {
    report <- reports[[country]]
    section <- worsening_count_section(html, paste0(report$slug, "-counts"))
    legend_colors <- worsening_count_legend_colors(section)
    report_summary <- stats::setNames(
      report$summary,
      vapply(report$summary, `[[`, character(1), "admin_name")
    )
    country_rows <- independent[independent$country == country, , drop = FALSE]
    for (admin_name in sort(unique(country_rows$admin_name))) {
      rows <- country_rows[country_rows$admin_name == admin_name, , drop = FALSE]
      rows <- rows[order(rows$indicator_order), , drop = FALSE]
      worsening_labels <- rows$indicator_label[rows$classification == "worsening"]
      improving_labels <- rows$indicator_label[rows$classification == "improving"]
      non_significant_labels <- rows$indicator_label[rows$classification == "inside_threshold"]
      worsening_count <- length(worsening_labels)
      improving_count <- length(improving_labels)
      non_significant_count <- length(non_significant_labels)
      check(
        worsening_count + improving_count + non_significant_count == report$indicator_count,
        paste(country, admin_name, "classification counts do not sum to the available indicators")
      )

      detail <- report_summary[[admin_name]]
      check(!is.null(detail), paste(country, admin_name, "is missing from the report count summary"))
      check(
        identical(as.integer(c(worsening_count, improving_count, non_significant_count)), as.integer(c(
          detail$worsening_count, detail$improving_count, detail$inside_threshold_count
        ))),
        paste(country, admin_name, "report counts differ from the independent distributions")
      )
      check(
        identical(as.character(worsening_labels), as.character(detail$worsening_indicators)) &&
          identical(as.character(improving_labels), as.character(detail$improving_indicators)) &&
          identical(as.character(non_significant_labels), as.character(detail$inside_threshold_indicators)),
        paste(country, admin_name, "report indicator membership differs from the independent distributions")
      )

      region <- worsening_count_region(section, admin_name)
      tip_match <- regmatches(region, regexpr('data-tip="[^"]*"', region, perl = TRUE))
      check(
        length(tip_match) == 1L && nzchar(tip_match),
        paste(country, admin_name, "rendered tooltip is missing")
      )
      tip_text <- sub('^data-tip="', "", tip_match)
      tip_text <- sub('"$', "", tip_text)
      tip_lines <- strsplit(tip_text, "\n", fixed = TRUE)[[1]]
      check(
        length(tip_lines) == 4L && identical(tip_lines[[1]], html_attr(admin_name)),
        paste(country, admin_name, "rendered tooltip area name or structure is incorrect")
      )
      tooltip_groups <- list(
        list(count = worsening_count, label = "Worsening", indicators = worsening_labels),
        list(count = improving_count, label = "Improving", indicators = improving_labels),
        list(count = non_significant_count, label = "Non-significant change", indicators = non_significant_labels)
      )
      for (group_index in seq_along(tooltip_groups)) {
        group <- tooltip_groups[[group_index]]
        prefix <- paste0(group$count, " ", group$label, ": ")
        line <- tip_lines[[group_index + 1L]]
        check(
          startsWith(line, prefix),
          paste(country, admin_name, "rendered", group$label, "count is incorrect")
        )
        actual_text <- substring(line, nchar(prefix) + 1L)
        actual_indicators <- if (identical(actual_text, "None")) character() else {
          strsplit(actual_text, ", ", fixed = TRUE)[[1]]
        }
        expected_indicators <- html_attr(group$indicators)
        check(
          identical(sort(actual_indicators), sort(expected_indicators)),
          paste(country, admin_name, "rendered", group$label, "indicator membership is incorrect")
        )
      }
      bucket_code <- worsening_count_code(worsening_count)
      expected_fill <- legend_colors[[bucket_code]]
      check(
        grepl(paste0('fill="', expected_fill, '"'), region, fixed = TRUE),
        paste(country, admin_name, "rendered fill does not match its worsening-count legend bucket")
      )

      area_index <- area_index + 1L
      area_audits[[area_index]] <- data.frame(
        country = country,
        admin_name = admin_name,
        available_indicators = report$indicator_count,
        improving_count = improving_count,
        non_significant_count = non_significant_count,
        worsening_count = worsening_count,
        legend_bucket = bucket_code,
        rendered_fill = expected_fill,
        stringsAsFactors = FALSE
      )
    }
  }

  area_audit <- do.call(rbind, area_audits)
  rownames(area_audit) <- NULL
  check(nrow(area_audit) == 74L, "expected 74 independently audited count-map areas")
  check(
    identical(as.integer(table(area_audit$country)[c("DRC", "Ethiopia", "Nigeria")]), c(26L, 11L, 37L)),
    "count-map country coverage is incorrect"
  )

  if (isTRUE(verbose)) {
    cat(
      "Worsening-count map validation passed:", state$checks, "checks;",
      nrow(indicator_audit), "country-indicator distributions;",
      nrow(independent), "independent classifications;",
      nrow(area_audit), "rendered ADM1 count-map areas.\n"
    )
  }
  invisible(list(
    checks = state$checks,
    indicators = indicator_audit,
    areas = area_audit
  ))
}
