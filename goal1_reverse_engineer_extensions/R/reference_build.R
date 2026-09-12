reference_replace_once <- function(text, token, replacement) {
  positions <- gregexpr(token, text, fixed = TRUE)[[1]]
  count <- if (length(positions) == 1L && positions[1] < 0L) 0L else length(positions)
  if (count != 1L) stop("Expected exactly one build token ", token, ", found ", count, call. = FALSE)
  sub(token, replacement, text, fixed = TRUE)
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
    map, "</div></section>"
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

reference_add_methods_navigation <- function(shell, report) {
  bivariate_chapter <- paste0(
    '<div class="nav-chapter" data-country="', report$slug,
    '" data-tab="bivariate"><a href="#', report$slug,
    '-bivariate" data-country="', report$slug,
    '" data-tab="bivariate"><span>02</span><b>Bivariate Map</b></a></div>'
  )
  methods_chapter <- paste0(
    '<div class="nav-chapter" data-country="', report$slug,
    '" data-tab="methods"><a href="#', report$slug,
    '-methods" data-country="', report$slug,
    '" data-tab="methods"><span>03</span><b>Methods Overview</b></a></div>'
  )
  shell <- reference_replace_once(shell, bivariate_chapter, paste0(bivariate_chapter, methods_chapter))

  hidden <- if (identical(report$slug, "ethiopia")) " hidden" else ""
  bivariate_button <- paste0(
    '<button type="button" class="tab-btn country-scoped" data-country="', report$slug,
    '" data-tab="bivariate" role="tab" aria-selected="false"', hidden, '>Bivariate Map</button>'
  )
  methods_hidden <- if (identical(report$slug, "drc")) "" else " hidden"
  methods_button <- paste0(
    '<button type="button" class="tab-btn country-scoped" data-country="', report$slug,
    '" data-tab="methods" role="tab" aria-selected="false"', methods_hidden, '>Methods Overview</button>'
  )
  reference_replace_once(shell, bivariate_button, paste0(bivariate_button, methods_button))
}

reference_methods_panel_markup <- function(report) {
  indicator_names <- c(
    "ANC4+", "Fever care seeking", "Facility delivery", "First birth < 20",
    "Zero-dose", "Anemia (women)", "Wasting"
  )
  if (!identical(report$slug, "ethiopia")) indicator_names <- append(indicator_names, "Malaria RDT+", after = 5L)
  indicator_list <- paste0("<li>", html_escape(indicator_names), "</li>", collapse = "")
  paste0(
    '<div class="tab-panel country-scoped" data-country="', report$slug,
    '" data-tab-panel="methods" hidden><section id="', report$slug,
    '-methods" class="analysis-section methods-overview">',
    '<div class="section-heading"><span class="section-index">01</span><div><h3>Methods Overview</h3>',
    '<p>How to interpret the ', html_escape(report$country_name), ' maps and comparison panels.</p></div></div>',
    '<div class="methods-grid">',
    '<div class="subsection-label"><span>01</span><div><h4>Indicators Assessed</h4></div></div>',
    '<div class="indicators-assessed-card"><ul>', indicator_list, '</ul></div>',
    '<div class="subsection-label"><span>02</span><div><h4>How Rankings and Worsening Are Defined</h4></div></div>',
    '<div class="methods-rank-note"><strong>All ranks are within-country.</strong><p>A geography\'s rank shows how it compares with its peers in the same country; it does not directly compare burden across countries.</p></div>',
    '<div class="methods-card-grid methods-definition-grid">',
    '<article class="methods-card methods-definition-card"><span class="methods-card-kicker">Current burden</span><h5>Composite prevalence rank</h5><p>Where a geography stands on burden relative to its peers across all programmatic indicators at once.</p><p class="methods-calculation"><b>Calculation</b>The average of its indicator-specific ranks using the most recent DHS prevalence estimates, re-ranked within the country.</p></article>',
    '<article class="methods-card methods-definition-card"><span class="methods-card-kicker">Change over time</span><h5>Composite change rank</h5><p>Where a geography stands on how much its burden has improved or worsened over time across multiple programmatic indicators at once.</p><p class="methods-calculation"><b>Calculation</b>The average of its indicator-specific ranks for risk-aligned percentage-point change between the most recent DHS estimate and the survey closest to ten years earlier, re-ranked within the country.</p></article>',
    '<article class="methods-card methods-definition-card"><span class="methods-card-kicker">Classification</span><h5>Worsening</h5><p>An indicator that has moved in the wrong direction by more than a marginal amount.</p><p class="methods-calculation"><b>Calculation</b>For each country-indicator, the threshold T is the type-7 25th percentile of absolute risk-aligned change across its geographies. Values above +T are worsening, values below -T are improving, and values between -T and +T are classified as little to no (non-significant) change.</p></article>',
    '</div>',
    '<div class="subsection-label"><span>03</span><div><h4>Prevalence References</h4></div></div>',
    '<div class="methods-card-grid">',
    '<article class="methods-card"><h5>Median across states</h5><p>The unweighted middle value after ordering the displayed first-level administrative areas from low to high. For an even number of areas, it is the average of the two middle values. It is not the national prevalence.</p></article>',
    '<article class="methods-card"><h5>National prevalence</h5><p>The country-level, survey-weighted DHS estimate using the same indicator definition and survey period.</p></article>',
    '<article class="methods-card"><h5>Distance to national prevalence</h5><p>The horizontal segment links each area value to the national-prevalence reference line. The dot marks the area value; the vertical line marks the national prevalence.</p></article>',
    '</div>',
    '<div class="subsection-label"><span>04</span><div><h4>Change and Bivariate Classification</h4></div></div>',
    '<div class="methods-card-grid">',
    '<article class="methods-card"><h5>Risk-aligned change</h5><p>Percentage-point changes are aligned so positive values always mean worsening and negative values always mean improving. Beneficial indicators are sign-reversed before ranking and counting.</p></article>',
    '<article class="methods-card"><h5>Worsening count</h5><p>The count map sums the indicators classified as worsening for each geography. Indicators classified as improving or little to no change are not counted.</p></article>',
    '<article class="methods-card"><h5>Bivariate map</h5><p>Change mode combines two country-specific change classifications. Current-rank mode combines the best, middle, and worst thirds of each indicator ranking within the selected country.</p></article>',
    '</div></div></section></div>'
  )
}

build_reference_dashboard <- function(
  output_file = file.path("output", "goal1_reverse_engineer_extensions.html"),
  project_root = "."
) {
  source(file.path(project_root, "R", "data_prep.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "html_helpers.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "profile_assets.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "reference_validation.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "threshold_distribution.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "risk_alignment_validation.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "national_prevalence_reference.R"), local = TRUE, encoding = "UTF-8")

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
  national_prevalence <- read_national_prevalence_reference(
    file.path(project_root, "data", "national_prevalence_reference.csv"),
    generated$indicator_rows
  )
  validate_supplied_profile_sources(reports, project_root)
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
  for (country in c("DRC", "Ethiopia", "Nigeria")) {
    shell <- reference_add_methods_navigation(shell, reports[[country]])
  }
  methods_markup <- reference_methods_panel_markup
  environment(methods_markup) <- environment()
  methods_panels <- paste(vapply(
    reports[c("DRC", "Ethiopia", "Nigeria")],
    methods_markup,
    character(1)
  ), collapse = "")
  shell <- reference_replace_once(shell, "{{METHODS_PANELS}}", methods_panels)
  indicator_json <- jsonlite::toJSON(
    generated$indicator_rows, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = 15
  )
  classification_json <- jsonlite::toJSON(
    generated$classifications, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = 15
  )
  mortality_json <- jsonlite::toJSON(
    reference_mortality_profile_rows(reports, project_root),
    dataframe = "rows", auto_unbox = TRUE, na = "null", digits = 15
  )
  national_prevalence_json <- jsonlite::toJSON(
    national_prevalence, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = 15
  )
  script <- reference_replace_once(script, "{{INDICATOR_ROWS}}", indicator_json)
  script <- reference_replace_once(script, "{{CLASSIFICATIONS}}", classification_json)
  script <- reference_replace_once(script, "{{MORTALITY_ROWS}}", mortality_json)
  script <- reference_replace_once(script, "{{NATIONAL_PREVALENCE_ROWS}}", national_prevalence_json)
  html <- reference_replace_once(shell, "{{DASHBOARD_CSS}}", css)
  html <- reference_replace_once(html, "{{PROFILE_IMAGE_SCRIPTS}}", "")
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
