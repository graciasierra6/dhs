# Monthly discontinuation hazards and timing concentration
#
# The monthly hazard is a nonparametric, weighted life-table estimate:
#
#   weighted discontinuations during month t
#   -----------------------------------------
#   weighted episodes at risk at month t
#
# This is not a regression hazard model. Cause-specific hazards use the same
# risk set but count only discontinuations attributed to the selected competing
# cause in the numerator.

required_objects <- c(
  "episodes", "method_order", "reason_names", "aj_cif", "derived_dir"
)
missing_objects <- required_objects[!vapply(required_objects, exists, logical(1))]
if (length(missing_objects) > 0L) {
  stop(
    "Monthly hazard analysis is missing required objects: ",
    paste(missing_objects, collapse = ", "),
    call. = FALSE
  )
}

cause_names <- reason_names[1:9]

monthly_hazards_for_group <- function(dat, method_name, months = 1L:12L) {
  all_rows <- vector("list", length(months))
  cause_rows <- vector("list", length(months))

  for (i in seq_along(months)) {
    month <- months[i]
    at_risk <- dat$entry < month & dat$exposure >= month
    risk_weight <- sum(dat$weight[at_risk])
    risk_n <- sum(at_risk)
    event_at_month <- dat$exposure == month & dat$discontinued == 1L
    all_event_weight <- sum(dat$weight[event_at_month])

    all_rows[[i]] <- data.frame(
      Method = method_name,
      Month = month,
      `All-cause monthly hazard (%)` =
        if (risk_weight > 0) all_event_weight / risk_weight * 100 else NA_real_,
      `Weighted risk set` = risk_weight,
      `Unweighted risk set` = risk_n,
      `Weighted discontinuations` = all_event_weight,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )

    cause_rows[[i]] <- do.call(
      rbind,
      lapply(seq_along(cause_names), function(cause_code) {
        cause_weight <- sum(
          dat$weight[event_at_month & dat$reason_group == cause_code]
        )
        data.frame(
          Method = method_name,
          Month = month,
          Reason = cause_names[cause_code],
          `Cause-specific monthly hazard (%)` =
            if (risk_weight > 0) cause_weight / risk_weight * 100 else NA_real_,
          `Weighted risk set` = risk_weight,
          `Weighted cause-specific discontinuations` = cause_weight,
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
      })
    )
  }

  list(
    all_cause = do.call(rbind, all_rows),
    cause_specific = do.call(rbind, cause_rows)
  )
}

monthly_results <- lapply(method_order, function(method_name) {
  dat <- if (method_name == "All methods") {
    episodes
  } else {
    episodes[episodes$method_group == method_name,]
  }
  monthly_hazards_for_group(dat, method_name)
})

monthly_all_cause <- do.call(
  rbind, lapply(monthly_results, function(x) x$all_cause)
)
monthly_cause_specific <- do.call(
  rbind, lapply(monthly_results, function(x) x$cause_specific)
)

# For each method and reason, calculate how much of the estimated 12-month
# cause-specific cumulative incidence had accumulated by months 3, 6, and 9.
timing_rows <- lapply(method_order, function(method_name) {
  dat <- if (method_name == "All methods") {
    episodes
  } else {
    episodes[episodes$method_group == method_name,]
  }
  cif_3 <- aj_cif(dat, dat$reason_group, 3L)[1:9]
  cif_6 <- aj_cif(dat, dat$reason_group, 6L)[1:9]
  cif_9 <- aj_cif(dat, dat$reason_group, 9L)[1:9]
  cif_12 <- aj_cif(dat, dat$reason_group, 12L)[1:9]
  safe_share <- function(numerator, denominator) {
    ifelse(denominator > 0, numerator / denominator * 100, NA_real_)
  }
  data.frame(
    Method = method_name,
    Reason = cause_names,
    `12-month cause-specific cumulative incidence (%)` = as.numeric(cif_12),
    `Accumulated by month 3 (%)` = safe_share(cif_3, cif_12),
    `Accumulated by month 6 (%)` = safe_share(cif_6, cif_12),
    `Accumulated by month 9 (%)` = safe_share(cif_9, cif_12),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
})
reason_timing <- do.call(rbind, timing_rows)

# Validation: cause-specific monthly hazards must sum to the all-cause monthly
# hazard for the same method and month.
cause_sum <- aggregate(
  monthly_cause_specific$`Cause-specific monthly hazard (%)`,
  by = list(
    Method = monthly_cause_specific$Method,
    Month = monthly_cause_specific$Month
  ),
  FUN = sum
)
names(cause_sum)[3] <- "Cause sum"
hazard_check <- merge(
  monthly_all_cause[, c("Method", "Month", "All-cause monthly hazard (%)")],
  cause_sum,
  by = c("Method", "Month")
)
hazard_check$`Absolute difference` <- abs(
  hazard_check$`All-cause monthly hazard (%)` - hazard_check$`Cause sum`
)
if (max(hazard_check$`Absolute difference`, na.rm = TRUE) > 1e-8) {
  stop("Cause-specific hazards do not sum to the all-cause monthly hazard.")
}
if (any(reason_timing[, grep("Accumulated", names(reason_timing))] < -1e-8,
        na.rm = TRUE) ||
    any(reason_timing[, grep("Accumulated", names(reason_timing))] > 100 + 1e-8,
        na.rm = TRUE)) {
  stop("Reason timing shares fall outside 0-100%.")
}

write.csv(
  monthly_all_cause,
  file.path(derived_dir, "monthly_all_cause_discontinuation_hazards.csv"),
  row.names = FALSE
)
write.csv(
  monthly_cause_specific,
  file.path(derived_dir, "monthly_cause_specific_discontinuation_hazards.csv"),
  row.names = FALSE
)
write.csv(
  reason_timing,
  file.path(derived_dir, "reason_timing_share_of_12_month_cif.csv"),
  row.names = FALSE
)
write.csv(
  hazard_check,
  file.path(derived_dir, "monthly_hazard_identity_validation.csv"),
  row.names = FALSE
)

message("Created monthly all-cause and cause-specific hazard estimates.")
