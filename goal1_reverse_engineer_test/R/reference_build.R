reference_replace_once <- function(text, token, replacement) {
  positions <- gregexpr(token, text, fixed = TRUE)[[1]]
  count <- if (length(positions) == 1L && positions[1] < 0L) 0L else length(positions)
  if (count != 1L) stop("Expected exactly one build token ", token, ", found ", count, call. = FALSE)
  sub(token, replacement, text, fixed = TRUE)
}

reference_profile_image_bank <- function(chart_type, reports, project_root, manifest, asset_reader) {
  bank <- unlist(lapply(names(reports), function(country) {
    areas <- reports[[country]]$composite$admin_name
    rows <- manifest[
      manifest$chart_type == chart_type & manifest$country == country,
      ,
      drop = FALSE
    ]
    rows <- rows[match(areas, rows$admin_name), , drop = FALSE]
    images <- lapply(rows$asset_path, asset_reader, project_root = project_root)
    stats::setNames(
      paste0("data:image/png;base64,", vapply(images, base64enc::base64encode, character(1))),
      areas
    )
  }), use.names = TRUE)
  jsonlite::toJSON(as.list(bank), auto_unbox = TRUE)
}

reference_html_attribute <- function(tag, attribute) {
  marker <- paste0(attribute, '="')
  start <- regexpr(marker, tag, fixed = TRUE)[1]
  if (start < 0L) stop("Missing ", attribute, " attribute in map region.", call. = FALSE)
  remainder <- substr(tag, start + nchar(marker), nchar(tag))
  finish <- regexpr('"', remainder, fixed = TRUE)[1]
  if (finish < 0L) stop("Unclosed ", attribute, " attribute in map region.", call. = FALSE)
  substr(remainder, 1L, finish - 1L)
}

reference_count_features <- function(shell, report) {
  section <- reference_extract_section(shell, paste0(report$slug, "-prevalence"))
  marker <- '<use class="map-region'
  starts <- gregexpr(marker, section, fixed = TRUE)[[1]]
  if (length(starts) == 1L && starts[1] < 0L) {
    stop("No map regions found for ", report$country_name, ".", call. = FALSE)
  }
  tags <- vapply(starts, function(start) {
    remainder <- substr(section, start, nchar(section))
    finish <- regexpr("></use>", remainder, fixed = TRUE)[1]
    if (finish < 0L) stop("Incomplete map region for ", report$country_name, ".", call. = FALSE)
    substr(remainder, 1L, finish + nchar("></use>") - 1L)
  }, character(1))
  features <- lapply(tags, function(tag) {
    list(
      id = sub("^#", "", reference_html_attribute(tag, "href")),
      name = reference_html_attribute(tag, "data-name")
    )
  })
  feature_names <- vapply(features, `[[`, character(1), "name")
  feature_ids <- vapply(features, `[[`, character(1), "id")
  if (length(features) != report$rank_max || anyDuplicated(feature_names) || anyDuplicated(feature_ids) ||
      !setequal(feature_names, report$composite$admin_name)) {
    stop(report$country_name, " map features do not match its administrative areas.", call. = FALSE)
  }
  features
}

reference_count_section_markup <- function(report, features, input_file, indicator_file) {
  summary_frame <- summary_to_frame(report$summary)
  by_name <- named_rows(summary_frame)
  summary_lookup <- stats::setNames(report$summary, vapply(report$summary, `[[`, character(1), "admin_name"))
  maximum_count <- max(summary_frame$worsening_count)
  highest_names <- sort(summary_frame$admin_name[summary_frame$worsening_count == maximum_count])
  country_count_colors <- count_colors_for_country(report$country)
  discrete <- paste(vapply(rev(names(country_count_colors)), function(label) {
    paste0('<span><i style="background:', country_count_colors[[label]], '"></i>', label, "</span>")
  }, character(1)), collapse = "")
  map <- map_markup(
    id = paste0(report$slug, "-count-map"),
    title = "Number of Worsening Indicators",
    aria_label = paste(report$country_name, "administrative map"),
    features = features,
    data_by_name = by_name,
    class_name = "wide-map",
    fill_function = function(row) if (is.null(row)) "#E7E2E8" else {
      country_count_colors[[count_bucket(row$worsening_count[1], report$country)]]
    },
    tooltip_function = function(name, row) {
      detail <- summary_lookup[[name]]
      if (is.null(detail)) return(paste(name, "No data", sep = "\n"))
      paste(
        name,
        paste0(
          detail$worsening_count, " Worsening: ",
          if (length(detail$worsening_indicators)) paste(detail$worsening_indicators, collapse = ", ") else "None"
        ),
        paste0(
          detail$improving_count, " Improving: ",
          if (length(detail$improving_indicators)) paste(detail$improving_indicators, collapse = ", ") else "None"
        ),
        paste0(
          detail$inside_threshold_count, " Non-significant change: ",
          if (length(detail$inside_threshold_indicators)) paste(detail$inside_threshold_indicators, collapse = ", ") else "None"
        ),
        sep = "\n"
      )
    },
    legend = paste0(
      '<div class="map-legend count-legend"><strong>Number of<br>worsening indicators</strong>',
      '<div class="discrete-legend">', discrete, "</div></div>"
    ),
    view_box = "0 0 720 460"
  )
  paste0(
    '<section id="', report$slug, '-counts" class="analysis-section count-section">',
    '<div class="section-heading"><span class="section-index">04</span><div><h3>Worsening Indicator Count</h3></div></div>',
    '<div class="count-kpis"><div><span>Highest count</span><strong>', maximum_count, "</strong><p>",
    html_escape(paste(highest_names, collapse = ", ")), '</p></div><div><span>Median count</span><strong>',
    format_number(median_value(summary_frame$worsening_count)), '</strong><p>across ', nrow(summary_frame), " ",
    html_escape(report$area_plural), "</p></div></div>",
    '<div class="count-map-block"><div class="subsection-label"><span>02</span><div><h4>Count Map</h4></div></div>',
    map, '<p class="map-source">Sources: ', html_escape(basename(input_file)), "; ",
    html_escape(basename(indicator_file)), "</p></div></section>"
  )
}

reference_add_count_navigation <- function(shell, report) {
  indicator_link <- paste0(
    '<a href="#', report$slug, '-indicators" data-country="', report$slug,
    '" data-tab="overview"><span>03</span>2024 Indicator Prevalence</a>'
  )
  count_link <- paste0(
    '<a href="#', report$slug, '-counts" data-country="', report$slug,
    '" data-tab="overview"><span>04</span>Worsening count</a>'
  )
  reference_replace_once(shell, indicator_link, paste0(indicator_link, count_link))
}

build_reference_dashboard <- function(
  output_file = file.path("output", "goal1_reverse_engineer_test.html"),
  project_root = "."
) {
  source(file.path(project_root, "R", "data_prep.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "html_helpers.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "profile_assets.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "reference_validation.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "threshold_distribution.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "risk_alignment_validation.R"), local = TRUE, encoding = "UTF-8")

  reports <- prepare_all_report_data(
    input_file = file.path(project_root, "data", "count_map_input_combined_master.csv"),
    composite_file = file.path(project_root, "data", "composite_indicator_rankings.csv"),
    indicator_file = file.path(project_root, "data", "subnational_indicator_rankings.csv"),
    mortality_file = file.path(project_root, "data", "mortalityunder5.csv"),
    profile_file = file.path(project_root, "data", "profile_indicator_estimates.csv")
  )
  validate_risk_alignment(reports)
  threshold_distribution <- build_worsening_threshold_distribution(reports)
  validate_worsening_threshold_distribution(threshold_distribution, reports)
  distribution_path <- write_worsening_threshold_distribution(
    threshold_distribution,
    file.path(project_root, "data", "worsening_count_threshold_distributions.csv")
  )
  generated <- reference_payloads_from_reports(reports)
  validate_supplied_profile_sources(reports, project_root)
  profile_manifest <- validate_profile_asset_manifest(reports, project_root)
  validate_reference_source_alignment(reports, project_root = project_root)

  shell <- reference_read_utf8(
    file.path(project_root, "assets", "templates", "reference_dashboard.template.html")
  )
  css <- reference_read_utf8(file.path(project_root, "assets", "css", "reference_dashboard.css"))
  script <- reference_read_utf8(
    file.path(project_root, "assets", "js", "reference_dashboard.template.js")
  )
  input_file <- file.path(project_root, "data", "count_map_input_combined_master.csv")
  indicator_file <- file.path(project_root, "data", "subnational_indicator_rankings.csv")
  count_features <- reference_count_features
  environment(count_features) <- environment()
  count_markup <- reference_count_section_markup
  environment(count_markup) <- environment()
  for (country in c("Ethiopia", "Nigeria")) {
    report <- reports[[country]]
    shell <- reference_add_count_navigation(shell, report)
    count_section <- count_markup(
      report,
      count_features(shell, report),
      input_file,
      indicator_file
    )
    shell <- reference_replace_once(
      shell,
      paste0("{{", toupper(report$slug), "_COUNT_SECTION}}"),
      count_section
    )
  }
  prevalence_images <- reference_profile_image_bank(
    "profiles", reports, project_root, profile_manifest, profile_asset_raw
  )
  change_images <- reference_profile_image_bank(
    "change", reports, project_root, profile_manifest, profile_asset_raw
  )
  indicator_json <- jsonlite::toJSON(
    generated$indicator_rows, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = 15
  )
  classification_json <- jsonlite::toJSON(
    generated$classifications, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = 15
  )
  script <- reference_replace_once(script, "{{PROVINCE_IMAGES_PREVALENCE}}", prevalence_images)
  script <- reference_replace_once(script, "{{PROVINCE_IMAGES_CHANGE}}", change_images)
  script <- reference_replace_once(script, "{{INDICATOR_ROWS}}", indicator_json)
  script <- reference_replace_once(script, "{{CLASSIFICATIONS}}", classification_json)
  html <- reference_replace_once(shell, "{{DASHBOARD_CSS}}", css)
  html <- reference_replace_once(html, "{{DASHBOARD_SCRIPT}}", script)

  output_path <- if (grepl("^[A-Za-z]:[/\\\\]", output_file)) output_file else file.path(project_root, output_file)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(html, con = output_path, useBytes = TRUE)
  validate_reference_source_alignment(reports, project_root = project_root, output_file = output_path)
  invisible(list(
    html = normalizePath(output_path, winslash = "/", mustWork = TRUE),
    threshold_distribution = distribution_path
  ))
}
