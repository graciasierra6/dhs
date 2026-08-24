reference_read_utf8 <- function(path) {
  if (!file.exists(path)) stop("Missing required file: ", path, call. = FALSE)
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

reference_slug <- function(country) {
  value <- country_configuration$slug[match(country, country_configuration$country)]
  if (is.na(value)) stop("No country slug configured for: ", country, call. = FALSE)
  value
}

reference_payloads_from_reports <- function(reports) {
  indicator_rows <- do.call(rbind, lapply(names(reports), function(country) {
    rows <- reports[[country]]$indicators
    data.frame(
      country = reference_slug(country),
      indicator = rows$indicator,
      direction = rows$direction,
      adminLevel = rows$admin_level,
      adminName = rows$admin_name,
      latestYear = as.integer(rows$latest_year),
      baselineYear = as.integer(rows$baseline_year),
      baselineEstimate = as.numeric(rows$baseline_estimate),
      observedLatestEstimate = as.numeric(rows$observed_latest_estimate),
      ppChange10yr = as.numeric(rows$pp_change_10yr),
      ppChange10yrRecoded = as.numeric(rows$pp_change_10yr_recoded),
      changeRank = as.numeric(rows$change_rank),
      prevalenceRank = as.numeric(rows$prevalence_rank),
      stringsAsFactors = FALSE
    )
  }))

  classification_codes <- c(improving = 1L, inside_threshold = 2L, worsening = 3L, no_data = 0L)
  classifications <- do.call(rbind, lapply(names(reports), function(country) {
    report <- reports[[country]]
    rows <- report$classifications
    data.frame(
      country = reference_slug(country),
      adminName = rows$admin_name,
      indicator = rows$indicator,
      indicatorLabel = rows$label,
      classification = rows$classification,
      classificationCode = unname(classification_codes[rows$classification]),
      observedLatestEstimate = as.numeric(rows$latest_estimate),
      latestYear = as.integer(rows$latest_year),
      ppChange10yrRecoded = as.numeric(rows$risk_change),
      thresholdT = as.numeric(report$thresholds[rows$indicator]),
      source = "Rebuilt from count_map_input_combined_master.csv using the documented Goal 1 pipeline",
      stringsAsFactors = FALSE
    )
  }))

  list(indicator_rows = indicator_rows, classifications = classifications)
}

reference_sort_frame <- function(data, keys) {
  order_columns <- lapply(keys, function(key) as.character(data[[key]]))
  data[do.call(order, order_columns), , drop = FALSE]
}

reference_compare_frames <- function(expected, actual, keys, text_fields, numeric_fields, tolerance = 1e-7) {
  required <- unique(c(keys, text_fields, numeric_fields))
  missing_expected <- setdiff(required, names(expected))
  missing_actual <- setdiff(required, names(actual))
  if (length(missing_expected) || length(missing_actual)) {
    stop(
      "Reference comparison is missing fields. Expected frame: ", paste(missing_expected, collapse = ", "),
      "; reference frame: ", paste(missing_actual, collapse = ", "), call. = FALSE
    )
  }
  expected <- reference_sort_frame(expected, keys)
  actual <- reference_sort_frame(actual, keys)
  if (nrow(expected) != nrow(actual)) {
    stop("Reference row count mismatch: expected ", nrow(expected), ", found ", nrow(actual), call. = FALSE)
  }
  expected_key <- do.call(paste, c(expected[keys], sep = "\r"))
  actual_key <- do.call(paste, c(actual[keys], sep = "\r"))
  if (!identical(expected_key, actual_key)) {
    missing <- setdiff(expected_key, actual_key)
    extra <- setdiff(actual_key, expected_key)
    stop(
      "Reference keys do not match source data. Missing: ", paste(head(missing, 10L), collapse = ", "),
      "; extra: ", paste(head(extra, 10L), collapse = ", "), call. = FALSE
    )
  }
  for (field in text_fields) {
    mismatched <- which(as.character(expected[[field]]) != as.character(actual[[field]]))
    if (length(mismatched)) {
      stop("Reference text mismatch in ", field, " for ", expected_key[mismatched[1]], call. = FALSE)
    }
  }
  for (field in numeric_fields) {
    difference <- abs(as.numeric(expected[[field]]) - as.numeric(actual[[field]]))
    mismatched <- which(!is.finite(difference) | difference > tolerance)
    if (length(mismatched)) {
      index <- mismatched[1]
      stop(
        "Reference numeric mismatch in ", field, " for ", expected_key[index],
        ": source=", expected[[field]][index], ", reference=", actual[[field]][index], call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

reference_extract_section <- function(html, id) {
  start_marker <- paste0('<section id="', id, '"')
  start <- regexpr(start_marker, html, fixed = TRUE)[1]
  if (start < 0L) stop("Missing reference section: ", id, call. = FALSE)
  remainder <- substr(html, start, nchar(html))
  finish <- regexpr("</section>", remainder, fixed = TRUE)[1]
  if (finish < 0L) stop("Unclosed reference section: ", id, call. = FALSE)
  substr(remainder, 1L, finish + nchar("</section>") - 1L)
}

reference_fixed_count <- function(pattern, text) {
  positions <- gregexpr(pattern, text, fixed = TRUE)[[1]]
  if (length(positions) == 1L && positions[1] < 0L) 0L else length(positions)
}

reference_validate_tab_panel_structure <- function(html) {
  main_start <- regexpr("<main", html, fixed = TRUE)[1]
  if (main_start < 0L) stop("Dashboard is missing its main content container.", call. = FALSE)
  main_remainder <- substr(html, main_start, nchar(html))
  main_finish <- regexpr("</main>", main_remainder, fixed = TRUE)[1]
  if (main_finish < 0L) stop("Dashboard main content container is not closed.", call. = FALSE)
  main_html <- substr(main_remainder, 1L, main_finish + nchar("</main>") - 1L)

  tokens <- regmatches(main_html, gregexpr("<div\\b[^>]*>|</div>", main_html, perl = TRUE))[[1]]
  stack <- list()
  panels <- character()
  for (token in tokens) {
    if (identical(token, "</div>")) {
      if (!length(stack)) stop("Dashboard contains an unmatched closing div.", call. = FALSE)
      stack <- stack[-length(stack)]
      next
    }

    is_panel <- grepl('class="[^"]*\\btab-panel\\b', token, perl = TRUE)
    if (is_panel && any(vapply(stack, function(entry) isTRUE(entry$is_panel), logical(1)))) {
      stop("A tab panel is nested inside another tab panel; inactive parent tabs would hide it.", call. = FALSE)
    }
    if (is_panel) {
      country <- sub('.*data-country="([^"]+)".*', '\\1', token, perl = TRUE)
      tab <- sub('.*data-tab-panel="([^"]+)".*', '\\1', token, perl = TRUE)
      if (identical(country, token) || identical(tab, token)) {
        stop("A tab panel is missing its country or tab identifier.", call. = FALSE)
      }
      panels <- c(panels, paste(country, tab, sep = "|"))
    }
    stack[[length(stack) + 1L]] <- list(is_panel = is_panel)
  }
  if (length(stack)) stop("Dashboard contains an unclosed div in its main content.", call. = FALSE)

  expected <- as.vector(outer(c("drc", "ethiopia", "nigeria"), c("overview", "bivariate"), paste, sep = "|"))
  if (!identical(sort(panels), sort(expected))) {
    stop(
      "Dashboard tab panels do not match the three countries and two required tabs. Found: ",
      paste(panels, collapse = ", "), call. = FALSE
    )
  }
  invisible(TRUE)
}

reference_validate_rank_maps <- function(reports, html) {
  for (country in names(reports)) {
    report <- reports[[country]]
    slug <- reference_slug(country)
    for (kind in c("prevalence", "change")) {
      section <- reference_extract_section(html, paste0(slug, "-", kind))
      rank_field <- paste0("composite_", kind, "_rank")
      score_field <- paste0("composite_", kind, "_score")
      if (reference_fixed_count('<use class="map-region', section) != report$rank_max) {
        stop(country, " ", kind, " map does not contain the expected number of areas.", call. = FALSE)
      }
      for (index in seq_len(nrow(report$composite))) {
        row <- report$composite[index, , drop = FALSE]
        expected_tip <- paste(
          row$admin_name,
          paste0("Rank ", row[[rank_field]], " / ", report$rank_max),
          paste0("Composite score ", formatC(row[[score_field]], format = "f", digits = 3)),
          sep = "\n"
        )
        if (!grepl(html_attr(expected_tip), section, fixed = TRUE)) {
          stop(country, " ", kind, " map differs from source data for ", row$admin_name, call. = FALSE)
        }
      }
    }
  }
  invisible(TRUE)
}

reference_validate_count_map <- function(report, html) {
  section <- reference_extract_section(html, "drc-counts")
  if (reference_fixed_count('<use class="map-region', section) != report$rank_max) {
    stop("DRC count map does not contain 26 provinces.", call. = FALSE)
  }
  for (detail in report$summary) {
    marker <- paste0('data-name="', html_attr(detail$admin_name), '"')
    start <- regexpr(marker, section, fixed = TRUE)[1]
    if (start < 0L) stop("DRC count map is missing ", detail$admin_name, call. = FALSE)
    remainder <- substr(section, start, nchar(section))
    finish <- regexpr("></use>", remainder, fixed = TRUE)[1]
    if (finish < 0L) stop("DRC count map has an incomplete region for ", detail$admin_name, call. = FALSE)
    region <- substr(remainder, 1L, finish + nchar("></use>") - 1L)
    count_markers <- c(
      paste0(detail$worsening_count, " Worsening:"),
      paste0(detail$improving_count, " Improving:"),
      paste0(detail$inside_threshold_count, " Non-significant change:")
    )
    if (!all(vapply(count_markers, grepl, logical(1), x = region, fixed = TRUE))) {
      stop("DRC count totals differ from source classifications for ", detail$admin_name, call. = FALSE)
    }
    expected_labels <- c(
      detail$worsening_indicators, detail$improving_indicators, detail$inside_threshold_indicators
    )
    if (!all(vapply(html_attr(expected_labels), grepl, logical(1), x = region, fixed = TRUE))) {
      stop("DRC count indicator membership differs from source data for ", detail$admin_name, call. = FALSE)
    }
    expected_fill <- if (detail$worsening_count <= 1L) {
      "#FDE0DD"
    } else if (detail$worsening_count <= 3L) {
      "#FA9FB5"
    } else if (detail$worsening_count == 4L) {
      "#DD3497"
    } else {
      "#49006A"
    }
    if (!grepl(paste0('fill="', expected_fill, '"'), region, fixed = TRUE)) {
      stop("DRC count-map color category differs from its worsening count for ", detail$admin_name, call. = FALSE)
    }
  }
  invisible(TRUE)
}

reference_validate_image_banks <- function(reports, project_root) {
  expected_names <- sort(unlist(lapply(reports, function(report) report$composite$admin_name), use.names = FALSE))
  manifest <- utils::read.csv(
    file.path(project_root, "artifacts", "profile_images_manifest.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    encoding = "UTF-8"
  )
  if (nrow(manifest) != 148L) stop("Expected 148 profile images.", call. = FALSE)
  for (chart_type in c("prevalence", "change")) {
    rows <- manifest[manifest$chart_type == chart_type, , drop = FALSE]
    if (nrow(rows) != 74L || !identical(sort(rows$admin_name), expected_names)) {
      stop(chart_type, " profile image names do not match the 74 dashboard areas.", call. = FALSE)
    }
    if (any(rows$mime_type != "image/png") || any(rows$bytes <= 0) || any(nchar(rows$sha256) != 64L)) {
      stop(chart_type, " profile image manifest contains invalid image metadata.", call. = FALSE)
    }
  }
  for (file in c("profile_images_prevalence.json", "profile_images_change.json")) {
    bank <- jsonlite::fromJSON(file.path(project_root, "artifacts", file), simplifyVector = TRUE)
    if (length(bank) != 74L || !identical(sort(names(bank)), expected_names)) {
      stop(file, " does not contain exactly one image for every dashboard area.", call. = FALSE)
    }
    if (!all(startsWith(as.character(unlist(bank, use.names = FALSE)), "data:image/png;base64,"))) {
      stop(file, " contains a non-embedded image.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

reference_validate_payloads <- function(reports, project_root) {
  generated <- reference_payloads_from_reports(reports)
  reference_indicators <- jsonlite::fromJSON(
    file.path(project_root, "artifacts", "reference_payloads", "indicatorRows.json")
  )
  reference_classifications <- jsonlite::fromJSON(
    file.path(project_root, "artifacts", "reference_payloads", "classifications.json")
  )
  reference_compare_frames(
    generated$indicator_rows,
    reference_indicators,
    keys = c("country", "indicator", "adminName"),
    text_fields = c("direction", "adminLevel"),
    numeric_fields = c(
      "latestYear", "baselineYear", "baselineEstimate", "observedLatestEstimate", "ppChange10yr",
      "ppChange10yrRecoded", "changeRank", "prevalenceRank"
    )
  )
  reference_compare_frames(
    generated$classifications,
    reference_classifications,
    keys = c("country", "indicator", "adminName"),
    text_fields = c("indicatorLabel", "classification"),
    numeric_fields = c("observedLatestEstimate", "latestYear", "ppChange10yrRecoded")
  )
  enriched <- !is.na(reference_classifications$thresholdT)
  if (any(enriched)) {
    reference_compare_frames(
      generated$classifications[generated$classifications$country == "drc", , drop = FALSE],
      reference_classifications[enriched, , drop = FALSE],
      keys = c("country", "indicator", "adminName"),
      text_fields = character(),
      numeric_fields = c("classificationCode", "thresholdT")
    )
  }
  invisible(generated)
}

reference_extract_output_json <- function(html, name, following_name) {
  pattern <- paste0(
    "(?s)const\\s+", name, "\\s*=\\s*(\\[.*?\\]);\\s*const\\s+", following_name
  )
  match <- regexec(pattern, html, perl = TRUE)
  values <- regmatches(html, match)[[1]]
  if (length(values) != 2L) stop("Could not extract rendered JavaScript payload: ", name, call. = FALSE)
  jsonlite::fromJSON(values[[2]])
}

reference_validate_output_payloads <- function(html, reports) {
  generated <- reference_payloads_from_reports(reports)
  output_indicators <- reference_extract_output_json(html, "indicatorRows", "classifications")
  output_classifications <- reference_extract_output_json(html, "classifications", "purpleScale")
  reference_compare_frames(
    generated$indicator_rows,
    output_indicators,
    keys = c("country", "indicator", "adminName"),
    text_fields = c("direction", "adminLevel"),
    numeric_fields = c(
      "latestYear", "baselineYear", "baselineEstimate", "observedLatestEstimate", "ppChange10yr",
      "ppChange10yrRecoded", "changeRank", "prevalenceRank"
    )
  )
  reference_compare_frames(
    generated$classifications,
    output_classifications,
    keys = c("country", "indicator", "adminName"),
    text_fields = c("indicatorLabel", "classification"),
    numeric_fields = c(
      "classificationCode", "observedLatestEstimate", "latestYear", "ppChange10yrRecoded", "thresholdT"
    )
  )
  nigeria_indicators <- output_indicators[output_indicators$country == "nigeria", , drop = FALSE]
  nigeria_classifications <- output_classifications[
    output_classifications$country == "nigeria", , drop = FALSE
  ]
  if (nrow(nigeria_indicators) != 296L || nrow(nigeria_classifications) != 296L) {
    stop("Rendered Nigeria bivariate payload is incomplete.", call. = FALSE)
  }
  invisible(TRUE)
}

reference_validate_html <- function(html, reports, output = FALSE) {
  reference_validate_tab_panel_structure(html)
  required_sections <- c(
    "drc-prevalence", "drc-change", "drc-indicators", "drc-counts", "drc-bivariate",
    "ethiopia-prevalence", "ethiopia-change", "ethiopia-indicators", "ethiopia-bivariate",
    "nigeria-prevalence", "nigeria-change", "nigeria-indicators", "nigeria-bivariate",
    "methods-overview"
  )
  for (id in required_sections) {
    if (!grepl(paste0('id="', id, '"'), html, fixed = TRUE)) stop("Missing section: ", id, call. = FALSE)
  }
  stopifnot(reference_fixed_count("<svg", html) == 14L)
  stopifnot(reference_fixed_count('<use class="map-region', html) == 322L)
  stopifnot(reference_fixed_count("Download CSV file", html) == 1L)
  stopifnot(!grepl("fetch\\s*\\(", html, perl = TRUE))
  stopifnot(!grepl("(?<![A-Za-z])[A-Za-z]:[/\\\\]", html, perl = TRUE))
  stopifnot(!grepl("file:///", html, fixed = TRUE))
  stopifnot(!grepl("<script[^>]+src=", html, perl = TRUE, ignore.case = TRUE))
  marker <- paste0("co", "dex")
  searchable_html <- gsub(
    "data:image/png;base64,[A-Za-z0-9+/=]+", "[embedded image]", html, perl = TRUE
  )
  stopifnot(!grepl(marker, tolower(searchable_html), fixed = TRUE))
  if (output) {
    stopifnot(reference_fixed_count("data:image/png;base64,", html) == 148L)
    stopifnot(!grepl("{{[A-Z_]+}}", html, perl = TRUE))
    stopifnot(grepl("const provinceImagesPrevalence =", html, fixed = TRUE))
    stopifnot(grepl("const provinceImagesChange =", html, fixed = TRUE))
  }
  reference_validate_rank_maps(reports, html)
  reference_validate_count_map(reports[["DRC"]], html)

  id_matches <- regmatches(html, gregexpr('id="[^"]+"', html, perl = TRUE))[[1]]
  ids <- gsub('^id="|"$', "", id_matches)
  duplicates <- names(which(table(ids) > 1L))
  if (length(duplicates)) stop("Duplicate HTML IDs: ", paste(duplicates, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

validate_reference_source_alignment <- function(reports, project_root = ".", output_file = NULL) {
  reference_validate_payloads(reports, project_root)
  reference_validate_image_banks(reports, project_root)
  template_html <- reference_read_utf8(
    file.path(project_root, "assets", "templates", "reference_dashboard.template.html")
  )
  reference_validate_html(template_html, reports, output = FALSE)
  if (!is.null(output_file)) {
    output_html <- reference_read_utf8(output_file)
    reference_validate_html(output_html, reports, output = TRUE)
    reference_validate_output_payloads(output_html, reports)
  }
  invisible(TRUE)
}
