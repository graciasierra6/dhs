indicator_definitions <- data.frame(
  id = c(
    "wasting", "anemia_women", "malaria_rdt_positive", "zero_dose",
    "first_birth_under20", "facility_delivery", "fever_care_seeking", "anc4plus"
  ),
  label = c(
    "Wasting", "Anemia (women)", "Malaria RDT+", "Zero-dose",
    "First birth < 20", "Facility delivery", "Fever care seeking", "ANC4+"
  ),
  short_label = c(
    "Wasting", "Anemia", "Malaria RDT+", "Zero-dose",
    "First birth <20", "Facility delivery", "Fever care", "ANC4+"
  ),
  direction = c("adverse", "adverse", "adverse", "adverse", "adverse", "beneficial", "beneficial", "beneficial"),
  stringsAsFactors = FALSE
)

country_configuration <- data.frame(
  country = c("DRC", "Ethiopia", "Nigeria"),
  slug = c("drc", "ethiopia", "nigeria"),
  country_name = c("Democratic Republic of the Congo", "Ethiopia", "Nigeria"),
  short_name = c("DR Congo", "Ethiopia", "Nigeria"),
  area_singular = c("province", "region", "state/FCT"),
  area_plural = c("provinces", "regions", "states/FCT"),
  expected_areas = c(26L, 11L, 37L),
  mortality_iso = c("DRC", "ETH", "NGA"),
  mortality_survey_year = c(2023L, 2025L, 2024L),
  stringsAsFactors = FALSE
)

required_columns <- function(data, columns, file_label) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(file_label, " is missing required columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

read_report_csv <- function(path, required, file_label) {
  if (!file.exists(path)) stop("Missing ", file_label, ": ", path, call. = FALSE)
  data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, encoding = "UTF-8")
  required_columns(data, required, file_label)
  data
}

country_config <- function(country) {
  row <- country_configuration[country_configuration$country == country, , drop = FALSE]
  if (nrow(row) != 1L) stop("Unsupported country: ", country, call. = FALSE)
  as.list(row[1, ])
}

canonical_admin <- function(country, value) {
  result <- as.character(value)
  replacements <- switch(
    country,
    DRC = c(
      "Kasai Central" = "Kasai-Central", "Kasai Oriental" = "Kasai-Oriental",
      "Kasaï Central" = "Kasai-Central", "Kasaï Oriental" = "Kasai-Oriental",
      "Kasaï" = "Kasai", "Haut Lomami" = "Haut-Lomami",
      "Haut uele" = "Haut-Uele", "Haut Uele" = "Haut-Uele",
      "Nord Ubangi" = "Nord-Ubangi", "Sud Ubangi" = "Sud-Ubangi",
      "Tanganika" = "Tanganyika"
    ),
    Ethiopia = c(
      "Affar" = "Afar", "Benishangul-Gumuz" = "Benishangul",
      "Beneshangul Gumu" = "Benishangul", "Hareri" = "Harari", "Oromiya" = "Oromia"
    ),
    Nigeria = c("FCT" = "FCT Abuja", "Abuja Federal Capital Territory" = "FCT Abuja"),
    character()
  )
  matched <- match(result, names(replacements))
  result[!is.na(matched)] <- unname(replacements[matched[!is.na(matched)]])
  result
}

normalize_admin_key <- function(value) {
  value <- iconv(as.character(value), from = "UTF-8", to = "ASCII//TRANSLIT")
  value <- tolower(value)
  gsub("[^a-z0-9]", "", value)
}

prepare_country_mortality <- function(mortality_all, composite_admin_names, country) {
  config <- country_config(country)
  mortality <- mortality_all[
    mortality_all$iso == config$mortality_iso &
      mortality_all$indicator == "U5MR" &
      as.numeric(mortality_all$window_mid) == 2022 &
      as.numeric(mortality_all$survey_year) == config$mortality_survey_year,
    ,
    drop = FALSE
  ]
  mortality$est_1000 <- as.numeric(mortality$est_1000)
  if (nrow(mortality) != config$expected_areas) {
    stop(
      "Expected exactly ", config$expected_areas, " ", country,
      " U5MR records for window_mid 2022 and survey_year ", config$mortality_survey_year, ", but found ",
      nrow(mortality), ".",
      call. = FALSE
    )
  }
  if (anyNA(mortality$est_1000)) {
    stop(country, " U5MR records contain missing or invalid est_1000 values.", call. = FALSE)
  }

  mortality$canonical_region <- canonical_admin(country, mortality$region_label)
  mortality$key <- normalize_admin_key(mortality$canonical_region)
  composite_keys <- normalize_admin_key(composite_admin_names)

  duplicate_keys <- unique(mortality$key[duplicated(mortality$key)])
  if (length(duplicate_keys)) {
    duplicate_labels <- mortality$region_label[mortality$key %in% duplicate_keys]
    stop("Duplicate ", country, " U5MR areas after name normalization: ", paste(duplicate_labels, collapse = ", "), call. = FALSE)
  }
  unmatched_composite <- composite_admin_names[!composite_keys %in% mortality$key]
  unmatched_mortality <- mortality$region_label[!mortality$key %in% composite_keys]
  if (length(unmatched_composite) || length(unmatched_mortality)) {
    stop(
      country, " U5MR area join failed. Unmatched dashboard areas: ",
      if (length(unmatched_composite)) paste(unmatched_composite, collapse = ", ") else "none",
      "; unmatched mortality provinces: ",
      if (length(unmatched_mortality)) paste(unmatched_mortality, collapse = ", ") else "none",
      ".",
      call. = FALSE
    )
  }

  matched <- match(composite_keys, mortality$key)
  if (anyNA(matched) || anyDuplicated(matched)) {
    stop("Each ", country, " dashboard area must match exactly one U5MR record.", call. = FALSE)
  }
  data.frame(
    admin_name = composite_admin_names,
    u5mr_est_1000 = mortality$est_1000[matched],
    stringsAsFactors = FALSE
  )
}

classification_label <- function(value) {
  labels <- c(improving = "Improving", inside_threshold = "Inside +/-T", worsening = "Worsening", no_data = "No data")
  unname(labels[value])
}

validate_endpoint_lineage <- function(master, indicators, definitions, country, tolerance = 1e-7) {
  endpoint_rows <- lapply(definitions$id, function(indicator_id) {
    indicator_rows <- indicators[indicators$indicator == indicator_id, , drop = FALSE]
    master_rows <- master[master$indicator == indicator_id, , drop = FALSE]
    latest_years <- unique(indicator_rows$latest_year)
    if (length(latest_years) != 1L) {
      stop(country, " ", indicator_id, " has inconsistent latest years in the ranking input.", call. = FALSE)
    }
    latest_year <- as.integer(latest_years)
    latest_master <- master_rows[master_rows$survey_year == latest_year, c("admin_name", "estimate"), drop = FALSE]
    names(latest_master)[2] <- "master_latest_estimate"
    latest_check <- merge(
      indicator_rows[c("admin_name", "observed_latest_estimate")],
      latest_master,
      by = "admin_name",
      all.x = TRUE,
      sort = FALSE
    )
    if (nrow(latest_check) != nrow(indicator_rows) || anyNA(latest_check$master_latest_estimate)) {
      stop(country, " ", indicator_id, " latest values do not fully match the master input.", call. = FALSE)
    }
    latest_error <- max(abs(latest_check$observed_latest_estimate - latest_check$master_latest_estimate))
    if (!is.finite(latest_error) || latest_error > tolerance) {
      stop(country, " ", indicator_id, " latest values differ from the master input.", call. = FALSE)
    }

    candidate_years <- sort(unique(master_rows$survey_year[master_rows$survey_year < latest_year]), decreasing = TRUE)
    matching_years <- candidate_years[vapply(candidate_years, function(baseline_year) {
      baseline_master <- master_rows[master_rows$survey_year == baseline_year, c("admin_name", "estimate"), drop = FALSE]
      names(baseline_master)[2] <- "baseline_estimate"
      endpoint_check <- merge(latest_master, baseline_master, by = "admin_name", all = FALSE, sort = FALSE)
      endpoint_check <- merge(
        endpoint_check,
        indicator_rows[c("admin_name", "pp_change_10yr_recoded")],
        by = "admin_name",
        all = FALSE,
        sort = FALSE
      )
      if (nrow(endpoint_check) != nrow(indicator_rows)) return(FALSE)
      raw_change <- endpoint_check$master_latest_estimate - endpoint_check$baseline_estimate
      risk_change <- if (definitions$direction[definitions$id == indicator_id] == "beneficial") -raw_change else raw_change
      error <- max(abs(risk_change - endpoint_check$pp_change_10yr_recoded))
      is.finite(error) && error <= tolerance
    }, logical(1))]
    if (!length(matching_years)) {
      stop(country, " ", indicator_id, " change values do not match any master-input endpoint pair.", call. = FALSE)
    }
    baseline_year <- max(matching_years)
    data.frame(
      indicator = indicator_id,
      baseline_year = baseline_year,
      latest_year = latest_year,
      span_years = latest_year - baseline_year,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, endpoint_rows)
}

attach_profile_estimates <- function(indicators, endpoints, profile_all, country, tolerance = 1e-7) {
  profile <- profile_all[
    profile_all$country == country & profile_all$indicator %in% unique(indicators$indicator),
    ,
    drop = FALSE
  ]
  profile$admin_name <- canonical_admin(country, profile$admin_name)
  profile$survey_year <- as.integer(profile$survey_year)
  for (column in c("estimate", "ci_l", "ci_u")) profile[[column]] <- as.numeric(profile[[column]])
  if (anyDuplicated(profile[c("indicator", "survey_year", "admin_name")])) {
    stop(country, " profile input contains duplicate area-indicator-year records.", call. = FALSE)
  }

  endpoint_by_indicator <- stats::setNames(seq_len(nrow(endpoints)), endpoints$indicator)
  indicators$baseline_year <- endpoints$baseline_year[endpoint_by_indicator[indicators$indicator]]
  indicators$profile_latest_year <- endpoints$latest_year[endpoint_by_indicator[indicators$indicator]]
  profile_key <- paste(profile$indicator, profile$survey_year, profile$admin_name, sep = "|")
  baseline_key <- paste(indicators$indicator, indicators$baseline_year, indicators$admin_name, sep = "|")
  latest_key <- paste(indicators$indicator, indicators$profile_latest_year, indicators$admin_name, sep = "|")
  baseline_match <- match(baseline_key, profile_key)
  latest_match <- match(latest_key, profile_key)
  if (anyNA(baseline_match) || anyNA(latest_match)) {
    missing_keys <- unique(c(baseline_key[is.na(baseline_match)], latest_key[is.na(latest_match)]))
    stop(
      country, " profile input is missing endpoint records: ",
      paste(missing_keys, collapse = ", "),
      call. = FALSE
    )
  }

  indicators$baseline_estimate <- profile$estimate[baseline_match]
  indicators$baseline_ci_l <- profile$ci_l[baseline_match]
  indicators$baseline_ci_u <- profile$ci_u[baseline_match]
  indicators$baseline_display_year <- vapply(seq_along(baseline_match), function(index) {
    display_survey_year(profile$survey_label[baseline_match[index]], profile$survey_year[baseline_match[index]])
  }, integer(1))
  if (identical(country, "DRC")) {
    indicators$baseline_display_year[indicators$baseline_display_year == 2013L] <- 2014L
  }
  indicators$latest_ci_l <- profile$ci_l[latest_match]
  indicators$latest_ci_u <- profile$ci_u[latest_match]
  indicators$latest_display_year <- vapply(seq_along(latest_match), function(index) {
    display_survey_year(profile$survey_label[latest_match[index]], profile$survey_year[latest_match[index]])
  }, integer(1))
  indicators$survey_source <- as.character(profile$survey_source[latest_match])
  latest_error <- abs(profile$estimate[latest_match] - indicators$observed_latest_estimate)
  if (any(!is.finite(latest_error)) || max(latest_error) > tolerance) {
    stop(country, " profile latest estimates do not match the ranking input.", call. = FALSE)
  }
  if (any(!is.finite(as.matrix(indicators[c(
    "baseline_estimate", "baseline_ci_l", "baseline_ci_u", "latest_ci_l", "latest_ci_u"
  )])))) {
    stop(country, " profile endpoint estimates or confidence intervals are invalid.", call. = FALSE)
  }
  indicators$profile_latest_year <- NULL
  indicators
}

display_survey_year <- function(label, fallback_year) {
  label <- as.character(label)
  pieces <- regmatches(label, gregexpr("[0-9]{2,4}", label, perl = TRUE))[[1]]
  if (!length(pieces)) return(as.integer(fallback_year))
  first <- suppressWarnings(as.integer(pieces[1]))
  last <- suppressWarnings(as.integer(pieces[length(pieces)]))
  if (length(pieces) > 1L && nchar(pieces[length(pieces)]) == 2L && is.finite(first)) {
    last <- (first %/% 100L) * 100L + last
  }
  if (!is.finite(last)) as.integer(fallback_year) else as.integer(last)
}

prepare_country_data <- function(master_all, composite_all, indicator_all, profile_all, country) {
  config <- country_config(country)
  master <- master_all[
    master_all$country == country & master_all$indicator %in% indicator_definitions$id,
    , drop = FALSE
  ]
  master$admin_name <- canonical_admin(country, master$admin_name)
  master$survey_year <- as.integer(master$survey_year)
  master$estimate <- as.numeric(master$estimate)
  duplicate_master <- duplicated(master[c("survey_year", "indicator", "admin_name")])
  if (any(duplicate_master)) stop(country, " master input contains duplicate endpoint records.", call. = FALSE)

  composite <- composite_all[
    composite_all$country == country & composite_all$composite_set != "severe",
    , drop = FALSE
  ]
  composite$admin_name <- canonical_admin(country, composite$admin_name)
  numeric_composite <- c(
    "composite_change_score", "composite_change_rank", "composite_prevalence_score", "composite_prevalence_rank"
  )
  composite[numeric_composite] <- lapply(composite[numeric_composite], as.numeric)
  composite <- composite[order(composite$composite_prevalence_rank, composite$admin_name), , drop = FALSE]
  if (nrow(composite) != config$expected_areas) {
    stop("Expected ", config$expected_areas, " standard composite rows for ", country, ".", call. = FALSE)
  }
  if (anyDuplicated(composite$admin_name)) stop(country, " composite input contains duplicate areas.", call. = FALSE)

  indicators <- indicator_all[
    indicator_all$country == country & indicator_all$indicator %in% indicator_definitions$id,
    , drop = FALSE
  ]
  indicators$admin_name <- canonical_admin(country, indicators$admin_name)
  indicators$latest_year <- as.integer(indicators$latest_year)
  indicators$observed_latest_estimate <- as.numeric(indicators$observed_latest_estimate)
  indicators$pp_change_10yr_recoded <- as.numeric(indicators$pp_change_10yr_recoded)
  indicators$prevalence_rank <- as.numeric(indicators$prevalence_rank)
  indicators$change_rank <- as.numeric(indicators$change_rank)
  if (anyDuplicated(indicators[c("indicator", "admin_name")])) {
    stop(country, " indicator ranking input contains duplicate area-indicator records.", call. = FALSE)
  }

  present_ids <- indicator_definitions$id[indicator_definitions$id %in% unique(indicators$indicator)]
  definitions <- indicator_definitions[indicator_definitions$id %in% present_ids, , drop = FALSE]
  definitions <- definitions[match(present_ids, definitions$id), , drop = FALSE]
  expected_indicator_rows <- config$expected_areas * nrow(definitions)
  if (nrow(indicators) != expected_indicator_rows) {
    stop(
      country, " expected ", expected_indicator_rows, " standard indicator rows but found ", nrow(indicators), ".",
      call. = FALSE
    )
  }
  if (!setequal(indicators$admin_name, composite$admin_name)) {
    stop(country, " indicator and composite area names do not match.", call. = FALSE)
  }

  endpoints <- validate_endpoint_lineage(master, indicators, definitions, country)
  indicators <- attach_profile_estimates(indicators, endpoints, profile_all, country)

  classifications <- indicators[c(
    "admin_name", "indicator", "direction", "latest_year", "observed_latest_estimate", "pp_change_10yr_recoded"
  )]
  names(classifications)[names(classifications) == "observed_latest_estimate"] <- "latest_estimate"
  names(classifications)[names(classifications) == "pp_change_10yr_recoded"] <- "risk_change"
  classifications <- merge(
    classifications,
    definitions[c("id", "label", "short_label")],
    by.x = "indicator",
    by.y = "id",
    all.x = TRUE,
    sort = FALSE
  )
  threshold_by_indicator <- stats::aggregate(
    abs(classifications$risk_change),
    list(indicator = classifications$indicator),
    function(values) as.numeric(stats::quantile(values, probs = 0.25, type = 7, na.rm = TRUE))
  )
  names(threshold_by_indicator)[2] <- "threshold"
  classifications <- merge(classifications, threshold_by_indicator, by = "indicator", all.x = TRUE, sort = FALSE)
  classifications$classification <- ifelse(
    is.na(classifications$risk_change), "no_data",
    ifelse(
      classifications$risk_change < -classifications$threshold,
      "improving",
      ifelse(classifications$risk_change > classifications$threshold, "worsening", "inside_threshold")
    )
  )
  classifications$indicator_order <- match(classifications$indicator, definitions$id)
  classifications <- classifications[order(classifications$admin_name, classifications$indicator_order), , drop = FALSE]

  summary_rows <- lapply(sort(unique(classifications$admin_name)), function(admin) {
    rows <- classifications[classifications$admin_name == admin, , drop = FALSE]
    rows <- rows[order(rows$indicator_order), , drop = FALSE]
    list(
      admin_name = admin,
      worsening_count = sum(rows$classification == "worsening", na.rm = TRUE),
      improving_count = sum(rows$classification == "improving", na.rm = TRUE),
      inside_threshold_count = sum(rows$classification == "inside_threshold", na.rm = TRUE),
      total_indicators = sum(rows$classification != "no_data", na.rm = TRUE),
      worsening_indicators = rows$label[rows$classification == "worsening"],
      improving_indicators = rows$label[rows$classification == "improving"],
      inside_threshold_indicators = rows$label[rows$classification == "inside_threshold"]
    )
  })
  order_summary <- order(
    -vapply(summary_rows, `[[`, numeric(1), "worsening_count"),
    vapply(summary_rows, `[[`, character(1), "admin_name")
  )
  summary_rows <- summary_rows[order_summary]

  c(
    config,
    list(
      rank_max = nrow(composite),
      indicator_count = nrow(definitions),
      baseline_year = min(endpoints$baseline_year),
      latest_year = max(endpoints$latest_year),
      definitions = definitions,
      composite = composite,
      indicators = indicators,
      classifications = classifications,
      summary = summary_rows,
      endpoints = endpoints,
      thresholds = stats::setNames(threshold_by_indicator$threshold, threshold_by_indicator$indicator)
    )
  )
}

prepare_all_report_data <- function(
  input_file,
  composite_file,
  indicator_file,
  mortality_file,
  profile_file = "data/profile_indicator_estimates.csv",
  countries = country_configuration$country
) {
  master_all <- read_report_csv(
    input_file,
    c("country", "survey_year", "indicator", "admin_name", "estimate"),
    "primary count-map input"
  )
  composite_all <- read_report_csv(
    composite_file,
    c(
      "composite_set", "country", "admin_name", "composite_change_score", "composite_change_rank",
      "composite_prevalence_score", "composite_prevalence_rank"
    ),
    "composite ranking input"
  )
  indicator_all <- read_report_csv(
    indicator_file,
    c(
      "country", "indicator", "direction", "admin_name", "latest_year", "observed_latest_estimate",
      "pp_change_10yr_recoded", "prevalence_rank", "change_rank"
    ),
    "subnational indicator ranking input"
  )
  mortality_all <- read_report_csv(
    mortality_file,
    c("iso", "indicator", "region_label", "window_mid", "survey_year", "est_1000"),
    "under-five mortality input"
  )
  profile_all <- read_report_csv(
    profile_file,
    c(
      "country", "survey_year", "survey_source", "survey_label", "indicator", "admin_name",
      "estimate", "ci_l", "ci_u"
    ),
    "profile indicator estimates input"
  )
  reports <- stats::setNames(
    lapply(
      countries,
      prepare_country_data,
      master_all = master_all,
      composite_all = composite_all,
      indicator_all = indicator_all,
      profile_all = profile_all
    ),
    countries
  )
  for (country in names(reports)) {
    reports[[country]]$mortality <- prepare_country_mortality(
      mortality_all,
      reports[[country]]$composite$admin_name,
      country
    )
  }
  reports
}
