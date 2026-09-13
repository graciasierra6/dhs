# Time to contraceptive reinitiation after discontinuation
#
# Starting population
# -------------------
# Contraceptive episodes with an observed discontinuation that was not caused
# by method failure (pregnancy while using) or a desire to become pregnant.
# Other fertility-related reasons remain eligible because that DHS aggregate
# category includes circumstances such as infrequent sex/partner absence,
# subfecundity/menopause, and marital dissolution rather than an observed or
# intended pregnancy.
#
# Outcome framework
# -----------------
# Time zero is the end month of the discontinued episode. A contraceptive
# episode beginning in the immediately following calendar month is recorded as
# reinitiation at month 1. The first subsequent pregnancy, birth, or termination
# is a competing event. If neither occurs before interview, follow-up is right
# censored. Weighted Aalen-Johansen cumulative incidence is calculated for
# every month from 1 through 12; the milestone output retains months 1, 3, 6,
# 9, and 12 for the compact summary table.
#
# This script is sourced by run_discontinuation_analysis.R after the episode
# objects have been constructed by replicate_table_7_11.R.

required_objects <- c("episodes", "events_all", "project_dir")
missing_objects <- required_objects[!vapply(required_objects, exists, logical(1))]
if (length(missing_objects) > 0L) {
  stop(
    "Reinitiation analysis is missing required objects: ",
    paste(missing_objects, collapse = ", "),
    call. = FALSE
  )
}

reinitiation <- episodes[
  episodes$discontinued == 1L &
    !episodes$reason_group %in% c(1L, 2L),
]

# Locate the first subsequent pregnancy-related calendar event for each
# discontinued episode. P, B, and T runs are retained to handle calendars in
# which a pregnancy run or its endpoint is the first observable marker.
pregnancy_events <- events_all[
  events_all$method_code %in% c(81L, 82L, 83L),
  c("caseid", "event_start")
]
pregnancy_by_case <- split(pregnancy_events$event_start, pregnancy_events$caseid)

reinitiation$next_pregnancy_start <- vapply(
  seq_len(nrow(reinitiation)),
  function(i) {
    candidate <- pregnancy_by_case[[as.character(reinitiation$caseid[i])]]
    candidate <- candidate[candidate > reinitiation$event_end[i]]
    if (length(candidate) == 0L) NA_integer_ else min(candidate)
  },
  integer(1)
)

reinitiation$followup_months <-
  reinitiation$interview_cmc - reinitiation$event_end
reinitiation$restart_month <-
  reinitiation$next_contra_start - reinitiation$event_end
reinitiation$pregnancy_month <-
  reinitiation$next_pregnancy_start - reinitiation$event_end

# Remove event dates that occur outside observable follow-up or do not occur
# strictly after discontinuation.
invalid_restart <- is.na(reinitiation$restart_month) |
  reinitiation$restart_month < 1L |
  reinitiation$restart_month > reinitiation$followup_months
invalid_pregnancy <- is.na(reinitiation$pregnancy_month) |
  reinitiation$pregnancy_month < 1L |
  reinitiation$pregnancy_month > reinitiation$followup_months
reinitiation$restart_month[invalid_restart] <- NA_integer_
reinitiation$pregnancy_month[invalid_pregnancy] <- NA_integer_

# Status: 0=censored, 1=reinitiated, 2=pregnancy-related competing event.
reinitiation$status <- 0L
restart_first <- !is.na(reinitiation$restart_month) &
  (is.na(reinitiation$pregnancy_month) |
     reinitiation$restart_month < reinitiation$pregnancy_month)
pregnancy_first <- !is.na(reinitiation$pregnancy_month) &
  (is.na(reinitiation$restart_month) |
     reinitiation$pregnancy_month < reinitiation$restart_month)

# The monthly calendar does not order two events within the same month. Stop
# rather than silently classifying a same-month restart/pregnancy tie.
same_month_tie <- !is.na(reinitiation$restart_month) &
  !is.na(reinitiation$pregnancy_month) &
  reinitiation$restart_month == reinitiation$pregnancy_month
if (any(same_month_tie)) {
  stop(
    "Reinitiation and pregnancy begin in the same calendar month for ",
    sum(same_month_tie), " eligible episode(s); event ordering is ambiguous.",
    call. = FALSE
  )
}
reinitiation$status[restart_first] <- 1L
reinitiation$status[pregnancy_first] <- 2L

reinitiation$event_month <- reinitiation$followup_months
reinitiation$event_month[restart_first] <- reinitiation$restart_month[restart_first]
reinitiation$event_month[pregnancy_first] <-
  reinitiation$pregnancy_month[pregnancy_first]

reinitiation <- reinitiation[
  is.finite(reinitiation$event_month) &
    reinitiation$event_month >= 1L &
    is.finite(reinitiation$weight) & reinitiation$weight > 0,
]

reinitiation_cif <- function(dat, horizons = c(1L, 3L, 6L, 9L, 12L)) {
  survival <- 1
  cif_restart <- 0
  cif_pregnancy <- 0
  output <- vector("list", length(horizons))
  max_horizon <- max(horizons)

  for (month in seq_len(max_horizon)) {
    at_risk <- dat$event_month >= month
    risk_weight <- sum(dat$weight[at_risk])
    if (risk_weight > 0) {
      restart_weight <- sum(
        dat$weight[dat$event_month == month & dat$status == 1L]
      )
      pregnancy_weight <- sum(
        dat$weight[dat$event_month == month & dat$status == 2L]
      )
      cif_restart <- cif_restart + survival * restart_weight / risk_weight
      cif_pregnancy <-
        cif_pregnancy + survival * pregnancy_weight / risk_weight
      survival <- survival *
        (1 - (restart_weight + pregnancy_weight) / risk_weight)
    }

    if (month %in% horizons) {
      output[[match(month, horizons)]] <- data.frame(
        Horizon = paste0(month, if (month == 1L) " month" else " months"),
        `Reinitiated (%)` = cif_restart * 100,
        `Pregnancy competing event (%)` = cif_pregnancy * 100,
        `No observed event (%)` = survival * 100,
        `Unweighted at risk` = sum(dat$event_month >= month),
        `Weighted at risk` = sum(dat$weight[dat$event_month >= month]),
        check.names = FALSE
      )
    }
  }
  do.call(rbind, output)
}

reinitiation_method_order <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception",
  "Other", "All methods"
)
reinitiation_monthly <- do.call(
  rbind,
  lapply(reinitiation_method_order, function(method_name) {
    dat <- if (method_name == "All methods") {
      reinitiation
    } else {
      reinitiation[reinitiation$method_group == method_name,]
    }
    data.frame(
      Method = method_name,
      reinitiation_cif(dat, horizons = 1L:12L),
      check.names = FALSE
    )
  })
)

milestone_horizons <- c(
  "1 month", "3 months", "6 months", "9 months", "12 months"
)
reinitiation_results <- reinitiation_monthly[
  reinitiation_monthly$Horizon %in% milestone_horizons,
]

reinitiation_summary <- do.call(
  rbind,
  lapply(reinitiation_method_order, function(method_name) {
    dat <- if (method_name == "All methods") {
      reinitiation
    } else {
      reinitiation[reinitiation$method_group == method_name,]
    }
    data.frame(
      Method = method_name,
      `Eligible discontinued episodes (unweighted)` = nrow(dat),
      `Eligible discontinued episodes (weighted)` = sum(dat$weight),
      `Observed reinitiations (unweighted)` = sum(dat$status == 1L),
      `Observed pregnancy competing events (unweighted)` =
        sum(dat$status == 2L),
      `Right censored (unweighted)` = sum(dat$status == 0L),
      check.names = FALSE
    )
  })
)

# Validation: cumulative incidence components must remain bounded and sum to no
# more than 100%, apart from floating-point tolerance.
component_sum <-
  reinitiation_results$`Reinitiated (%)` +
  reinitiation_results$`Pregnancy competing event (%)` +
  reinitiation_results$`No observed event (%)`
if (any(abs(component_sum - 100) > 1e-8)) {
  stop("Reinitiation cumulative-incidence components do not sum to 100%.")
}
if (any(reinitiation_results$`Reinitiated (%)` < -1e-8) ||
    any(reinitiation_results$`Reinitiated (%)` > 100 + 1e-8)) {
  stop("Reinitiation cumulative incidence is outside the valid range.")
}

write.csv(
  reinitiation_results,
  file.path(derived_dir, "reinitiation_competing_risk_1_3_6_9_12.csv"),
  row.names = FALSE
)
write.csv(
  reinitiation_monthly,
  file.path(derived_dir, "reinitiation_monthly_competing_risk_1_12.csv"),
  row.names = FALSE
)
write.csv(
  reinitiation_summary,
  file.path(derived_dir, "reinitiation_sample_summary.csv"),
  row.names = FALSE
)

message(
  "Created reinitiation analysis for ", nrow(reinitiation),
  " eligible discontinued episodes."
)
