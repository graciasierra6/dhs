validate_supplied_profile_sources <- function(reports, project_root = ".", tolerance = 1e-7) {
  numbers <- read_report_csv(
    file.path(project_root, "data", "source", "region_profile_numbers.csv"),
    c(
      "country", "admin_name", "indicator", "label", "direction", "latest_year",
      "prev", "se", "ci_l", "ci_u", "prevalence_rank", "n_units", "rank_band",
      "prov_avg", "prov_min", "prov_max", "gap_worse", "pos_worse"
    ),
    "supplied region profile numbers"
  )
  for (field in c(
    "latest_year", "prev", "se", "ci_l", "ci_u", "prevalence_rank", "n_units",
    "prov_avg", "prov_min", "prov_max", "gap_worse", "pos_worse"
  )) numbers[[field]] <- as.numeric(numbers[[field]])
  if (nrow(numbers) != 581L || anyDuplicated(numbers[c("country", "admin_name", "indicator")])) {
    stop("Supplied region profile numbers must contain 581 unique area-indicator rows.", call. = FALSE)
  }
  if (any(numbers$ci_l > numbers$prev) || any(numbers$prev > numbers$ci_u)) {
    stop("A supplied region profile estimate falls outside its 95% confidence interval.", call. = FALSE)
  }

  expected_numbers <- do.call(rbind, lapply(names(reports), function(country) {
    report <- reports[[country]]
    rows <- report$indicators
    direction <- report$definitions$direction[match(rows$indicator, report$definitions$id)]
    data.frame(
      country = country,
      admin_name = rows$admin_name,
      indicator = rows$indicator,
      direction = direction,
      latest_year = as.numeric(rows$latest_year),
      prev = as.numeric(rows$observed_latest_estimate),
      ci_l = as.numeric(rows$latest_ci_l),
      ci_u = as.numeric(rows$latest_ci_u),
      prevalence_rank = as.numeric(rows$prevalence_rank),
      n_units = report$rank_max,
      stringsAsFactors = FALSE
    )
  }))
  numbers$admin_name <- mapply(canonical_admin, numbers$country, numbers$admin_name, USE.NAMES = FALSE)
  key_fields <- c("country", "admin_name", "indicator")
  expected_numbers <- expected_numbers[do.call(order, expected_numbers[key_fields]), , drop = FALSE]
  numbers <- numbers[do.call(order, numbers[key_fields]), , drop = FALSE]
  expected_key <- do.call(paste, c(expected_numbers[key_fields], sep = "\r"))
  actual_key <- do.call(paste, c(numbers[key_fields], sep = "\r"))
  if (!identical(expected_key, actual_key)) {
    stop("Supplied region profile number keys do not match the dashboard inputs.", call. = FALSE)
  }
  if (!identical(as.character(numbers$direction), as.character(expected_numbers$direction))) {
    stop("Supplied region profile directions do not match the dashboard definitions.", call. = FALSE)
  }
  for (field in c("latest_year", "prev", "ci_l", "ci_u", "prevalence_rank", "n_units")) {
    difference <- abs(numbers[[field]] - expected_numbers[[field]])
    if (any(!is.finite(difference)) || max(difference) > tolerance) {
      stop("Supplied region profile values differ from dashboard inputs in ", field, ".", call. = FALSE)
    }
  }
  number_groups <- split(numbers, paste(numbers$country, numbers$indicator, sep = "\r"))
  for (rows in number_groups) {
    if (
      max(abs(rows$prov_avg - mean(rows$prev))) > 1e-5 ||
      max(abs(rows$prov_min - min(rows$prev))) > 1e-5 ||
      max(abs(rows$prov_max - max(rows$prev))) > 1e-5
    ) stop("Supplied profile distribution summaries do not match their area values.", call. = FALSE)
  }

  mortality <- read_report_csv(
    file.path(project_root, "data", "source", "region_profile_mortality.csv"),
    c(
      "country", "admin_name", "indicator", "prev", "ci_l", "ci_u", "n_units",
      "prov_avg", "prov_min", "prov_max", "pos_worse"
    ),
    "supplied region profile mortality"
  )
  for (field in c("prev", "ci_l", "ci_u", "n_units", "prov_avg", "prov_min", "prov_max", "pos_worse")) {
    mortality[[field]] <- as.numeric(mortality[[field]])
  }
  mortality$admin_name <- mapply(canonical_admin, mortality$country, mortality$admin_name, USE.NAMES = FALSE)
  if (
    nrow(mortality) != 222L ||
    anyDuplicated(mortality[c("country", "admin_name", "indicator")]) ||
    !setequal(unique(mortality$indicator), c("IMR", "NMR", "U5MR"))
  ) stop("Supplied mortality profiles must contain 222 unique IMR/NMR/U5MR rows.", call. = FALSE)
  if (any(mortality$ci_l > mortality$prev) || any(mortality$prev > mortality$ci_u)) {
    stop("A supplied mortality estimate falls outside its 95% confidence interval.", call. = FALSE)
  }
  for (country in names(reports)) {
    report <- reports[[country]]
    rows <- mortality[mortality$country == country, , drop = FALSE]
    if (
      nrow(rows) != report$rank_max * 3L ||
      !setequal(unique(rows$admin_name), report$composite$admin_name) ||
      any(rows$n_units != report$rank_max)
    ) stop(country, " supplied mortality profile coverage is incomplete.", call. = FALSE)
    latest_u5mr <- rows[rows$indicator == "U5MR", c("admin_name", "prev"), drop = FALSE]
    joined <- merge(report$mortality, latest_u5mr, by = "admin_name", all = TRUE, sort = FALSE)
    if (nrow(joined) != report$rank_max || anyNA(joined)) {
      stop(country, " supplied U5MR rows do not join to every dashboard area.", call. = FALSE)
    }
    if (max(abs(joined$u5mr_est_1000 - joined$prev)) > tolerance) {
      stop(country, " supplied U5MR values differ from the validated mortality input.", call. = FALSE)
    }
  }
  mortality_groups <- split(mortality, paste(mortality$country, mortality$indicator, sep = "\r"))
  for (rows in mortality_groups) {
    if (
      max(abs(rows$prov_avg - mean(rows$prev))) > 1e-10 ||
      max(abs(rows$prov_min - min(rows$prev))) > 1e-10 ||
      max(abs(rows$prov_max - max(rows$prev))) > 1e-10
    ) stop("Supplied mortality distribution summaries do not match their area values.", call. = FALSE)
  }
  invisible(list(numbers = numbers, mortality = mortality))
}
