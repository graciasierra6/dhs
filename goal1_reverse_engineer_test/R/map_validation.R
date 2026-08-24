map_validation_check <- function(condition, message, state) {
  if (!isTRUE(condition)) {
    stop("Map validation failed: ", message, call. = FALSE)
  }
  state$checks <- state$checks + 1L
  invisible(TRUE)
}

map_validation_coordinates <- function(node) {
  is_point <- is.list(node) && length(node) >= 2L && all(vapply(
    node[1:2],
    function(value) is.atomic(value) && length(value) == 1L && is.numeric(value),
    logical(1)
  ))
  if (is_point) {
    return(matrix(as.numeric(unlist(node[1:2])), nrow = 1L, ncol = 2L))
  }
  if (!is.list(node) || !length(node)) return(matrix(numeric(), ncol = 2L))
  pieces <- lapply(node, map_validation_coordinates)
  pieces <- pieces[vapply(pieces, nrow, integer(1)) > 0L]
  if (!length(pieces)) matrix(numeric(), ncol = 2L) else do.call(rbind, pieces)
}

map_validation_bbox <- function(geometry) {
  coordinates <- map_validation_coordinates(geometry$coordinates)
  if (!nrow(coordinates) || any(!is.finite(coordinates))) {
    stop("Map validation failed: geometry contains no finite coordinates.", call. = FALSE)
  }
  c(
    bbox_min_lon = min(coordinates[, 1]),
    bbox_min_lat = min(coordinates[, 2]),
    bbox_max_lon = max(coordinates[, 1]),
    bbox_max_lat = max(coordinates[, 2])
  )
}

map_validation_attribute <- function(markup, attribute) {
  pattern <- paste0('(?s).*\\b', attribute, '="([^"]*)".*')
  sub(pattern, "\\1", markup, perl = TRUE)
}

map_validation_fixed_count <- function(pattern, text) {
  matches <- gregexpr(pattern, text, fixed = TRUE)[[1]]
  if (identical(matches, -1L)) 0L else length(matches)
}

map_validation_hash <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Package 'digest' is required for boundary-file verification.", call. = FALSE)
  }
  tolower(digest::digest(object = path, algo = "sha256", file = TRUE, serialize = FALSE))
}

validate_map_build <- function(
  project_root = ".",
  online = FALSE,
  verbose = TRUE,
  html_text = NULL,
  html_path = NULL
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required for map validation.", call. = FALSE)
  }
  root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  state <- new.env(parent = emptyenv())
  state$checks <- 0L
  check <- function(condition, message) map_validation_check(condition, message, state)

  layer_manifest_path <- file.path(root, "data", "reference", "admin1_boundary_manifest.csv")
  feature_reference_path <- file.path(root, "data", "reference", "admin1_feature_reference.csv")
  check(file.exists(layer_manifest_path), "the boundary manifest is missing")
  check(file.exists(feature_reference_path), "the feature reference is missing")
  layers <- utils::read.csv(layer_manifest_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  references <- utils::read.csv(feature_reference_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  check(nrow(layers) == 3L, "the boundary manifest must contain exactly three country layers")
  check(nrow(references) == 74L, "the feature reference must contain exactly 74 ADM1 areas")
  check(!anyDuplicated(layers$country), "country layers are duplicated in the boundary manifest")
  check(!anyDuplicated(references[c("country", "dashboard_name")]), "dashboard area names are duplicated")
  check(!anyDuplicated(references[c("country", "shape_iso")]), "public ADM1 codes are duplicated")
  check(!anyDuplicated(references$shape_id), "public geoBoundaries shape IDs are duplicated")

  expected_dashboard_names <- list()
  expected_dashboard_ids <- list()

  for (layer_index in seq_len(nrow(layers))) {
    layer <- layers[layer_index, , drop = FALSE]
    country <- layer$country
    country_reference <- references[references$country == country, , drop = FALSE]
    country_reference <- country_reference[order(country_reference$feature_index), , drop = FALSE]
    path <- file.path(root, layer$project_file)
    check(file.exists(path), paste(country, "GeoJSON file is missing"))
    check(
      identical(map_validation_hash(path), tolower(layer$sha256)),
      paste(country, "GeoJSON bytes differ from the pinned public geoBoundaries file")
    )

    geo <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    check(identical(geo$type, "FeatureCollection"), paste(country, "GeoJSON is not a FeatureCollection"))
    check(length(geo$features) == layer$adm_unit_count, paste(country, "ADM1 feature count is incorrect"))
    check(nrow(country_reference) == layer$adm_unit_count, paste(country, "reference feature count is incorrect"))

    for (feature_position in seq_along(geo$features)) {
      feature <- geo$features[[feature_position]]
      reference <- country_reference[feature_position, , drop = FALSE]
      properties <- feature$properties
      expected_index <- feature_position - 1L
      check(reference$feature_index == expected_index, paste(country, "reference feature order is not contiguous"))
      check(properties$shapeName == reference$public_shape_name, paste(country, reference$dashboard_name, "public name mismatch"))
      check(properties$shapeISO == reference$shape_iso, paste(country, reference$dashboard_name, "ADM1 code mismatch"))
      check(properties$shapeID == reference$shape_id, paste(country, reference$dashboard_name, "geoBoundaries shape ID mismatch"))
      check(properties$shapeGroup == layer$iso3, paste(country, reference$dashboard_name, "country code mismatch"))
      check(properties$shapeType == "ADM1", paste(country, reference$dashboard_name, "administrative level mismatch"))
      check(feature$geometry$type %in% c("Polygon", "MultiPolygon"), paste(country, reference$dashboard_name, "unsupported geometry type"))

      bbox <- map_validation_bbox(feature$geometry)
      expected_bbox <- as.numeric(unlist(
        reference[c("bbox_min_lon", "bbox_min_lat", "bbox_max_lon", "bbox_max_lat")],
        use.names = FALSE
      ))
      check(
        max(abs(as.numeric(bbox) - expected_bbox)) <= 1e-8,
        paste(country, reference$dashboard_name, "geometry is not in its pinned public-map location")
      )
      check(bbox[["bbox_min_lon"]] >= -180 && bbox[["bbox_max_lon"]] <= 180, paste(country, reference$dashboard_name, "longitude is out of range"))
      check(bbox[["bbox_min_lat"]] >= -90 && bbox[["bbox_max_lat"]] <= 90, paste(country, reference$dashboard_name, "latitude is out of range"))
      center <- c(
        (bbox[["bbox_min_lon"]] + bbox[["bbox_max_lon"]]) / 2,
        (bbox[["bbox_min_lat"]] + bbox[["bbox_max_lat"]]) / 2
      )
      check(
        max(abs(center - c(reference$bbox_center_lon, reference$bbox_center_lat))) <= 1e-8,
        paste(country, reference$dashboard_name, "reference location center mismatch")
      )
    }

    expected_dashboard_names[[country]] <- country_reference$dashboard_name
    slug <- c(DRC = "drc", Ethiopia = "ethiopia", Nigeria = "nigeria")[[country]]
    expected_dashboard_ids[[country]] <- paste0(slug, "-shape-", country_reference$feature_index)

    if (isTRUE(online)) {
      api_url <- paste0("https://www.geoboundaries.org/api/current/gbOpen/", layer$iso3, "/ADM1/")
      metadata <- jsonlite::fromJSON(api_url, simplifyVector = TRUE)
      check(metadata$boundaryID == layer$boundary_id, paste(country, "current public boundary ID differs from the pinned source"))
      check(as.character(metadata$boundaryYearRepresented) == as.character(layer$boundary_year), paste(country, "public boundary year differs"))
      check(as.integer(metadata$admUnitCount) == layer$adm_unit_count, paste(country, "public ADM1 count differs"))
      current_url <- if (layer$reference_variant == "simplified") metadata$simplifiedGeometryGeoJSON else metadata$gjDownloadURL
      public_copy <- tempfile(fileext = ".geojson")
      on.exit(unlink(public_copy), add = TRUE)
      utils::download.file(current_url, public_copy, mode = "wb", quiet = TRUE)
      check(
        identical(map_validation_hash(public_copy), tolower(layer$sha256)),
        paste(country, "current public geoBoundaries download differs from the pinned source")
      )
    }
  }

  composite_path <- file.path(root, "data", "composite_indicator_rankings.csv")
  indicators_path <- file.path(root, "data", "subnational_indicator_rankings.csv")
  check(file.exists(composite_path), "composite input is missing")
  check(file.exists(indicators_path), "indicator input is missing")
  composite <- utils::read.csv(composite_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  indicators <- utils::read.csv(indicators_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  for (country in names(expected_dashboard_names)) {
    public_names <- sort(expected_dashboard_names[[country]])
    composite_names <- sort(unique(composite$admin_name[composite$country == country & composite$composite_set == "standard"]))
    indicator_names <- sort(unique(indicators$admin_name[indicators$country == country]))
    check(identical(composite_names, public_names), paste(country, "composite names do not match public ADM1 areas"))
    check(identical(indicator_names, public_names), paste(country, "indicator names do not match public ADM1 areas"))
  }

  if (is.null(html_path)) html_path <- file.path(root, "output", "goal1_reverse_engineer_test.html")
  html <- if (is.null(html_text)) {
    check(file.exists(html_path), "rendered dashboard HTML is missing")
    paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  } else {
    paste(as.character(html_text), collapse = "\n")
  }
  json_match <- regmatches(
    html,
    regexpr('<script id="dashboard-data" type="application/json">.*?</script>', html, perl = TRUE)
  )
  use_markup <- regmatches(html, gregexpr('(?s)<use class="map-region[^>]*>.*?</use>', html, perl = TRUE))[[1]]
  has_dashboard_payload <- length(json_match) == 1L && nzchar(json_match)
  uses_per_country <- if (has_dashboard_payload) {
    c(DRC = 5L, Ethiopia = 5L, Nigeria = 5L)
  } else {
    c(DRC = 5L, Ethiopia = 4L, Nigeria = 4L)
  }
  expected_use_total <- sum(vapply(names(expected_dashboard_names), function(country) {
    length(expected_dashboard_names[[country]]) * uses_per_country[[country]]
  }, integer(1)))
  check(
    length(use_markup) == expected_use_total,
    paste("rendered dashboard must contain", expected_use_total, "administrative map regions")
  )
  use_names <- vapply(use_markup, map_validation_attribute, character(1), attribute = "data-name")
  use_ids <- vapply(use_markup, map_validation_attribute, character(1), attribute = "href")
  use_ids <- sub("^#", "", use_ids)

  payload_by_country <- NULL
  if (has_dashboard_payload) {
    json_text <- sub('^<script id="dashboard-data" type="application/json">', "", json_match)
    json_text <- sub('</script>$', "", json_text)
    payload <- jsonlite::fromJSON(json_text, simplifyDataFrame = FALSE)
    payload_by_country <- stats::setNames(
      payload$countries,
      vapply(payload$countries, `[[`, character(1), "country")
    )
  }

  for (country in names(expected_dashboard_names)) {
    expected_names <- expected_dashboard_names[[country]]
    expected_ids <- expected_dashboard_ids[[country]]
    if (has_dashboard_payload) {
      payload_country <- payload_by_country[[country]]
      check(!is.null(payload_country), paste(country, "is missing from the rendered dashboard payload"))
      check(identical(unlist(payload_country$shape_names), expected_names), paste(country, "payload shape names are out of order or mislabeled"))
      check(identical(unlist(payload_country$shape_ids), expected_ids), paste(country, "payload shape IDs are out of order"))
    }
    for (feature_index in seq_along(expected_names)) {
      expected_name <- expected_names[[feature_index]]
      expected_id <- expected_ids[[feature_index]]
      pair_count <- sum(use_names == expected_name & use_ids == expected_id)
      check(
        pair_count == uses_per_country[[country]],
        paste(country, expected_name, "does not point to its own geometry in every rendered map")
      )
      check(
        map_validation_fixed_count(paste0('id="', expected_id, '"'), html) == 1L,
        paste(country, expected_name, "SVG geometry definition is missing or duplicated")
      )
    }
  }

  if (isTRUE(verbose)) {
    cat(
      "Map validation passed:", state$checks, "checks;",
      "74 public ADM1 names/codes/locations;", expected_use_total,
      "rendered map regions; no swapped name-to-shape joins.",
      if (isTRUE(online)) "Public geoBoundaries downloads rechecked online.\n" else "Pinned public-source hashes checked offline.\n"
    )
  }
  invisible(list(checks = state$checks, online = isTRUE(online)))
}
