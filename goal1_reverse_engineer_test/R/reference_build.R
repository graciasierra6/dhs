reference_replace_once <- function(text, token, replacement) {
  positions <- gregexpr(token, text, fixed = TRUE)[[1]]
  count <- if (length(positions) == 1L && positions[1] < 0L) 0L else length(positions)
  if (count != 1L) stop("Expected exactly one build token ", token, ", found ", count, call. = FALSE)
  sub(token, replacement, text, fixed = TRUE)
}

build_reference_dashboard <- function(
  output_file = file.path("output", "goal1_reverse_engineer_test.html"),
  project_root = "."
) {
  source(file.path(project_root, "R", "data_prep.R"), local = TRUE, encoding = "UTF-8")
  source(file.path(project_root, "R", "html_helpers.R"), local = TRUE, encoding = "UTF-8")
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
  validate_reference_source_alignment(reports, project_root = project_root)

  shell <- reference_read_utf8(
    file.path(project_root, "assets", "templates", "reference_dashboard.template.html")
  )
  css <- reference_read_utf8(file.path(project_root, "assets", "css", "reference_dashboard.css"))
  script <- reference_read_utf8(
    file.path(project_root, "assets", "js", "reference_dashboard.template.js")
  )
  prevalence_images <- reference_read_utf8(
    file.path(project_root, "artifacts", "profile_images_prevalence.json")
  )
  change_images <- reference_read_utf8(
    file.path(project_root, "artifacts", "profile_images_change.json")
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
