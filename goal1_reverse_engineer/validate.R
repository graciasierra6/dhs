command_line <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_line, value = TRUE)
script_file <- if (length(file_argument) == 1L) sub("^--file=", "", file_argument) else "validate.R"
script_path <- normalizePath(
  script_file,
  winslash = "/",
  mustWork = TRUE
)
project_root <- dirname(script_path)
output_file <- file.path(project_root, "output", "goal1_reverse_engineer_test.html")

source(file.path(project_root, "R", "data_prep.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "html_helpers.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "map_validation.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "profile_assets.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "reference_validation.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "threshold_distribution.R"), encoding = "UTF-8")
source(file.path(project_root, "R", "risk_alignment_validation.R"), encoding = "UTF-8")

reports <- prepare_all_report_data(
  input_file = file.path(project_root, "data", "count_map_input_combined_master.csv"),
  composite_file = file.path(project_root, "data", "composite_indicator_rankings.csv"),
  indicator_file = file.path(project_root, "data", "subnational_indicator_rankings.csv"),
  mortality_file = file.path(project_root, "data", "mortalityunder5.csv"),
  profile_file = file.path(project_root, "data", "profile_indicator_estimates.csv")
)
risk_alignment_audit <- validate_risk_alignment(reports)
profile_sources <- validate_supplied_profile_sources(reports, project_root)
stopifnot(nrow(profile_sources$numbers) == 581L)
stopifnot(nrow(profile_sources$mortality) == 222L)

profile_manifest <- utils::read.csv(
  file.path(project_root, "artifacts", "profile_images_manifest.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
profile_manifest <- profile_manifest[profile_manifest$chart_type == "profiles", , drop = FALSE]
profile_archive <- file.path(project_root, "assets", "profile-plots-profiles.zip")
expected_archive_names <- sub("^assets/profile-plots/", "", profile_manifest$asset_path)
manifest_order <- order(expected_archive_names)
if (
  nrow(profile_manifest) != 74L ||
  anyDuplicated(expected_archive_names) ||
  any(!nzchar(expected_archive_names)) ||
  any(!is.finite(profile_manifest$bytes)) ||
  any(profile_manifest$bytes <= 0)
) stop("Supplied prevalence-profile manifest is incomplete or invalid.", call. = FALSE)

# The original 21.5 MB PNG archive is visual provenance only and is deliberately
# excluded from the browser-uploadable project. If a local copy is restored, its
# contents are still checked exactly against the committed manifest.
if (file.exists(profile_archive)) {
  archive_inventory <- utils::unzip(profile_archive, list = TRUE)
  archive_inventory <- archive_inventory[grepl("\\.png$", archive_inventory$Name, ignore.case = TRUE), , drop = FALSE]
  archive_order <- order(archive_inventory$Name)
  if (
    nrow(archive_inventory) != 74L ||
    !identical(archive_inventory$Name[archive_order], expected_archive_names[manifest_order]) ||
    !identical(as.numeric(archive_inventory$Length[archive_order]), as.numeric(profile_manifest$bytes[manifest_order]))
  ) stop("Archived supplied prevalence-profile PNGs do not match their 74-file manifest.", call. = FALSE)
}

expected <- data.frame(
  country = c("DRC", "Ethiopia", "Nigeria"),
  areas = c(26L, 11L, 37L),
  indicators = c(8L, 7L, 8L),
  indicator_rows = c(208L, 77L, 296L),
  stringsAsFactors = FALSE
)

indicator_palette <- c(
  "#F7FCFD", "#E0ECF4", "#BFD3E6", "#9EBCDA", "#8C96C6",
  "#8C6BB1", "#88419D", "#810F7C", "#4D004B"
)

for (index in seq_len(nrow(expected))) {
  country <- expected$country[index]
  report <- reports[[country]]
  stopifnot(report$rank_max == expected$areas[index])
  stopifnot(report$indicator_count == expected$indicators[index])
  stopifnot(nrow(report$indicators) == expected$indicator_rows[index])
  stopifnot(nrow(report$classifications) == expected$indicator_rows[index])
  stopifnot(!anyDuplicated(report$composite$admin_name))
  stopifnot(!anyDuplicated(report$indicators[c("admin_name", "indicator")]))
  stopifnot(all(report$composite$composite_set != "severe"))
  stopifnot(nrow(report$mortality) == expected$areas[index])
  stopifnot(!anyDuplicated(report$mortality$admin_name))
  stopifnot(setequal(report$mortality$admin_name, report$composite$admin_name))
  stopifnot(!anyNA(report$mortality$u5mr_est_1000))

  for (indicator_id in report$definitions$id) {
    rows <- report$indicators[report$indicators$indicator == indicator_id, , drop = FALSE]
    threshold <- as.numeric(stats::quantile(abs(rows$pp_change_10yr_recoded), 0.25, type = 7))
    stopifnot(abs(threshold - report$thresholds[[indicator_id]]) < 1e-12)
    values <- as.numeric(rows$observed_latest_estimate)
    value_min <- min(values)
    value_max <- max(values)
    progress <- if (value_max == value_min) rep(0.5, length(values)) else (values - value_min) / (value_max - value_min)
    palette_index <- pmin(length(indicator_palette) - 1L, floor(progress * length(indicator_palette)))
    direction <- report$definitions$direction[match(indicator_id, report$definitions$id)]
    if (identical(direction, "beneficial")) palette_index <- length(indicator_palette) - 1L - palette_index
    colors <- indicator_palette[palette_index + 1L]
    if (length(unique(values)) < 2L || length(unique(colors)) < 2L) {
      stop(country, " ", indicator_id, " indicator-prevalence map does not have a varying source distribution and palette.", call. = FALSE)
    }
  }
}

distribution_file <- file.path(project_root, "data", "worsening_count_threshold_distributions.csv")
if (!file.exists(distribution_file)) {
  stop("Missing threshold distribution CSV. Run Rscript render.R first.", call. = FALSE)
}
expected_distribution <- build_worsening_threshold_distribution(reports)
actual_distribution <- utils::read.csv(
  distribution_file,
  stringsAsFactors = FALSE,
  check.names = FALSE,
  fileEncoding = "UTF-8"
)
validate_worsening_threshold_distribution(actual_distribution, reports)
reference_compare_frames(
  expected_distribution,
  actual_distribution,
  keys = c("country", "indicator", "admin_name"),
  text_fields = c("indicator_label", "direction", "classification", "classification_label"),
  numeric_fields = c(
    "distribution_order_improving_to_worsening", "absolute_change_distribution_rank",
    "areas_in_country_indicator_distribution", "latest_year", "observed_latest_estimate",
    "prevalence_rank", "change_rank", "risk_aligned_change_pp", "absolute_risk_aligned_change_pp",
    "threshold_percentile", "quantile_type", "threshold_t_pp", "improving_cutoff_pp",
    "worsening_cutoff_pp", "improving_count_contribution",
    "non_significant_count_contribution", "worsening_count_contribution"
  ),
  tolerance = 1e-8
)

stopifnot(attr(risk_alignment_audit, "indicator_rows") == 581L)
stopifnot(attr(risk_alignment_audit, "bivariate_pairs") == 77L)

if (!file.exists(output_file)) {
  stop("Missing rendered dashboard. Run Rscript render.R first.", call. = FALSE)
}
rendered_html <- reference_read_utf8(output_file)
rendered_raw <- readBin(output_file, what = "raw", n = file.info(output_file)$size)
raw_contains <- function(haystack, needle) {
  length(grepRaw(as.raw(needle), haystack, fixed = TRUE, all = TRUE)) > 0L
}
for (invalid_utf8_marker in list(
  c(0xC3, 0xA2),
  c(0xC3, 0x82),
  c(0xC3, 0x83),
  c(0xEF, 0xBF, 0xBD)
)) stopifnot(!raw_contains(rendered_raw, invalid_utf8_marker))
stopifnot(raw_contains(rendered_raw, charToRaw('5\\u20136')))
overview_section_ids <- unlist(lapply(c("drc", "ethiopia", "nigeria"), function(slug) {
  paste0(slug, c("-prevalence", "-change", "-indicators", "-counts"))
}), use.names = FALSE)
overview_view_boxes <- vapply(overview_section_ids, function(section_id) {
  section_html <- reference_extract_section(rendered_html, section_id)
  match <- regexec('<svg class="geo-map" viewBox="([^"]+)"', section_html, perl = TRUE)
  capture <- regmatches(section_html, match)[[1]]
  if (length(capture) != 2L) stop("Missing overview map viewBox for ", section_id, ".", call. = FALSE)
  capture[[2]]
}, character(1))
stopifnot(length(unique(overview_view_boxes)) == 1L)
stopifnot(unname(overview_view_boxes[[1]]) == "0 0 720 460")
for (country in names(reports)) {
  report <- reports[[country]]
  bivariate_html <- reference_extract_section(rendered_html, paste0(report$slug, "-bivariate"))
  stopifnot(reference_fixed_count('<use class="map-region', bivariate_html) == report$rank_max)
  stopifnot(reference_fixed_count("biv-region", bivariate_html) == report$rank_max)
  for (indicator_id in report$definitions$id) {
    stopifnot(reference_fixed_count(paste0('<option value="', indicator_id, '">'), bivariate_html) == 2L)
  }
}
interaction_script <- reference_read_utf8(
  file.path(project_root, "assets", "js", "reference_dashboard.template.js")
)
dashboard_css <- reference_read_utf8(
  file.path(project_root, "assets", "css", "reference_dashboard.css")
)
stopifnot(grepl("ensureBivariateModeControl", interaction_script, fixed = TRUE))
stopifnot(grepl('<option value="prevalence_rank">Current rank</option>', interaction_script, fixed = TRUE))
stopifnot(grepl('modeSelect?.addEventListener("change"', interaction_script, fixed = TRUE))
stopifnot(grepl("updateBivariateSection(section)", interaction_script, fixed = TRUE))
stopifnot(grepl('indicatorRows.filter((row) => row.country === country)', interaction_script, fixed = TRUE))
stopifnot(grepl('classifications.filter((row) => row.country === country)', interaction_script, fixed = TRUE))
stopifnot(grepl('bivariateColors[xr.classification + ":" + yr.classification]', interaction_script, fixed = TRUE))
stopifnot(grepl('prevalenceRankBivariateColors[xb + ":" + yb]', interaction_script, fixed = TRUE))
stopifnot(grepl('mode === "prevalence_rank" ? "prevalence" : "change"', interaction_script, fixed = TRUE))
stopifnot(grepl("applyWorseningCountPalette", interaction_script, fixed = TRUE))
stopifnot(grepl('data-role="mapping-status" hidden', rendered_html, fixed = TRUE))
stopifnot(grepl("z-index: 2;\n  width: 270px;\n  padding: 16px 12px;\n  background: #fff;", dashboard_css, fixed = TRUE))
stopifnot(grepl(".bivariate-map {\n    min-height: 600px;", dashboard_css, fixed = TRUE))
stopifnot(grepl(".bivariate-map .geo-map {\n    height: 660px;", dashboard_css, fixed = TRUE))
stopifnot(grepl(".map-shell:not(.bivariate-map)", dashboard_css, fixed = TRUE))
stopifnot(grepl("Cross-platform overview sizing", dashboard_css, fixed = TRUE))
stopifnot(grepl("aspect-ratio: 720 / 460;", dashboard_css, fixed = TRUE))
stopifnot(grepl('document.querySelectorAll(".count-section")', interaction_script, fixed = TRUE))
stopifnot(grepl('"5\\u20136", "4", "2\\u20133", "0\\u20131"', interaction_script, fixed = TRUE))
stopifnot(grepl("const mortalityRows = {{MORTALITY_ROWS}};", interaction_script, fixed = TRUE))
stopifnot(!grepl("provinceImagesPrevalence", interaction_script, fixed = TRUE))
stopifnot(!grepl("provinceImagesChange", interaction_script, fixed = TRUE))
stopifnot(grepl("alphabetizeIndicatorTabs", interaction_script, fixed = TRUE))
stopifnot(grepl("initializeIndicatorSections", interaction_script, fixed = TRUE))
stopifnot(grepl("tabs.replaceChildren()", interaction_script, fixed = TRUE))
stopifnot(grepl("initialized.forEach(([indicator, section]) => updateIndicator(indicator, section))", interaction_script, fixed = TRUE))
stopifnot(grepl("if (note) {", interaction_script, fixed = TRUE))
stopifnot(!grepl("fitMapViewBoxes", interaction_script, fixed = TRUE))
stopifnot(!grepl("profile-image--map-cropped", interaction_script, fixed = TRUE))
stopifnot(!grepl("Each row compares", interaction_script, fixed = TRUE))
stopifnot(grepl("buildPrevalenceProfile", interaction_script, fixed = TRUE))
stopifnot(grepl("buildChangeProfile", interaction_script, fixed = TRUE))
stopifnot(grepl("riskAlignedEndpoint", interaction_script, fixed = TRUE))
stopifnot(grepl('const profileOrder = ["malaria_rdt_positive", "zero_dose", "facility_delivery", "anc4plus", "anemia_women", "fever_care_seeking", "wasting", "first_birth_under20"]', interaction_script, fixed = TRUE))
stopifnot(grepl('const labelX = 182, leftValueX = 280, left = 308, right = 782, rightValueX = 880, legendX = 1008;', interaction_script, fixed = TRUE))
stopifnot(grepl('position(selected.latestCiL, false)', interaction_script, fixed = TRUE))
stopifnot(grepl('position(selected.latestCiU, false)', interaction_script, fixed = TRUE))
stopifnot(grepl('const legendOrder = ["Worst fifth", "Worse half", "Better half", "Best fifth"]', interaction_script, fixed = TRUE))
stopifnot(grepl('viewBox="0 0 \' + width + \' \' + height + \'"', interaction_script, fixed = TRUE))
stopifnot(!grepl("[^\\x00-\\x7F]", interaction_script, perl = TRUE))
stopifnot(grepl('new MouseEvent("click", { bubbles: true })', interaction_script, fixed = TRUE))
stopifnot(grepl("a.label.localeCompare(b.label)", interaction_script, fixed = TRUE))
stopifnot(grepl(".indicator-grid:has(.bar-panel[hidden]),", dashboard_css, fixed = TRUE))
stopifnot(grepl(".count-map-block > .map-shell,", dashboard_css, fixed = TRUE))
stopifnot(!grepl("height: 770px", dashboard_css, fixed = TRUE))
stopifnot(!grepl("min-height: 720px", dashboard_css, fixed = TRUE))

validate_reference_source_alignment(reports, project_root = project_root, output_file = output_file)
stopifnot(file.info(output_file)$size < 10000000L)
stopifnot(!grepl('<script src="', rendered_html, fixed = TRUE))
map_result <- validate_map_build(project_root = project_root, online = FALSE, verbose = FALSE)

upload_files <- list.files(
  project_root,
  recursive = TRUE,
  all.files = TRUE,
  full.names = TRUE,
  no.. = TRUE
)
upload_files <- upload_files[file.info(upload_files)$isdir %in% FALSE]
upload_files <- upload_files[!grepl("/\\.git(/|$)", upload_files)]
upload_files <- upload_files[!basename(upload_files) %in% c(".DS_Store", ".Rhistory", ".RData")]
upload_files <- upload_files[!grepl("/(\\.Rproj\\.user|renv/library)/", upload_files)]
upload_sizes <- file.info(upload_files)$size
stopifnot(length(upload_files) < 100L)
stopifnot(all(upload_sizes < 25L * 1024L * 1024L))

cat(
  "Validation passed: 74 administrative areas; 581 source-aligned indicator rows; ",
  "581-row worsening-threshold distribution CSV; 581 country- and indicator-specific risk classifications; ",
  "74 source-driven prevalence profiles and 74 source-driven risk-aligned change profiles; 74 supplied prevalence-profile manifest records; 581 supplied profile-number rows with exact CI agreement; ",
  "222 supplied IMR/NMR/U5MR profile rows; ",
  "six composite rank maps, three country-specific worsening-count maps, three bivariate sections, ",
  "77 complete country-specific indicator pairs in both bivariate modes; 581 independently risk-aligned endpoint records; ",
  "state-name and geometry joins; ",
  map_result$checks, " boundary checks; ", length(upload_files),
  " uploadable project files; self-contained dashboard below 10 MB with no external network data requests, absolute paths, or machine identifiers.\n",
  sep = ""
)
