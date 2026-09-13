# Outcomes after discontinuation, stratified by reason and previous method
#
# Analytic unit
# -------------
# One observed discontinued contraceptive episode. Unlike the primary
# reinitiation analysis, this analysis retains every DHS reason group,
# including method failure and desire for pregnancy, so their subsequent
# pathways remain visible and can be interpreted separately.
#
# Outcomes
# --------
# The first subsequent contraceptive start is the event of interest. A first
# subsequent pregnancy, birth, or termination is a competing event. Interview
# is right censoring. Survey-weighted Aalen-Johansen cumulative incidence is
# estimated at 1, 3, 6, and 12 months.

required_objects <- c(
  "episodes", "events_all", "reinitiation_cif",
  "reinitiation_method_order", "project_dir"
)
missing_objects <- required_objects[
  !vapply(required_objects, exists, logical(1))
]
if (length(missing_objects) > 0L) {
  stop(
    "Reason-to-outcome analysis is missing required objects: ",
    paste(missing_objects, collapse = ", "),
    call. = FALSE
  )
}

reason_level_names <- c(
  `1` = "Method failure",
  `2` = "Desire to become pregnant",
  `3` = "Other fertility-related reasons",
  `4` = "Changes in menstrual bleeding",
  `5` = "Other side effects/health concerns",
  `6` = "Wanted more effective method",
  `7` = "Other method-related reasons",
  `8` = "Husband/partner disapproved",
  `9` = "Other reasons"
)
reason_horizons <- c(1L, 3L, 6L, 12L)

reason_followup <- episodes[episodes$discontinued == 1L, ]

pregnancy_events_reason <- events_all[
  events_all$method_code %in% c(81L, 82L, 83L),
  c("caseid", "event_start")
]
pregnancy_by_case_reason <- split(
  pregnancy_events_reason$event_start,
  pregnancy_events_reason$caseid
)

reason_followup$next_pregnancy_start <- vapply(
  seq_len(nrow(reason_followup)),
  function(i) {
    candidate <- pregnancy_by_case_reason[[
      as.character(reason_followup$caseid[i])
    ]]
    candidate <- candidate[candidate > reason_followup$event_end[i]]
    if (length(candidate) == 0L) NA_integer_ else min(candidate)
  },
  integer(1)
)

reason_followup$followup_months <-
  reason_followup$interview_cmc - reason_followup$event_end
reason_followup$restart_month <-
  reason_followup$next_contra_start - reason_followup$event_end
reason_followup$pregnancy_month <-
  reason_followup$next_pregnancy_start - reason_followup$event_end

invalid_restart <- is.na(reason_followup$restart_month) |
  reason_followup$restart_month < 1L |
  reason_followup$restart_month > reason_followup$followup_months
invalid_pregnancy <- is.na(reason_followup$pregnancy_month) |
  reason_followup$pregnancy_month < 1L |
  reason_followup$pregnancy_month > reason_followup$followup_months
reason_followup$restart_month[invalid_restart] <- NA_integer_
reason_followup$pregnancy_month[invalid_pregnancy] <- NA_integer_

same_month_tie <- !is.na(reason_followup$restart_month) &
  !is.na(reason_followup$pregnancy_month) &
  reason_followup$restart_month == reason_followup$pregnancy_month
if (any(same_month_tie)) {
  stop(
    "A restart and pregnancy begin in the same calendar month for ",
    sum(same_month_tie),
    " discontinued episode(s); the monthly calendar cannot order them.",
    call. = FALSE
  )
}

reason_followup$status <- 0L
restart_first <- !is.na(reason_followup$restart_month) &
  (is.na(reason_followup$pregnancy_month) |
     reason_followup$restart_month < reason_followup$pregnancy_month)
pregnancy_first <- !is.na(reason_followup$pregnancy_month) &
  (is.na(reason_followup$restart_month) |
     reason_followup$pregnancy_month < reason_followup$restart_month)
reason_followup$status[restart_first] <- 1L
reason_followup$status[pregnancy_first] <- 2L

reason_followup$event_month <- reason_followup$followup_months
reason_followup$event_month[restart_first] <-
  reason_followup$restart_month[restart_first]
reason_followup$event_month[pregnancy_first] <-
  reason_followup$pregnancy_month[pregnancy_first]
reason_followup <- reason_followup[
  is.finite(reason_followup$event_month) &
    reason_followup$event_month >= 1L &
    is.finite(reason_followup$weight) & reason_followup$weight > 0,
]
reason_followup$Reason <- unname(
  reason_level_names[as.character(reason_followup$reason_group)]
)
if (any(is.na(reason_followup$Reason))) {
  stop("A discontinued episode has an unmapped reason group.", call. = FALSE)
}

estimate_reason_group <- function(dat, reason_name, method_name = NULL) {
  result <- reinitiation_cif(dat, horizons = reason_horizons)
  data.frame(
    Reason = reason_name,
    `Discontinued method` = if (is.null(method_name)) {
      "All methods"
    } else {
      method_name
    },
    Month = reason_horizons,
    `Reinitiated (%)` = result$`Reinitiated (%)`,
    `Pregnancy before reinitiation (%)` =
      result$`Pregnancy competing event (%)`,
    `No observed event (%)` = result$`No observed event (%)`,
    `Eligible episodes (unweighted)` = nrow(dat),
    `Eligible episodes (weighted)` = sum(dat$weight),
    check.names = FALSE
  )
}

reason_outcomes <- do.call(
  rbind,
  lapply(unname(reason_level_names), function(reason_name) {
    dat <- reason_followup[reason_followup$Reason == reason_name, ]
    estimate_reason_group(dat, reason_name)
  })
)

method_reason_outcomes <- do.call(
  rbind,
  lapply(reinitiation_method_order[reinitiation_method_order != "All methods"],
         function(method_name) {
    do.call(rbind, lapply(unname(reason_level_names), function(reason_name) {
      dat <- reason_followup[
        reason_followup$method_group == method_name &
          reason_followup$Reason == reason_name,
      ]
      if (nrow(dat) == 0L) return(NULL)
      estimate_reason_group(dat, reason_name, method_name)
    }))
  })
)

outcome_columns <- c(
  "Reinitiated (%)", "Pregnancy before reinitiation (%)",
  "No observed event (%)"
)
if (max(abs(rowSums(reason_outcomes[, outcome_columns]) - 100)) > 1e-8 ||
    max(abs(rowSums(method_reason_outcomes[, outcome_columns]) - 100)) > 1e-8) {
  stop("A reason-to-outcome partition does not sum to 100%.", call. = FALSE)
}

write.csv(
  reason_outcomes,
  file.path(
    project_dir, "Analyses", "derived",
    "reason_post_discontinuation_outcomes.csv"
  ),
  row.names = FALSE
)
write.csv(
  method_reason_outcomes,
  file.path(
    project_dir,
    "Analyses",
    "derived",
    "reason_previous_method_post_discontinuation_outcomes.csv"
  ),
  row.names = FALSE
)

message(
  "Created reason-linked post-discontinuation outcomes for ",
  nrow(reason_followup), " discontinued episodes."
)
