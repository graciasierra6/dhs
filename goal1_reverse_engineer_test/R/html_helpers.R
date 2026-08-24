purple_scale <- c("#FFF7F3", "#FDE0DD", "#FCC5C0", "#FA9FB5", "#F768A1", "#DD3497", "#AE017E", "#7A0177", "#49006A")
count_palette_ylgn <- c(
  "#FFFFE5", "#F7FCB9", "#D9F0A3", "#ADDD8E", "#78C679",
  "#41AB5D", "#238443", "#006837", "#004529"
)
count_labels <- c(paste0("0", intToUtf8(0x2013), "1"), paste0("2", intToUtf8(0x2013), "3"), "4", paste0("5", intToUtf8(0x2013), "6"))
drc_count_labels <- count_labels
other_count_labels <- count_labels
count_colors <- stats::setNames(count_palette_ylgn[c(1, 4, 6, 9)], other_count_labels)
drc_count_colors <- stats::setNames(count_palette_ylgn[c(1, 4, 6, 9)], drc_count_labels)
bivariate_palette_stevens_greenblue <- c(
  "#F0EEE4", "#E8BC8D", "#DF8A36", "#80B0A6", "#86856A",
  "#8C592E", "#107369", "#254E48", "#3A2826"
)
bivariate_colors <- stats::setNames(
  bivariate_palette_stevens_greenblue,
  c(
    "improving:worsening", "inside_threshold:worsening", "worsening:worsening",
    "improving:inside_threshold", "inside_threshold:inside_threshold", "worsening:inside_threshold",
    "improving:improving", "inside_threshold:improving", "worsening:improving"
  )
)
bivariate_prevalence_colors <- stats::setNames(
  bivariate_palette_stevens_greenblue,
  c(
    "low:high", "middle:high", "high:high",
    "low:middle", "middle:middle", "high:middle",
    "low:low", "middle:low", "high:low"
  )
)

html_escape <- function(value) {
  value <- as.character(value)
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value
}

html_attr <- function(value) {
  value <- html_escape(value)
  value <- gsub('"', "&quot;", value, fixed = TRUE)
  gsub("'", "&#39;", value, fixed = TRUE)
}

format_number <- function(value, digits = 1) {
  formatC(as.numeric(value), format = "f", digits = digits, big.mark = ",")
}

median_value <- function(values) stats::median(as.numeric(values), na.rm = TRUE)

prevalence_class <- function(value, values) {
  thresholds <- stats::quantile(as.numeric(values), probs = c(1 / 3, 2 / 3), na.rm = TRUE, type = 7, names = FALSE)
  if (as.numeric(value) <= thresholds[1]) return("low")
  if (as.numeric(value) <= thresholds[2]) return("middle")
  "high"
}

color_for_rank <- function(rank, maximum) {
  progress <- if (maximum <= 1) 0 else (as.numeric(rank) - 1) / (maximum - 1)
  index <- min(length(purple_scale), floor(progress * length(purple_scale)) + 1)
  purple_scale[index]
}

color_for_value <- function(value, minimum, maximum, reverse = FALSE) {
  progress <- if (maximum == minimum) 0.5 else (as.numeric(value) - minimum) / (maximum - minimum)
  index <- min(length(purple_scale), floor(progress * length(purple_scale)) + 1)
  if (reverse) index <- length(purple_scale) + 1 - index
  purple_scale[index]
}

count_colors_for_country <- function(country) {
  if (identical(country, "DRC")) drc_count_colors else count_colors
}

count_bucket <- function(value, country) {
  value <- as.integer(value)
  if (identical(country, "DRC")) {
    if (value < 1L || value > 6L) stop("DRC worsening count must be between 1 and 6.", call. = FALSE)
    if (value == 1L) return(drc_count_labels[1])
    if (value <= 3L) return(drc_count_labels[2])
    if (value == 4L) return("4")
    return(drc_count_labels[4])
  }
  if (value < 0L || value > 6L) stop("Ethiopia and Nigeria worsening counts must be between 0 and 6.", call. = FALSE)
  if (value <= 1L) return(other_count_labels[1])
  if (value <= 3L) return(other_count_labels[2])
  if (value == 4L) return("4")
  other_count_labels[4]
}

named_rows <- function(data, key = "admin_name") {
  split(data, as.character(data[[key]]))
}

section_heading <- function(index, title) {
  paste0(
    '<div class="section-heading"><span class="section-index">', html_escape(index),
    '</span><div><h3>', html_escape(title), "</h3></div></div>"
  )
}

purple_legend <- function(title, top_label, bottom_label) {
  swatches <- paste0('<i style="background:', rev(purple_scale), '"></i>', collapse = "")
  paste0(
    '<div class="map-legend"><strong>', html_escape(title), "</strong><span data-role=\"legend-top\">", html_escape(top_label),
    '</span><div class="legend-swatches">', swatches, '</div><span data-role="legend-bottom">',
    html_escape(bottom_label), "</span></div>"
  )
}

map_definitions_markup <- function(features) {
  paths <- vapply(features, function(feature) {
    paste0('<path id="', html_attr(feature$id), '" d="', html_attr(feature$path), '"></path>')
  }, character(1))
  paste0(
    '<svg aria-hidden="true" width="0" height="0" style="position:absolute;width:0;height:0;overflow:hidden" ',
    'xmlns="http://www.w3.org/2000/svg"><defs>', paste(paths, collapse = ""), "</defs></svg>"
  )
}

feature_view_box <- function(features, padding = 1) {
  values <- unlist(lapply(features, function(feature) {
    matches <- regmatches(feature$path, gregexpr("-?[0-9]+(?:\\.[0-9]+)?", feature$path, perl = TRUE))[[1]]
    as.numeric(matches)
  }), use.names = FALSE)
  if (!length(values) || length(values) %% 2L != 0L || any(!is.finite(values))) {
    stop("Map feature paths do not contain valid coordinate pairs.", call. = FALSE)
  }
  x_values <- values[seq.int(1L, length(values), by = 2L)]
  y_values <- values[seq.int(2L, length(values), by = 2L)]
  x_min <- floor(min(x_values)) - padding
  y_min <- floor(min(y_values)) - padding
  width <- ceiling(max(x_values)) + padding - x_min
  height <- ceiling(max(y_values)) + padding - y_min
  paste(x_min, y_min, width, height)
}

map_markup <- function(
  id,
  title,
  aria_label,
  features,
  data_by_name,
  fill_function,
  tooltip_function,
  legend = "",
  class_name = "",
  region_class = "",
  region_role = NULL,
  preserve_aspect_ratio = "xMidYMid meet",
  view_box = "0 0 720 460"
) {
  regions <- vapply(features, function(feature) {
    datum <- data_by_name[[feature$name]]
    tooltip <- tooltip_function(feature$name, datum)
    fill <- fill_function(datum)
    paste0(
      '<use class="map-region ', region_class, '" data-name="', html_attr(feature$name), '" data-tip="', html_attr(tooltip),
      '" href="#', html_attr(feature$id), '" xlink:href="#', html_attr(feature$id), '" fill="', html_attr(fill),
      '" tabindex="0"', if (!is.null(region_role)) paste0(' role="', html_attr(region_role), '"') else "",
      ' aria-label="', html_attr(gsub("\n", ", ", tooltip, fixed = TRUE)), '"></use>'
    )
  }, character(1))
  paste0(
    '<div class="map-shell ', class_name, '" id="', html_attr(id), '-shell">',
    '<h4 class="map-title" data-role="map-title">', html_escape(title), "</h4>",
    '<svg class="geo-map" viewBox="', html_attr(view_box), '" preserveAspectRatio="', html_attr(preserve_aspect_ratio),
    '" role="img" aria-label="', html_attr(aria_label), '" ',
    'xmlns:xlink="http://www.w3.org/1999/xlink" fill-rule="evenodd">', paste(regions, collapse = ""), "</svg>",
    '<div class="map-tooltip standalone-tooltip" aria-live="polite"></div>', legend, "</div>"
  )
}

rank_section_markup <- function(report, features, kind, index) {
  prevalence <- identical(kind, "prevalence")
  profile_enabled <- prevalence
  rank_field <- if (prevalence) "composite_prevalence_rank" else "composite_change_rank"
  score_field <- if (prevalence) "composite_prevalence_score" else "composite_change_score"
  heading <- if (prevalence) "Current Prevalence Rank" else "Indicator Change Rank"
  map_metric <- if (prevalence) "Current Prevalence" else "Indicator Change"
  map_title <- paste0(report$short_name, " | Composite Rank - ", map_metric)
  rows <- report$composite[order(report$composite[[rank_field]], report$composite$admin_name), , drop = FALSE]
  by_name <- named_rows(rows)
  map <- map_markup(
    id = paste0(report$slug, "-rank-", kind),
    title = map_title,
    aria_label = paste(report$country_name, "administrative map"),
    features = features,
    data_by_name = by_name,
    fill_function = function(row) if (is.null(row)) "#E7E2E8" else color_for_rank(row[[rank_field]][1], report$rank_max),
    tooltip_function = function(name, row) {
      if (is.null(row)) return(paste(name, "No data", sep = "\n"))
      paste(
        name,
        paste0("Rank ", row[[rank_field]][1], " / ", report$rank_max),
        paste0("Composite score ", format_number(row[[score_field]][1], 3)),
        sep = "\n"
      )
    },
    legend = purple_legend("Composite Rank", paste0(report$rank_max, " (worst)"), "1 (best)"),
    region_class = if (profile_enabled) "profile-trigger" else "",
    region_role = if (profile_enabled) "button" else NULL
  )
  rank_rows <- paste(vapply(seq_len(nrow(rows)), function(row_index) {
    row <- rows[row_index, , drop = FALSE]
    paste0(
      '<div class="rank-row"><span><i style="background:', color_for_rank(row[[rank_field]][1], report$rank_max), '"></i>',
      html_escape(row$admin_name), "</span><strong>", row[[rank_field]][1], "</strong></div>"
    )
  }, character(1)), collapse = "")
  overview <- paste0(
    '<div class="section-grid map-and-list"', if (profile_enabled) ' data-role="prevalence-overview"' else "", '>', map,
    '<div class="rank-list"><div class="rank-list-head"><span>', html_escape(report$area_singular),
    '</span><span>Rank</span></div><div class="rank-list-scroll">', rank_rows, "</div></div></div>"
  )
  profile <- if (profile_enabled) paste0(
    '<div class="province-profile" data-role="province-profile" hidden>',
    '<button type="button" class="profile-back" data-role="profile-back">&larr; Back to prevalence map</button>',
    '<div class="province-profile-header"><div class="province-profile-identity">',
    '<p class="eyebrow">', html_escape(report$area_singular), ' profile</p><h4 data-role="profile-name">',
    html_escape(report$area_singular), "</h4>",
    '<div class="u5mr-result"><span>Under-five mortality</span><strong>',
    '<span data-role="profile-u5mr">&mdash;</span> per 1,000 live births</strong></div>',
    '</div>',
    '<div class="profile-rank-box"><span>Composite prevalence rank</span>',
    '<strong data-role="profile-rank">&mdash; / ', report$rank_max, '</strong></div></div>',
    '<div class="profile-table-wrap"><table class="profile-table">',
    '<thead><tr><th>Indicator</th><th>Observed year</th><th>Latest prevalence</th></tr></thead>',
    '<tbody data-role="profile-indicators"></tbody></table></div></div>'
  ) else ""
  paste0(
    '<section id="', report$slug, "-", kind, '" class="analysis-section">', section_heading(index, heading),
    overview, profile, "</section>"
  )
}

indicator_prevalence_map_markup <- function(report, features, definition) {
  rows <- report$indicators[report$indicators$indicator == definition$id, , drop = FALSE]
  rows <- rows[order(rows$admin_name), , drop = FALSE]
  by_name <- named_rows(rows)
  values <- rows$observed_latest_estimate
  minimum <- min(values, na.rm = TRUE)
  maximum <- max(values, na.rm = TRUE)
  years <- sort(unique(rows$latest_year))
  map <- map_markup(
    id = paste0(report$slug, "-indicator-", definition$id, "-map"),
    title = definition$label,
    aria_label = paste(report$country_name, definition$label, "prevalence map"),
    features = features,
    data_by_name = by_name,
    region_class = "indicator-prevalence-region",
    class_name = "indicator-static-map",
    fill_function = function(row) {
      if (is.null(row)) return("#E7E2E8")
      color_for_value(row$observed_latest_estimate[1], minimum, maximum, definition$direction == "beneficial")
    },
    tooltip_function = function(name, row) {
      if (is.null(row)) return(paste(name, "No data", sep = "\n"))
      paste(
        name,
        paste0(definition$label, ": ", format_number(row$observed_latest_estimate[1]), "%"),
        sep = "\n"
      )
    },
    legend = purple_legend(
      "Value",
      paste0(format_number(if (definition$direction == "beneficial") minimum else maximum, 0), "%"),
      paste0(format_number(if (definition$direction == "beneficial") maximum else minimum, 0), "%")
    )
  )
  paste0(
    '<article class="indicator-map-card" data-prevalence-indicator="', html_attr(definition$id), '">',
    '<p class="indicator-map-year"><span>Observed year</span><strong>', paste(years, collapse = ", "), "</strong></p>",
    map, "</article>"
  )
}

indicator_section_markup <- function(report, features) {
  maps <- paste(vapply(seq_len(nrow(report$definitions)), function(row_index) {
    indicator_prevalence_map_markup(report, features, report$definitions[row_index, , drop = FALSE])
  }, character(1)), collapse = "")
  paste0(
    '<section id="', report$slug, '-indicators" class="analysis-section indicator-section">',
    section_heading("03", "Indicator Prevalence Maps"),
    '<p class="indicator-map-intro">Each map uses the observed prevalence value from the year shown.</p>',
    '<div class="indicator-map-grid">', maps, "</div></section>"
  )
}

distribution_markup <- function(report) {
  summary_rows <- report$summary
  specifications <- list(
    list(key = "worsening_count", label = "Worsening", class_name = "worsening"),
    list(key = "improving_count", label = "Improving", class_name = "improving")
  )
  maximum_indicators <- max(vapply(summary_rows, `[[`, numeric(1), "total_indicators"))
  frequency_lists <- lapply(specifications, function(specification) {
    values <- vapply(summary_rows, `[[`, numeric(1), specification$key)
    frequencies <- vapply(0:maximum_indicators, function(count) sum(values == count), numeric(1))
    c(specification, list(values = values, frequencies = frequencies))
  })
  maximum_frequency <- max(unlist(lapply(frequency_lists, `[[`, "frequencies")), 1)
  panels <- paste(vapply(frequency_lists, function(item) {
    rows <- paste(vapply(seq_along(item$frequencies), function(index) {
      count <- index - 1
      areas <- item$frequencies[index]
      paste0(
        '<div class="distribution-row"><span>', count, '</span><div><i style="width:',
        (areas / maximum_frequency) * 100, '%"></i></div><b>', areas, "</b></div>"
      )
    }, character(1)), collapse = "")
    paste0(
      '<div class="distribution-panel ', item$class_name, '"><div class="distribution-panel-head"><h5>', item$label,
      '</h5><span>Median <b>', format_number(median_value(item$values)), '</b></span></div>',
      '<div class="distribution-axis"><span>Indicators</span><span>', html_escape(report$area_plural),
      '</span></div><div class="distribution-bars">', rows, "</div></div>"
    )
  }, character(1)), collapse = "")
  paste0(
    '<div class="overall-distributions"><div class="subsection-label"><span>01</span><div><h4>Overall Distributions</h4></div></div>',
    '<div class="distribution-grid">', panels, "</div></div>"
  )
}

summary_to_frame <- function(summary_rows) {
  data.frame(
    admin_name = vapply(summary_rows, `[[`, character(1), "admin_name"),
    worsening_count = vapply(summary_rows, `[[`, numeric(1), "worsening_count"),
    improving_count = vapply(summary_rows, `[[`, numeric(1), "improving_count"),
    inside_threshold_count = vapply(summary_rows, `[[`, numeric(1), "inside_threshold_count"),
    total_indicators = vapply(summary_rows, `[[`, numeric(1), "total_indicators"),
    stringsAsFactors = FALSE
  )
}

count_section_markup <- function(report, features, input_file, indicator_file) {
  summary_frame <- summary_to_frame(report$summary)
  by_name <- named_rows(summary_frame)
  summary_lookup <- stats::setNames(report$summary, vapply(report$summary, `[[`, character(1), "admin_name"))
  maximum_count <- max(summary_frame$worsening_count)
  assessed <- report$definitions$label[report$definitions$id %in% unique(report$classifications$indicator)]
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
        sep = "\n"
      )
    },
    legend = paste0(
      '<div class="map-legend count-legend"><strong>Number of<br>worsening indicators</strong>',
      '<div class="discrete-legend">', discrete, "</div></div>"
    ),
    preserve_aspect_ratio = "xMinYMin meet",
    view_box = feature_view_box(features)
  )
  table_rows <- paste(vapply(seq_along(report$summary), function(index) {
    row <- report$summary[[index]]
    paste0(
      "<tr><td>", index, "</td><th scope=\"row\">", html_escape(row$admin_name), "</th>",
      '<td><span class="count-pill worsening">', row$worsening_count, "</span></td>",
      '<td><span class="count-pill improving">', row$improving_count, "</span></td>",
      '<td class="indicator-list-cell">',
      html_escape(if (length(row$worsening_indicators)) paste(row$worsening_indicators, collapse = ", ") else "None"),
      "</td></tr>"
    )
  }, character(1)), collapse = "")
  paste0(
    '<section id="', report$slug, '-counts" class="analysis-section count-section">',
    section_heading("04", "Worsening Count Map"),
    '<div class="count-kpis"><div><span>Highest count</span><strong>', maximum_count, "</strong><p>",
    html_escape(report$summary[[1]]$admin_name), '</p></div><div><span>Median count</span><strong>',
    format_number(median_value(summary_frame$worsening_count)), '</strong><p>across ', nrow(summary_frame), " ",
    html_escape(report$area_plural), "</p></div>",
    '<div class="indicators-assessed-card"><span>Indicators assessed</span><strong>', length(assessed), "</strong><ul>",
    paste0("<li>", html_escape(assessed), "</li>", collapse = ""), "</ul></div></div>",
    distribution_markup(report),
    '<div class="count-map-block"><div class="subsection-label"><span>02</span><div><h4>Count Map</h4></div></div>',
    map, '<p class="map-source">Sources: ', html_escape(basename(input_file)), "; ",
    html_escape(basename(indicator_file)), "</p></div>",
    '<div class="table-block"><div class="subsection-label"><span>03</span><div><h4>',
    html_escape(report$area_singular), ' Classification Table</h4></div></div>',
    '<div class="table-scroll"><table><thead><tr><th>Rank</th><th>', html_escape(report$area_singular),
    '</th><th>Worsening</th><th>Improving</th><th>Indicators worsening</th></tr></thead><tbody>',
    table_rows, "</tbody></table></div></div></section>"
  )
}

bivariate_legend <- function(x_label, y_label) {
  x_statuses <- c("improving", "inside_threshold", "worsening")
  y_statuses <- c("worsening", "inside_threshold", "improving")
  cells <- paste(unlist(lapply(y_statuses, function(y) {
    vapply(x_statuses, function(x) {
      paste0('<i style="background:', bivariate_colors[[paste(x, y, sep = ":")]], '"></i>')
    }, character(1))
  })), collapse = "")
  paste0(
    '<div class="bivariate-side-legend"><h4>Risk-Aligned Change Classification</h4><div class="bivariate-legend">',
    '<div class="biv-y-label"><span data-role="biv-y-label">', html_escape(y_label),
    '</span><small>Improving &rarr; Worsening</small></div><div class="biv-grid">', cells,
    '</div><div class="biv-x-label"><span data-role="biv-x-label">', html_escape(x_label),
    "</span><small>Improving &rarr; Worsening</small></div></div></div>"
  )
}

bivariate_prevalence_legend <- function(x_label, y_label) {
  x_classes <- c("low", "middle", "high")
  y_classes <- c("high", "middle", "low")
  cells <- paste(unlist(lapply(y_classes, function(y) {
    vapply(x_classes, function(x) {
      paste0('<i style="background:', bivariate_prevalence_colors[[paste(x, y, sep = ":")]], '"></i>')
    }, character(1))
  })), collapse = "")
  paste0(
    '<div class="bivariate-side-legend"><h4>Observed Prevalence Class</h4><div class="bivariate-legend">',
    '<div class="biv-y-label"><span data-role="biv-y-label">', html_escape(y_label),
    '</span><small>Low &rarr; High</small></div><div class="biv-grid">', cells,
    '</div><div class="biv-x-label"><span data-role="biv-x-label">', html_escape(x_label),
    "</span><small>Low &rarr; High</small></div></div></div>"
  )
}

bivariate_section_markup <- function(report, features) {
  x_definition <- report$definitions[1, ]
  y_definition <- report$definitions[2, ]
  lookup_key <- paste(report$classifications$admin_name, report$classifications$indicator, sep = "|")
  classification_lookup <- split(report$classifications, lookup_key)
  rows <- lapply(report$composite$admin_name, function(admin) {
    list(
      admin_name = admin,
      x = classification_lookup[[paste(admin, x_definition$id, sep = "|")]],
      y = classification_lookup[[paste(admin, y_definition$id, sep = "|")]]
    )
  })
  by_name <- stats::setNames(rows, vapply(rows, `[[`, character(1), "admin_name"))
  both <- sum(vapply(rows, function(row) {
    !is.null(row$x) && !is.null(row$y) &&
      row$x$classification[1] == "worsening" && row$y$classification[1] == "worsening"
  }, logical(1)))
  options <- paste0(
    '<option value="', html_attr(report$definitions$id), '">', html_escape(report$definitions$label), "</option>",
    collapse = ""
  )
  map <- map_markup(
    id = paste0(report$slug, "-biv-map"),
    title = paste(x_definition$short_label, y_definition$short_label, sep = " x "),
    aria_label = paste(report$country_name, "administrative map"),
    features = features,
    data_by_name = by_name,
    class_name = "bivariate-map",
    region_class = "biv-region",
    fill_function = function(row) {
      if (is.null(row) || is.null(row$x) || is.null(row$y)) return("#E7E2E8")
      bivariate_colors[[paste(row$x$classification[1], row$y$classification[1], sep = ":")]]
    },
    tooltip_function = function(name, row) {
      if (is.null(row) || is.null(row$x) || is.null(row$y)) return(paste(name, "No paired data", sep = "\n"))
      x <- row$x[1, ]
      y <- row$y[1, ]
      x_measure <- if (x_definition$direction == "beneficial") "coverage" else "prevalence"
      y_measure <- if (y_definition$direction == "beneficial") "coverage" else "prevalence"
      paste(
        name,
        paste0(x_definition$label, " ", x_measure, ": ", format_number(x$latest_estimate), "%"),
        paste0(y_definition$label, " ", y_measure, ": ", format_number(y$latest_estimate), "%"),
        sep = "\n"
      )
    },
    legend = bivariate_legend(x_definition$short_label, y_definition$short_label)
  )
  paste0(
    '<section id="', report$slug, '-bivariate" class="analysis-section bivariate-section bivariate-change-section">',
    section_heading("05", "Bivariate PP Change Maps"),
    '<div class="bivariate-controls"><label><span>Horizontal indicator</span><select data-role="biv-x">',
    options, '</select></label><span class="versus">&times;</span><label><span>Vertical indicator</span>',
    '<select data-role="biv-y">', options, '</select></label><div class="bivariate-result"><strong data-role="biv-both">',
    both, '</strong><span>areas where both worsened</span></div></div>',
    '<div class="section-grid bivariate-grid-layout">', map, "</div></section>"
  )
}

bivariate_prevalence_section_markup <- function(report, features) {
  x_definition <- report$definitions[1, ]
  y_definition <- report$definitions[2, ]
  lookup_key <- paste(report$indicators$admin_name, report$indicators$indicator, sep = "|")
  observation_lookup <- split(report$indicators, lookup_key)
  x_values <- report$indicators$observed_latest_estimate[report$indicators$indicator == x_definition$id]
  y_values <- report$indicators$observed_latest_estimate[report$indicators$indicator == y_definition$id]
  rows <- lapply(report$composite$admin_name, function(admin) {
    list(
      admin_name = admin,
      x = observation_lookup[[paste(admin, x_definition$id, sep = "|")]],
      y = observation_lookup[[paste(admin, y_definition$id, sep = "|")]]
    )
  })
  by_name <- stats::setNames(rows, vapply(rows, `[[`, character(1), "admin_name"))
  high_high <- sum(vapply(rows, function(row) {
    !is.null(row$x) && !is.null(row$y) &&
      prevalence_class(row$x$observed_latest_estimate[1], x_values) == "high" &&
      prevalence_class(row$y$observed_latest_estimate[1], y_values) == "high"
  }, logical(1)))
  options <- paste0(
    '<option value="', html_attr(report$definitions$id), '">', html_escape(report$definitions$label), "</option>",
    collapse = ""
  )
  map <- map_markup(
    id = paste0(report$slug, "-biv-prevalence-map"),
    title = paste(x_definition$short_label, y_definition$short_label, sep = " x "),
    aria_label = paste(report$country_name, "bivariate prevalence map"),
    features = features,
    data_by_name = by_name,
    class_name = "bivariate-map",
    region_class = "biv-prevalence-region",
    fill_function = function(row) {
      if (is.null(row) || is.null(row$x) || is.null(row$y)) return("#E7E2E8")
      x_class <- prevalence_class(row$x$observed_latest_estimate[1], x_values)
      y_class <- prevalence_class(row$y$observed_latest_estimate[1], y_values)
      bivariate_prevalence_colors[[paste(x_class, y_class, sep = ":")]]
    },
    tooltip_function = function(name, row) {
      if (is.null(row) || is.null(row$x) || is.null(row$y)) return(paste(name, "No paired data", sep = "\n"))
      paste(
        name,
        paste0(x_definition$label, ": ", format_number(row$x$observed_latest_estimate[1]), "%"),
        paste0(y_definition$label, ": ", format_number(row$y$observed_latest_estimate[1]), "%"),
        sep = "\n"
      )
    },
    legend = bivariate_prevalence_legend(x_definition$short_label, y_definition$short_label)
  )
  paste0(
    '<section id="', report$slug, '-bivariate-prevalence" class="analysis-section bivariate-section bivariate-prevalence-section">',
    section_heading("06", "Bivariate Prevalence Maps"),
    '<p class="bivariate-method-note">Colors combine country-specific low, middle, and high groups for the two selected observed prevalence values.</p>',
    '<div class="bivariate-controls"><label><span>Horizontal indicator</span><select data-role="biv-x">',
    options, '</select></label><span class="versus">&times;</span><label><span>Vertical indicator</span>',
    '<select data-role="biv-y">', options, '</select></label><div class="bivariate-result"><strong data-role="biv-both">',
    high_high, '</strong><span>areas where both selected values are high</span></div></div>',
    '<div class="section-grid bivariate-grid-layout">', map, "</div></section>"
  )
}

country_dashboard_json <- function(report) {
  profiles <- data.frame(
    admin_name = report$composite$admin_name,
    composite_prevalence_rank = report$composite$composite_prevalence_rank,
    stringsAsFactors = FALSE
  )
  mortality_match <- match(profiles$admin_name, report$mortality$admin_name)
  profiles$u5mr_est_1000 <- report$mortality$u5mr_est_1000[mortality_match]
  list(
    slug = report$slug,
    country = report$country,
    country_name = report$country_name,
    area_plural = report$area_plural,
    rank_max = report$rank_max,
    latest_year = report$latest_year,
    definitions = report$definitions,
    profiles = profiles,
    indicators = report$indicators[c(
      "admin_name", "indicator", "direction", "latest_year", "observed_latest_estimate", "pp_change_10yr_recoded"
    )],
    classifications = report$classifications[c(
      "admin_name", "indicator", "label", "classification", "latest_estimate", "latest_year", "risk_change"
    )]
  )
}

dashboard_json <- function(reports) {
  value <- list(
    countries = unname(lapply(reports, country_dashboard_json)),
    purple_scale = purple_scale,
    bivariate_colors = as.list(bivariate_colors),
    bivariate_prevalence_colors = as.list(bivariate_prevalence_colors),
    status_labels = list(
      improving = "Improving", inside_threshold = "Inside +/-T", worsening = "Worsening", no_data = "No data"
    )
  )
  json <- jsonlite::toJSON(value, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = 15)
  gsub("<", "\\u003c", json, fixed = TRUE)
}

navigation_markup <- function(reports) {
  chapters <- paste(vapply(seq_along(reports), function(index) {
    report <- reports[[index]]
    paste0(
      '<div class="nav-chapter ', if (index == 1L) "active" else "", '">',
      '<a href="#', report$slug, '"><span>', sprintf("%02d", index), '</span><b>', html_escape(report$short_name),
      '</b></a><div class="nav-sections">',
      '<a href="#', report$slug, '-prevalence"><span>01</span>Current Prevalence Rank</a>',
      '<a href="#', report$slug, '-change"><span>02</span>Indicator Change Rank</a>',
      '<a href="#', report$slug, '-indicators"><span>03</span>Indicator Prevalence Maps</a>',
      '<a href="#', report$slug, '-counts"><span>04</span>Worsening Count Map</a>',
      '<a href="#', report$slug, '-bivariate"><span>05</span>Bivariate PP Change Maps</a>',
      '<a href="#', report$slug, '-bivariate-prevalence"><span>06</span>Bivariate Prevalence Maps</a></div></div>'
    )
  }, character(1)), collapse = "")
  paste0(
    '<aside class="sidebar"><a href="#top" class="brand"><span class="brand-mark">3</span>',
    '<span><b>Health Dashboard</b><small>Subnational indicators</small></span></a>',
    '<div class="contents-label"><span>Countries</span><i></i></div><nav aria-label="Dashboard sections">',
    chapters, '</nav><div class="sidebar-note"><span>Scope</span>',
    '<p>DRC &middot; Ethiopia &middot; Nigeria<br>standard composites only</p></div></aside>'
  )
}

country_chapter_markup <- function(report, features, input_file, indicator_file) {
  latest_years <- sort(unique(report$indicators$latest_year))
  paste0(
    '<article id="', report$slug, '" class="country-chapter" data-country="', report$slug, '">',
    '<header class="chapter-header"><div class="chapter-title-row"><div><p class="eyebrow">Country</p><h2>',
    html_escape(report$country_name), '</h2></div><div class="chapter-meta">',
    '<span><b>', report$rank_max, '</b> ', html_escape(report$area_plural), '</span><span><b>',
    report$indicator_count, '</b> indicators</span><span><b>', max(latest_years), '</b> latest survey</span>',
    '</div></div><p class="endpoint-note">Indicator change endpoints span ', report$baseline_year, "&ndash;",
    report$latest_year, '; see the data inventory for indicator-specific years.</p></header>',
    rank_section_markup(report, features, "prevalence", "01"),
    rank_section_markup(report, features, "change", "02"),
    indicator_section_markup(report, features),
    count_section_markup(report, features, input_file, indicator_file),
    bivariate_section_markup(report, features),
    bivariate_prevalence_section_markup(report, features),
    "</article>"
  )
}

build_dashboard_fragment <- function(reports, features_by_country, input_file, indicator_file, interaction_script) {
  total_areas <- sum(vapply(reports, `[[`, numeric(1), "rank_max"))
  geometry_definitions <- paste(vapply(seq_along(reports), function(index) {
    map_definitions_markup(features_by_country[[index]])
  }, character(1)), collapse = "")
  chapters <- paste(vapply(seq_along(reports), function(index) {
    country_chapter_markup(reports[[index]], features_by_country[[index]], input_file, indicator_file)
  }, character(1)), collapse = "")
  paste0(
    '<div id="health-dashboard-root" class="dashboard-frame">', geometry_definitions, navigation_markup(reports),
    '<main class="dashboard-main"><section id="top" class="hero"><div class="hero-topline">',
    '<span>Interactive health dashboard</span><span>DHS subnational estimates</span></div>',
    '<p class="eyebrow">Three-country comparison</p><h1>Subnational Health<br>Across Three Countries</h1>',
    '<div class="hero-metrics"><span><b>3</b> countries</span><span><b>', total_areas,
    '</b> administrative areas</span><span><b>8</b> standard indicator types</span></div>',
    '<a class="primary-action" href="#drc">Explore country sections <span>&darr;</span></a></section>',
    chapters,
    '<footer><div><b>Subnational Health Dashboard</b>',
    '<p>Self-contained interactive file &middot; standard composite sets only</p></div><div class="footer-links">',
    '<a href="https://www.geoboundaries.org/" target="_blank" rel="noreferrer">Boundary attribution: geoBoundaries</a>',
    '<a href="#top">Back to top &uarr;</a></div></footer></main>',
    '<script id="dashboard-data" type="application/json">', dashboard_json(reports), "</script>",
    "<script>", gsub("</script", "<\\/script", interaction_script, fixed = TRUE), "</script></div>"
  )
}
