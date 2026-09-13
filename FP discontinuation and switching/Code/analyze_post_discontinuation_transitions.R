# Post-discontinuation contraceptive transitions
#
# Analytic unit: an eligible discontinued contraceptive episode. One woman may
# contribute multiple episodes. The starting sample and competing-event rules
# are inherited from analyze_reinitiation.R.

required_objects <- c("reinitiation", "reinitiation_method_order", "project_dir")
missing_objects <- required_objects[!vapply(required_objects, exists, logical(1))]
if (length(missing_objects) > 0L) {
  stop(
    "Transition analysis is missing required objects: ",
    paste(missing_objects, collapse = ", "),
    call. = FALSE
  )
}

derived_dir <- file.path(project_dir, "Analyses", "derived")
horizons <- c(1L, 3L, 6L, 9L, 12L)

# Standard DHS contraceptive-calendar codes. Codes 8, 9, and W/10 are
# traditional methods; the remaining recognized contraceptive codes are
# modern methods. The dashboard retains the main method categories separately
# and combines sparse modern methods in "Other modern".
traditional_codes <- c(8L, 9L, 10L)
larc_permanent_codes <- c(2L, 6L, 7L, 11L)
short_acting_modern_codes <- c(
  1L, 3L, 4L, 5L, 12L, 13L, 14L, 15L, 16L, 17L, 18L
)
recognized_codes <- c(traditional_codes, larc_permanent_codes,
                      short_acting_modern_codes)

if (any(reinitiation$status == 1L &
        !reinitiation$next_contra_method %in% recognized_codes)) {
  bad <- sort(unique(reinitiation$next_contra_method[
    reinitiation$status == 1L &
      !reinitiation$next_contra_method %in% recognized_codes
  ]))
  stop(
    "Unrecognized next-method calendar code(s): ",
    paste(bad, collapse = ", "),
    call. = FALSE
  )
}

destination_category <- function(code) {
  out <- rep(NA_character_, length(code))
  out[code == 3L] <- "Injectables"
  out[code == 11L] <- "Implants"
  out[code == 1L] <- "Pill"
  out[code == 16L] <- "Emergency contraception"
  out[code %in% traditional_codes] <- "Traditional method"
  out[code %in% setdiff(recognized_codes, c(1L, 3L, 11L, 16L,
                                             traditional_codes))] <-
    "Other modern"
  out
}

effectiveness_tier <- function(code) {
  out <- rep(NA_integer_, length(code))
  out[code %in% traditional_codes] <- 1L
  out[code %in% short_acting_modern_codes] <- 2L
  out[code %in% larc_permanent_codes] <- 3L
  out
}

reinitiation$next_destination <- destination_category(
  reinitiation$next_contra_method
)
old_tier <- effectiveness_tier(reinitiation$method_code)
new_tier <- effectiveness_tier(reinitiation$next_contra_method)
reinitiation$effectiveness_transition <- NA_character_
is_restart <- reinitiation$status == 1L
reinitiation$effectiveness_transition[
  is_restart & reinitiation$next_contra_method == reinitiation$method_code
] <- "Same method restarted"
reinitiation$effectiveness_transition[
  is_restart & reinitiation$next_contra_method != reinitiation$method_code &
    new_tier > old_tier
] <- "Higher-effectiveness method"
reinitiation$effectiveness_transition[
  is_restart & reinitiation$next_contra_method != reinitiation$method_code &
    new_tier == old_tier
] <- "Different method, same tier"
reinitiation$effectiveness_transition[
  is_restart & new_tier < old_tier
] <- "Lower-effectiveness method"

if (any(is_restart & is.na(reinitiation$next_destination)) ||
    any(is_restart & is.na(reinitiation$effectiveness_transition))) {
  stop("A reinitiation event could not be assigned to a transition category.",
       call. = FALSE)
}

# Weighted Aalen-Johansen estimator with one restart destination per cause and
# pregnancy before restart as an additional competing event.
aj_partition <- function(dat, restart_cause, cause_levels, horizons) {
  survival <- 1
  cif <- setNames(rep(0, length(cause_levels) + 1L),
                  c(cause_levels, "Pregnancy before reinitiation"))
  output <- vector("list", length(horizons))
  for (month in seq_len(max(horizons))) {
    risk_weight <- sum(dat$weight[dat$event_month >= month])
    if (risk_weight > 0) {
      event_now <- dat$event_month == month
      cause_weights <- vapply(cause_levels, function(cause_name) {
        sum(dat$weight[event_now & dat$status == 1L &
                         restart_cause == cause_name])
      }, numeric(1))
      pregnancy_weight <- sum(
        dat$weight[event_now & dat$status == 2L]
      )
      all_weights <- c(cause_weights, pregnancy_weight)
      cif <- cif + survival * all_weights / risk_weight
      survival <- survival * (1 - sum(all_weights) / risk_weight)
    }
    if (month %in% horizons) {
      row <- as.data.frame(as.list(c(cif * 100,
                                     `No observed event` = survival * 100)),
                           check.names = FALSE)
      row$Month <- month
      output[[match(month, horizons)]] <- row
    }
  }
  do.call(rbind, output)
}

destination_levels <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception",
  "Other modern", "Traditional method"
)
effectiveness_levels <- c(
  "Higher-effectiveness method", "Different method, same tier",
  "Same method restarted", "Lower-effectiveness method"
)

build_partition <- function(cause_variable, cause_levels) {
  do.call(rbind, lapply(reinitiation_method_order, function(method_name) {
    dat <- if (method_name == "All methods") reinitiation else
      reinitiation[reinitiation$method_group == method_name,]
    result <- aj_partition(dat, dat[[cause_variable]], cause_levels, horizons)
    data.frame(`Discontinued method` = method_name, result,
               check.names = FALSE)
  }))
}

transition_destination <- build_partition(
  "next_destination", destination_levels
)
transition_effectiveness <- build_partition(
  "effectiveness_transition", effectiveness_levels
)

# Conditional destination distribution among episodes estimated to have
# reinitiated by each horizon. The numerator is a destination-specific CIF and
# the denominator is the sum of all reinitiation-destination CIFs at that same
# horizon. Pregnancy and no-event outcomes are therefore not columns in this
# conditional matrix.
transition_destination_conditional <- transition_destination[
  , c("Discontinued method", "Month", destination_levels)
]
destination_total <- rowSums(
  transition_destination_conditional[, destination_levels]
)
if (any(destination_total <= 0)) {
  stop("A conditional destination row has no estimated reinitiations.",
       call. = FALSE)
}
transition_destination_conditional[, destination_levels] <-
  transition_destination_conditional[, destination_levels] /
  destination_total * 100

# Gap-duration categories are differences between cumulative incidence values.
monthly_cif <- do.call(rbind, lapply(reinitiation_method_order, function(method_name) {
  dat <- if (method_name == "All methods") reinitiation else
    reinitiation[reinitiation$method_group == method_name,]
  result <- reinitiation_cif(dat, horizons = 1L:12L)
  data.frame(`Discontinued method` = method_name, Month = 1L:12L,
             result[, setdiff(names(result), "Horizon")],
             check.names = FALSE)
}))

gap_distribution <- do.call(rbind, lapply(reinitiation_method_order,
  function(method_name) {
    dat <- monthly_cif[monthly_cif$`Discontinued method` == method_name,]
    r <- dat$`Reinitiated (%)`
    p12 <- dat$`Pregnancy competing event (%)`[12]
    s12 <- dat$`No observed event (%)`[12]
    data.frame(
      `Discontinued method` = method_name,
      `Next month` = r[1],
      `Months 2-3` = r[3] - r[1],
      `Months 4-6` = r[6] - r[3],
      `Months 7-9` = r[9] - r[6],
      `Months 10-12` = r[12] - r[9],
      `Pregnancy before reinitiation` = p12,
      `No observed event by 12 months` = s12,
      check.names = FALSE
    )
  }
))

# Integrated modern-protection pathways
# -------------------------------------
# This 12-month program view begins with an eligible discontinued modern-method
# episode and assigns its first observed post-discontinuation outcome to one
# mutually exclusive category. Month 1 is the immediately following calendar
# month. Months 2-3 are the remaining prompt-switching window, while months
# 4-12 are an operational prolonged-gap band. A first traditional-method start
# remains separate even if a modern method is observed later.
modern_codes <- setdiff(recognized_codes, traditional_codes)
reinitiation$origin_destination <- destination_category(reinitiation$method_code)
modern_origin_reinitiation <- reinitiation[
  !is.na(reinitiation$origin_destination) &
    reinitiation$origin_destination != "Traditional method",
]

protection_pathway_levels <- c(
  "Continued modern protection",
  "Temporary non-use then modern reinitiation",
  "Prolonged gap then modern reinitiation",
  "Traditional-method use"
)
modern_origin_reinitiation$protection_pathway <- NA_character_
modern_restart <- modern_origin_reinitiation$status == 1L &
  modern_origin_reinitiation$next_contra_method %in% modern_codes
traditional_restart <- modern_origin_reinitiation$status == 1L &
  modern_origin_reinitiation$next_contra_method %in% traditional_codes
modern_origin_reinitiation$protection_pathway[
  modern_restart & modern_origin_reinitiation$restart_month == 1L
] <- "Continued modern protection"
modern_origin_reinitiation$protection_pathway[
  modern_restart & modern_origin_reinitiation$restart_month %in% 2L:3L
] <- "Temporary non-use then modern reinitiation"
modern_origin_reinitiation$protection_pathway[
  modern_restart & modern_origin_reinitiation$restart_month %in% 4L:12L
] <- "Prolonged gap then modern reinitiation"
modern_origin_reinitiation$protection_pathway[traditional_restart] <-
  "Traditional-method use"

unclassified_12_month_restart <-
  modern_origin_reinitiation$status == 1L &
  modern_origin_reinitiation$restart_month <= 12L &
  is.na(modern_origin_reinitiation$protection_pathway)
if (any(unclassified_12_month_restart)) {
  stop("A 12-month modern-origin reinitiation pathway was not classified.",
       call. = FALSE)
}

modern_origin_order <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception",
  "Other modern", "All modern methods"
)
modern_protection_pathways <- do.call(rbind, lapply(
  modern_origin_order,
  function(method_name) {
    dat <- if (method_name == "All modern methods") {
      modern_origin_reinitiation
    } else {
      modern_origin_reinitiation[
        modern_origin_reinitiation$origin_destination == method_name,
      ]
    }
    estimate <- aj_partition(
      dat,
      dat$protection_pathway,
      protection_pathway_levels,
      horizons = 12L
    )
    data.frame(
      `Discontinued modern method` = method_name,
      estimate,
      `Weighted eligible episodes` = sum(dat$weight),
      `Unweighted eligible episodes` = nrow(dat),
      check.names = FALSE
    )
  }
))
names(modern_protection_pathways)[
  names(modern_protection_pathways) == "Pregnancy before reinitiation"
] <- "Pregnancy first"
names(modern_protection_pathways)[
  names(modern_protection_pathways) == "No observed event"
] <- "No reinitiation or pregnancy observed by 12 months"

modern_pathway_value_columns <- c(
  protection_pathway_levels,
  "Pregnancy first",
  "No reinitiation or pregnancy observed by 12 months"
)
modern_pathway_identity_error <- max(abs(
  rowSums(modern_protection_pathways[, modern_pathway_value_columns]) - 100
))
if (modern_pathway_identity_error > 1e-8) {
  stop("Modern-protection pathway rows do not sum to 100%.", call. = FALSE)
}

# Every horizon-specific partition and every 12-month gap distribution must
# total 100% before rounding.
destination_value_cols <- c(destination_levels,
                            "Pregnancy before reinitiation", "No observed event")
effectiveness_value_cols <- c(effectiveness_levels,
                              "Pregnancy before reinitiation", "No observed event")
if (max(abs(rowSums(transition_destination[, destination_value_cols]) - 100)) > 1e-8 ||
    max(abs(rowSums(transition_effectiveness[, effectiveness_value_cols]) - 100)) > 1e-8 ||
    max(abs(rowSums(gap_distribution[, -1]) - 100)) > 1e-8) {
  stop("Post-discontinuation outcome partition does not sum to 100%.",
       call. = FALSE)
}

write.csv(transition_destination,
          file.path(derived_dir, "post_discontinuation_transition_matrix.csv"),
          row.names = FALSE)
write.csv(
  transition_destination_conditional,
  file.path(
    derived_dir,
    "post_discontinuation_destination_among_reinitiators.csv"
  ),
  row.names = FALSE
)
write.csv(transition_effectiveness,
          file.path(derived_dir, "post_discontinuation_effectiveness_transition.csv"),
          row.names = FALSE)
write.csv(gap_distribution,
          file.path(derived_dir, "post_discontinuation_gap_distribution.csv"),
          row.names = FALSE)
write.csv(
  modern_protection_pathways,
  file.path(derived_dir, "post_discontinuation_modern_protection_pathways.csv"),
  row.names = FALSE
)

message("Created post-discontinuation transition, gap, and effectiveness outputs.")
