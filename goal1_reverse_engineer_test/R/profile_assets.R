profile_asset_archive <- function(chart_type, project_root = ".") {
  if (!chart_type %in% c("profiles", "change")) {
    stop("Unknown profile chart type: ", chart_type, call. = FALSE)
  }
  file.path(project_root, "assets", paste0("profile-plots-", chart_type, ".zip"))
}

profile_read_archive_member <- function(archive_path, member) {
  if (!file.exists(archive_path)) {
    stop("Missing profile asset archive: ", archive_path, call. = FALSE)
  }
  connection <- unz(archive_path, member, open = "rb")
  on.exit(close(connection), add = TRUE)
  tryCatch(
    readBin(connection, what = "raw", n = 1e9),
    error = function(error) {
      stop("Could not read ", member, " from ", archive_path, ": ", conditionMessage(error), call. = FALSE)
    }
  )
}

profile_asset_raw <- function(asset_path, project_root = ".") {
  logical_path <- gsub("\\\\", "/", asset_path)
  match <- regexec(
    "^assets/profile-plots/(profiles|change)/(DRC|Ethiopia|Nigeria)/[^/]+\\.png$",
    logical_path
  )
  capture <- regmatches(logical_path, match)[[1]]
  if (length(capture) != 3L) {
    stop("Invalid profile archive member path: ", logical_path, call. = FALSE)
  }
  chart_type <- capture[2]
  member <- sub("^assets/profile-plots/", "", logical_path)
  profile_read_archive_member(profile_asset_archive(chart_type, project_root), member)
}

profile_png_dimensions <- function(bytes, label = "profile image") {
  header <- bytes[seq_len(min(length(bytes), 24L))]
  png_signature <- as.raw(c(137, 80, 78, 71, 13, 10, 26, 10))
  if (length(header) != 24L || !identical(header[1:8], png_signature)) {
    stop("Invalid PNG asset: ", label, call. = FALSE)
  }
  decode_uint32 <- function(bytes) {
    sum(as.numeric(as.integer(bytes)) * c(256^3, 256^2, 256, 1))
  }
  c(width = decode_uint32(header[17:20]), height = decode_uint32(header[21:24]))
}

profile_asset_catalog <- function(reports, project_root = ".") {
  chart_types <- c("profiles", "change")
  archives <- stats::setNames(lapply(chart_types, function(chart_type) {
    archive_path <- profile_asset_archive(chart_type, project_root)
    if (!file.exists(archive_path)) {
      stop("Missing profile asset archive: ", archive_path, call. = FALSE)
    }
    archive_listing <- utils::unzip(archive_path, list = TRUE)
    members <- archive_listing$Name[
      grepl(
        paste0("^", chart_type, "/(DRC|Ethiopia|Nigeria)/[^/]+\\.png$"),
        archive_listing$Name
      )
    ]
    if (length(members) != 74L || anyDuplicated(members)) {
      stop("The ", chart_type, " asset archive must contain exactly 74 uniquely named PNGs.", call. = FALSE)
    }
    list(path = archive_path, members = members)
  }), chart_types)
  rows <- list()
  row_index <- 0L
  for (chart_type in chart_types) {
    archive_path <- archives[[chart_type]]$path
    archive_members <- archives[[chart_type]]$members
    for (country in names(reports)) {
      areas <- reports[[country]]$composite$admin_name
      prefix <- paste0(chart_type, "/", country, "/")
      members <- archive_members[startsWith(archive_members, prefix)]
      if (length(members) != length(areas)) {
        stop(
          chart_type, "/", country, " must contain exactly ", length(areas),
          " PNGs in the asset archive; found ", length(members), ".", call. = FALSE
        )
      }
      stems <- sub("\\.png$", "", basename(members))
      stems <- sub(paste0("^", country, "_"), "", stems)
      if (identical(chart_type, "change")) stems <- sub("_change$", "", stems)
      file_keys <- normalize_admin_key(stems)
      area_keys <- normalize_admin_key(areas)
      if (anyDuplicated(file_keys) || !setequal(file_keys, area_keys)) {
        stop(chart_type, "/", country, " PNG names do not match the dashboard areas.", call. = FALSE)
      }
      matched <- match(area_keys, file_keys)
      members <- members[matched]
      images <- lapply(members, function(member) profile_read_archive_member(archive_path, member))
      dimensions <- t(vapply(seq_along(images), function(index) {
        profile_png_dimensions(images[[index]], members[index])
      }, numeric(2)))
      relative_paths <- file.path(
        "assets", "profile-plots", chart_type, country, basename(members)
      )
      for (index in seq_along(areas)) {
        row_index <- row_index + 1L
        rows[[row_index]] <- data.frame(
          chart_type = chart_type,
          country = country,
          admin_name = areas[index],
          asset_path = gsub("\\\\", "/", relative_paths[index]),
          mime_type = "image/png",
          bytes = as.numeric(length(images[[index]])),
          width = as.integer(dimensions[index, "width"]),
          height = as.integer(dimensions[index, "height"]),
          sha256 = digest::digest(images[[index]], algo = "sha256", serialize = FALSE),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  catalog <- do.call(rbind, rows)
  rownames(catalog) <- NULL
  catalog[order(catalog$chart_type, catalog$country, catalog$admin_name), , drop = FALSE]
}

write_profile_asset_manifest <- function(reports, project_root = ".") {
  catalog <- profile_asset_catalog(reports, project_root)
  path <- file.path(project_root, "artifacts", "profile_images_manifest.csv")
  utils::write.csv(catalog, path, row.names = FALSE, fileEncoding = "UTF-8", na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

validate_profile_asset_manifest <- function(reports, project_root = ".") {
  path <- file.path(project_root, "artifacts", "profile_images_manifest.csv")
  manifest <- read_report_csv(
    path,
    c(
      "chart_type", "country", "admin_name", "asset_path", "mime_type",
      "bytes", "width", "height", "sha256"
    ),
    "profile image manifest"
  )
  actual <- profile_asset_catalog(reports, project_root)
  manifest <- manifest[order(manifest$chart_type, manifest$country, manifest$admin_name), , drop = FALSE]
  rownames(manifest) <- NULL
  if (nrow(manifest) != 148L || nrow(actual) != 148L) {
    stop("The profile asset manifest must contain 148 PNGs.", call. = FALSE)
  }
  text_fields <- c("chart_type", "country", "admin_name", "asset_path", "mime_type", "sha256")
  numeric_fields <- c("bytes", "width", "height")
  for (field in text_fields) {
    if (!identical(as.character(manifest[[field]]), as.character(actual[[field]]))) {
      stop("Profile asset manifest mismatch in ", field, ".", call. = FALSE)
    }
  }
  for (field in numeric_fields) {
    if (!identical(as.numeric(manifest[[field]]), as.numeric(actual[[field]]))) {
      stop("Profile asset manifest mismatch in ", field, ".", call. = FALSE)
    }
  }
  chart_counts <- table(manifest$chart_type)
  if (
    !identical(sort(names(chart_counts)), c("change", "profiles")) ||
    any(as.integer(chart_counts[c("change", "profiles")]) != c(74L, 74L))
  ) {
    stop("The profile asset manifest must contain 74 profile and 74 change PNGs.", call. = FALSE)
  }
  invisible(manifest)
}

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
  for (field in c("latest_year", "prev", "prevalence_rank", "n_units")) {
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
