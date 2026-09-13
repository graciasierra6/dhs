options(stringsAsFactors = FALSE)

project_dir <- getOption(
  "ethiopia_discontinuation_project_dir",
  normalizePath(".", mustWork = TRUE)
)
project_library <- file.path(project_dir, "r_libs")
if (dir.exists(project_library)) {
  .libPaths(c(project_library, .libPaths()))
}
suppressPackageStartupMessages(library(haven))

input_file <- file.path(project_dir, "Data", "Ethiopia", "ETIR8AFL.dta")
derived_dir <- file.path(project_dir, "Analyses", "derived")
dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)

stopifnot(file.exists(input_file))

calendar <- read_dta(
  input_file,
  col_select = c(
    caseid, v005, v008, v017, v018, v019, vcal_1, vcal_2, v312, v313
  )
)

pad_calendar <- function(x, width = 80L) {
  x[is.na(x)] <- ""
  n <- nchar(x, type = "chars")
  paste0(substr(x, 1L, width), strrep(" ", pmax(0L, width - n)))
}

calendar$vcal_1 <- pad_calendar(calendar$vcal_1)
calendar$vcal_2 <- pad_calendar(calendar$vcal_2)

method_key <- strsplit("123456789WNALCFEMS", "", fixed = TRUE)[[1]]
method_numeric <- setNames(seq_along(method_key), method_key)
reason_numeric <- c(
  "1" = 1, "2" = 2, "3" = 3, "4" = 4, "5" = 5,
  "6" = 6, "7" = 7, "8" = 8, "9" = 9,
  "C" = 10, "F" = 11, "A" = 12, "D" = 13,
  "M" = 14, "W" = 96, "K" = 98, "?" = 99
)

event_rows <- vector("list", nrow(calendar))

for (i in seq_len(nrow(calendar))) {
  start_pos <- as.integer(calendar$v018[i])
  end_pos <- min(80L, start_pos + as.integer(calendar$v019[i]) - 1L)
  if (is.na(start_pos) || is.na(end_pos) || start_pos > end_pos) next

  pos <- seq.int(end_pos, start_pos, by = -1L)
  m <- substring(calendar$vcal_1[i], pos, pos)
  r <- substring(calendar$vcal_2[i], pos, pos)
  cmc <- as.integer(calendar$v008[i]) - (pos - start_pos)

  run <- rle(m)
  run_end <- cumsum(run$lengths)
  run_start <- c(1L, head(run_end, -1L) + 1L)

  rows <- vector("list", length(run$values))
  for (j in seq_along(run$values)) {
    idx <- run_start[j]:run_end[j]
    code <- run$values[j]
    code_num <- if (code == "0") {
      0
    } else if (code == "B") {
      81
    } else if (code == "P") {
      82
    } else if (code == "T") {
      83
    } else if (code == "?") {
      99
    } else if (code %in% names(method_numeric)) {
      unname(method_numeric[code])
    } else {
      -1
    }

    # The reason is recorded in the final (most recent) month of the episode.
    reason_alpha <- r[max(idx)]
    reason_num <- if (reason_alpha == " ") 0 else unname(reason_numeric[reason_alpha])
    if (is.na(reason_num)) reason_num <- -1

    rows[[j]] <- data.frame(
      caseid = calendar$caseid[i],
      event_index = j,
      event_start = min(cmc[idx]),
      event_end = max(cmc[idx]),
      duration = length(idx),
      method_alpha = code,
      method_code = code_num,
      reason_alpha = reason_alpha,
      reason_code = reason_num,
      weight = as.numeric(calendar$v005[i]) / 1e6,
      interview_cmc = as.integer(calendar$v008[i]),
      calendar_start_cmc = as.integer(calendar$v017[i]),
      stringsAsFactors = FALSE
    )
  }

  person_events <- do.call(rbind, rows)
  person_events$next_full_code <- c(person_events$method_code[-1], NA_integer_)
  event_rows[[i]] <- person_events
}

events_all <- do.call(rbind, event_rows)
rownames(events_all) <- NULL

# Keep contraceptive episodes, including missing methods, as in the DHS standard.
episodes <- events_all[
  !((events_all$method_code > 80 & events_all$method_code < 99) |
      events_all$method_code == 0),
]
episodes <- episodes[episodes$calendar_start_cmc != episodes$event_start,]
episodes <- episodes[order(episodes$caseid, episodes$event_start),]

# The next row after filtering is the next contraceptive episode for that woman.
episodes$next_contra_start <- NA_integer_
episodes$next_contra_method <- NA_integer_
split_idx <- split(seq_len(nrow(episodes)), episodes$caseid)
for (idx in split_idx) {
  if (length(idx) > 1L) {
    episodes$next_contra_start[idx[-length(idx)]] <- episodes$event_start[idx[-1L]]
    episodes$next_contra_method[idx[-length(idx)]] <- episodes$method_code[idx[-1L]]
  }
}

episodes$months_start_to_interview <- episodes$interview_cmc - episodes$event_start
episodes$months_end_to_interview <- episodes$interview_cmc - episodes$event_end
episodes$discontinued <- as.integer(episodes$reason_code != 0)
episodes$discontinued[episodes$months_end_to_interview < 3] <- 0L
episodes$entry <- ifelse(
  episodes$months_start_to_interview >= 63,
  episodes$months_start_to_interview - 62,
  0
)
episodes$exposure <- episodes$duration
recent_end <- episodes$months_end_to_interview < 3
episodes$exposure[recent_end] <- episodes$duration[recent_end] -
  (3 - episodes$months_end_to_interview[recent_end])
episodes$exposure <- pmax(0, episodes$exposure)

episodes <- episodes[episodes$months_start_to_interview >= 3,]
episodes <- episodes[!(episodes$months_start_to_interview > 62 &
                         episodes$months_end_to_interview > 62),]

episodes$reason_group <- 0L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code == 1] <- 1L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code == 2] <- 2L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code %in% c(9, 12, 13)] <- 3L
# Ethiopia's distributed calendar uses the legacy standard-recode scheme.
# Survey-specific code M carries the DHS-8 "changes in menstrual bleeding"
# response, while legacy codes 4 and 5 carry other side effects/health concerns.
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code == 14] <- 4L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code %in% c(4, 5)] <- 5L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code == 7] <- 6L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code %in% c(6, 8, 10)] <- 7L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_code == 3] <- 8L
episodes$reason_group[episodes$discontinued == 1 & episodes$reason_group == 0] <- 9L

episodes$switch <- 0L
direct_switch <- !is.na(episodes$next_contra_start) &
  episodes$next_contra_start == episodes$event_end + 1L
effective_switch <- episodes$reason_code == 7 &
  !is.na(episodes$next_contra_start) &
  episodes$next_contra_start <= episodes$event_end + 2L &
  episodes$next_full_code == 0
episodes$switch[episodes$discontinued == 1 & (direct_switch | effective_switch)] <- 1L
same_method_restart <- direct_switch &
  !is.na(episodes$next_contra_method) &
  episodes$method_code == episodes$next_contra_method
episodes$switch[same_method_restart] <- 0L

episodes$method_group <- "Other"
episodes$method_group[episodes$method_code == 1] <- "Pill"
episodes$method_group[episodes$method_code == 3] <- "Injectables"
episodes$method_group[episodes$method_code == 11] <- "Implants"
episodes$method_group[episodes$method_code == 16] <- "Emergency contraception"

aj_cif <- function(dat, status, horizon = 12L) {
  dat <- dat[is.finite(dat$entry) & is.finite(dat$exposure) &
               dat$exposure > dat$entry & dat$weight > 0,]
  cif <- numeric(9)
  surv <- 1
  for (t in seq_len(horizon)) {
    at_risk <- dat$entry < t & dat$exposure >= t
    risk_weight <- sum(dat$weight[at_risk])
    if (risk_weight <= 0) next
    event_at_t <- dat$exposure == t & status > 0
    cause_events <- vapply(
      1:9,
      function(k) sum(dat$weight[event_at_t & status == k]),
      numeric(1)
    )
    cif <- cif + surv * (cause_events / risk_weight)
    surv <- surv * (1 - sum(cause_events) / risk_weight)
  }
  c(cif, any_reason = sum(cif)) * 100
}

switch_cif <- function(dat, horizon = 12L) {
  dat <- dat[is.finite(dat$entry) & is.finite(dat$exposure) &
               dat$exposure > dat$entry & dat$weight > 0,]
  cif <- 0
  surv <- 1
  switch_status <- ifelse(dat$discontinued == 1 & dat$switch == 1, 1L,
                          ifelse(dat$discontinued == 1, 2L, 0L))
  for (t in seq_len(horizon)) {
    at_risk <- dat$entry < t & dat$exposure >= t
    risk_weight <- sum(dat$weight[at_risk])
    if (risk_weight <= 0) next
    event_at_t <- dat$exposure == t & switch_status > 0
    d_switch <- sum(dat$weight[event_at_t & switch_status == 1])
    d_all <- sum(dat$weight[event_at_t])
    cif <- cif + surv * d_switch / risk_weight
    surv <- surv * (1 - d_all / risk_weight)
  }
  cif * 100
}

# All-cause discontinuation treats every discontinuation reason as the same
# endpoint. This is the single-decrement life-table quantity 1 - S(t).
single_decrement_rates <- function(dat, horizons = c(3L, 6L, 9L, 12L)) {
  dat <- dat[is.finite(dat$entry) & is.finite(dat$exposure) &
               dat$exposure > dat$entry & dat$weight > 0,]
  surv <- 1
  out <- setNames(rep(NA_real_, length(horizons)), paste0("month_", horizons))
  for (t in seq_len(max(horizons))) {
    at_risk <- dat$entry < t & dat$exposure >= t
    risk_weight <- sum(dat$weight[at_risk])
    if (risk_weight > 0) {
      event_at_t <- dat$exposure == t & dat$discontinued == 1
      event_weight <- sum(dat$weight[event_at_t])
      surv <- surv * (1 - event_weight / risk_weight)
    }
    if (t %in% horizons) out[paste0("month_", t)] <- (1 - surv) * 100
  }
  out
}

life_table_by_group <- function(dat, group_var, group_order,
                                horizons = c(3L, 6L, 9L, 12L)) {
  rows <- lapply(group_order, function(group_name) {
    group_dat <- if (group_name == "All methods") {
      dat
    } else {
      dat[dat[[group_var]] == group_name,]
    }
    rates <- single_decrement_rates(group_dat, horizons)
    risk_counts <- vapply(
      horizons,
      function(h) sum(group_dat$entry < h & group_dat$exposure >= h),
      numeric(1)
    )
    entry_n <- sum(group_dat$entry == 0)
    risk_12_n <- unname(risk_counts[as.character(horizons) == "12"])
    support <- if (entry_n < 25 || risk_12_n < 25) {
      "Insufficient at one endpoint (<25); suppress or aggregate"
    } else if (entry_n < 50 || risk_12_n < 50) {
      "Limited at one endpoint (25-49); flag/parenthesize"
    } else {
      "Adequate for an all-cause estimate; still inspect CI"
    }
    data.frame(
      Method = group_name,
      `3 months` = unname(rates["month_3"]),
      `6 months` = unname(rates["month_6"]),
      `9 months` = unname(rates["month_9"]),
      `12 months` = unname(rates["month_12"]),
      `Weighted episodes` = sum(group_dat$weight),
      `Unweighted entering month 1` = entry_n,
      `Unweighted at risk month 12` = risk_12_n,
      `Sample support` = support,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

method_order <- c("Injectables", "Implants", "Pill",
                  "Emergency contraception", "Other", "All methods")
reason_names <- c(
  "Method failure",
  "Desire to become pregnant",
  "Other fertility-related reasons",
  "Changes in menstrual bleeding",
  "Other side effects/health concerns",
  "Wanted more effective method",
  "Other method-related reasons",
  "Husband/partner disapproved",
  "Other reasons",
  "Any reason"
)

result_rows <- lapply(method_order, function(m) {
  dat <- if (m == "All methods") episodes else episodes[episodes$method_group == m,]
  rates <- aj_cif(dat, dat$reason_group)
  out <- data.frame(Method = m, t(rates), check.names = FALSE)
  names(out)[2:11] <- reason_names
  out$`Switched to another method` <- switch_cif(dat)
  out$`Number of episodes of use` <- sum(dat$weight)
  out$`Unweighted episodes entering month 1` <- sum(dat$entry == 0)
  out
})

results <- do.call(rbind, result_rows)
rownames(results) <- NULL

published_group_order <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception",
  "Other", "All methods"
)
published_group_life_table <- life_table_by_group(
  episodes, "method_group", published_group_order
)

# Retain finer method rows only where the data have useful support. Emergency
# contraception remains separate to permit validation against the DHS report,
# but is explicitly flagged because few episodes remain at risk at month 12.
episodes$analysis_method <- "Other sparse methods"
episodes$analysis_method[episodes$method_code == 1] <- "Pill"
episodes$analysis_method[episodes$method_code == 2] <- "IUD"
episodes$analysis_method[episodes$method_code == 3] <- "Injectables"
episodes$analysis_method[episodes$method_code == 8] <- "Rhythm method"
episodes$analysis_method[episodes$method_code == 11] <- "Implants"
episodes$analysis_method[episodes$method_code == 13] <- "LAM"
episodes$analysis_method[episodes$method_code == 16] <- "Emergency contraception"

analysis_group_order <- c(
  "Injectables", "Implants", "Pill", "IUD", "Rhythm method", "LAM",
  "Emergency contraception", "Other sparse methods", "All methods"
)
disaggregated_life_table <- life_table_by_group(
  episodes, "analysis_method", analysis_group_order
)

published_file <- file.path(derived_dir, "table_7_11_published.csv")
published_reference <- read.csv(published_file, check.names = FALSE)
published_validation <- merge(
  published_group_life_table,
  published_reference[, c("Method", "Any reason", "Number of episodes of use")],
  by = "Method",
  all.x = TRUE,
  sort = FALSE
)
published_validation <- published_validation[
  match(published_group_order, published_validation$Method),
]
names(published_validation)[
  names(published_validation) == "Any reason"
] <- "DHS published 12 months"
names(published_validation)[
  names(published_validation) == "Number of episodes of use"
] <- "DHS published weighted episodes"
published_validation$`12-month difference (pp)` <-
  published_validation$`12 months` - published_validation$`DHS published 12 months`
published_validation$`Episode difference (weighted)` <-
  published_validation$`Weighted episodes` -
  published_validation$`DHS published weighted episodes`

# Boundary-condition audit used to investigate differences between the public
# IR calendar reconstruction and the final-report production denominator.
boundary_flags <- list(
  `Starts exactly 3 months before interview` =
    episodes$months_start_to_interview == 3,
  `Starts exactly 62 months before interview` =
    episodes$months_start_to_interview == 62,
  `Left truncated at 62-month boundary` = episodes$entry > 0,
  `Ends within final 3 months (censored)` =
    episodes$months_end_to_interview < 3,
  `Ongoing/censored with no discontinuation` = episodes$discontinued == 0,
  `One-month episode` = episodes$duration == 1
)
boundary_audit <- do.call(
  rbind,
  lapply(names(boundary_flags), function(flag_name) {
    keep <- boundary_flags[[flag_name]]
    do.call(
      rbind,
      lapply(published_group_order, function(group_name) {
        group_keep <- if (group_name == "All methods") {
          keep
        } else {
          keep & episodes$method_group == group_name
        }
        data.frame(
          `Candidate boundary condition` = flag_name,
          Method = group_name,
          `Unweighted episodes` = sum(group_keep),
          `Weighted episodes` = sum(episodes$weight[group_keep]),
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      })
    )
  })
)

aj_equivalence <- do.call(
  rbind,
  lapply(published_group_order, function(group_name) {
    dat <- if (group_name == "All methods") episodes else
      episodes[episodes$method_group == group_name,]
    sd_12 <- unname(single_decrement_rates(dat, 12L)["month_12"])
    aj_12 <- unname(aj_cif(dat, dat$reason_group, 12L)["any_reason"])
    data.frame(
      Method = group_name,
      `Single-decrement 12 months` = sd_12,
      `Sum of competing-risk CIFs at 12 months` = aj_12,
      `Absolute difference` = abs(sd_12 - aj_12),
      check.names = FALSE
    )
  })
)

reason_table_at_horizon <- function(horizon) {
  rows <- lapply(method_order, function(m) {
    dat <- if (m == "All methods") episodes else
      episodes[episodes$method_group == m,]
    rates <- aj_cif(dat, dat$reason_group, horizon)
    out <- data.frame(
      Duration = paste0(horizon, " months"),
      Method = m,
      t(rates),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
    names(out)[3:12] <- reason_names
    out$`Switched to another method` <- switch_cif(dat, horizon)
    out$`Weighted episodes` <- sum(dat$weight)
    out$`Unweighted episodes entering month 1` <- sum(dat$entry == 0)
    out$`Unweighted at risk at horizon` <-
      sum(dat$entry < horizon & dat$exposure >= horizon)
    out
  })
  do.call(rbind, rows)
}

reason_tables <- do.call(
  rbind,
  lapply(c(3L, 6L, 9L, 12L), reason_table_at_horizon)
)

reason_cols_for_validation <- c(
  reason_names,
  "Switched to another method"
)
reason_12_calc <- reason_tables[reason_tables$Duration == "12 months",]
reason_12_validation <- do.call(
  rbind,
  lapply(method_order, function(m) {
    calc_row <- reason_12_calc[reason_12_calc$Method == m,]
    pub_row <- published_reference[published_reference$Method == m,]
    do.call(
      rbind,
      lapply(reason_cols_for_validation, function(reason_name) {
        data.frame(
          Method = m,
          Measure = reason_name,
          `Calculated 12 months` = as.numeric(calc_row[[reason_name]]),
          `DHS published 12 months` = as.numeric(pub_row[[reason_name]]),
          `Difference (percentage points)` =
            as.numeric(calc_row[[reason_name]]) - as.numeric(pub_row[[reason_name]]),
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      })
    )
  })
)

method_diagnostics <- aggregate(
  cbind(weighted_episodes = episodes$weight,
        unweighted_episodes = rep(1, nrow(episodes))),
  by = list(method_code = episodes$method_code,
            method_alpha = episodes$method_alpha,
            method_group = episodes$method_group),
  FUN = sum
)
method_diagnostics <- method_diagnostics[order(-method_diagnostics$weighted_episodes),]

eligible_episodes <- episodes[
  is.finite(episodes$entry) & is.finite(episodes$exposure) &
    episodes$exposure > episodes$entry & episodes$weight > 0,
]
eligible_method_diagnostics <- aggregate(
  cbind(weighted_episodes = eligible_episodes$weight,
        unweighted_episodes = rep(1, nrow(eligible_episodes))),
  by = list(method_group = eligible_episodes$method_group),
  FUN = sum
)
entry0_episodes <- episodes[episodes$entry == 0,]
entry0_method_diagnostics <- aggregate(
  cbind(weighted_episodes = entry0_episodes$weight,
        unweighted_episodes = rep(1, nrow(entry0_episodes))),
  by = list(method_group = entry0_episodes$method_group),
  FUN = sum
)

fine_method_labels <- c(
  "1" = "Pill",
  "2" = "IUD",
  "3" = "Injectables",
  "4" = "Diaphragm",
  "5" = "Male condom",
  "6" = "Female sterilization",
  "7" = "Male sterilization",
  "8" = "Rhythm method",
  "9" = "Withdrawal",
  "10" = "Other traditional method",
  "11" = "Implants",
  "13" = "Lactational amenorrhea method (LAM)",
  "14" = "Female condom",
  "15" = "Foam/jelly",
  "16" = "Emergency contraception",
  "17" = "Other modern method",
  "18" = "Standard days method"
)
fine_method_sample_diagnostics <- do.call(
  rbind,
  lapply(as.integer(names(fine_method_labels)), function(code) {
    dat <- episodes[episodes$method_code == code,]
    entering_month_1 <- dat$entry == 0
    at_month_12 <- dat$entry < 12 & dat$exposure >= 12
    event_by_12 <- dat$discontinued == 1 & dat$exposure <= 12 &
      dat$exposure > dat$entry
    data.frame(
      method_code = code,
      method = unname(fine_method_labels[as.character(code)]),
      unweighted_episodes = nrow(dat),
      unweighted_women = length(unique(dat$caseid)),
      weighted_episodes = sum(dat$weight),
      unweighted_entering_month_1 = sum(entering_month_1),
      unweighted_women_entering_month_1 = length(unique(dat$caseid[entering_month_1])),
      unweighted_at_risk_month_12 = sum(at_month_12),
      unweighted_women_at_risk_month_12 = length(unique(dat$caseid[at_month_12])),
      weighted_at_risk_month_12 = sum(dat$weight[at_month_12]),
      unweighted_discontinuations_by_month_12 = sum(event_by_12),
      weighted_discontinuations_by_month_12 = sum(dat$weight[event_by_12]),
      stringsAsFactors = FALSE
    )
  })
)

discontinued_episodes <- episodes[episodes$discontinued == 1,]
reason_diagnostics <- aggregate(
  cbind(weighted_discontinuations = discontinued_episodes$weight,
        unweighted_discontinuations = rep(1, nrow(discontinued_episodes))),
  by = list(reason_code = discontinued_episodes$reason_code,
            reason_alpha = discontinued_episodes$reason_alpha,
            reason_group = discontinued_episodes$reason_group),
  FUN = sum
)
reason_diagnostics <- reason_diagnostics[order(reason_diagnostics$reason_code),]

write.csv(results, file.path(derived_dir, "table_7_11_reconstructed.csv"), row.names = FALSE)
write.csv(method_diagnostics, file.path(derived_dir, "method_diagnostics.csv"), row.names = FALSE)
write.csv(eligible_method_diagnostics, file.path(derived_dir, "eligible_method_diagnostics.csv"), row.names = FALSE)
write.csv(entry0_method_diagnostics, file.path(derived_dir, "entry0_method_diagnostics.csv"), row.names = FALSE)
write.csv(fine_method_sample_diagnostics, file.path(derived_dir, "fine_method_sample_diagnostics.csv"), row.names = FALSE)
write.csv(published_group_life_table, file.path(derived_dir, "all_cause_life_table_published_groups.csv"), row.names = FALSE)
write.csv(disaggregated_life_table, file.path(derived_dir, "all_cause_life_table_disaggregated.csv"), row.names = FALSE)
write.csv(published_validation, file.path(derived_dir, "all_cause_12_month_validation.csv"), row.names = FALSE)
write.csv(aj_equivalence, file.path(derived_dir, "single_vs_competing_risk_equivalence.csv"), row.names = FALSE)
write.csv(boundary_audit, file.path(derived_dir, "episode_boundary_sensitivity_audit.csv"), row.names = FALSE)
write.csv(reason_tables, file.path(derived_dir, "competing_risk_reasons_3_6_9_12_months.csv"), row.names = FALSE)
write.csv(reason_12_validation, file.path(derived_dir, "competing_risk_reasons_12_month_validation.csv"), row.names = FALSE)
write.csv(reason_diagnostics, file.path(derived_dir, "reason_diagnostics.csv"), row.names = FALSE)
write.csv(
  data.frame(
    metric = c(
      "Women in IR file",
      "Contraceptive episodes retained (unweighted)",
      "Contraceptive episodes retained (weighted)",
      "Unknown method codes",
      "Unknown reason codes among discontinuations",
      "Duplicate case IDs"
    ),
    value = c(
      nrow(calendar),
      nrow(episodes),
      sum(episodes$weight),
      sum(episodes$method_code == -1),
      sum(episodes$discontinued == 1 & episodes$reason_code == -1),
      sum(duplicated(calendar$caseid))
    )
  ),
  file.path(derived_dir, "validation_summary.csv"),
  row.names = FALSE
)

print(results, digits = 4)
cat("\nMethod diagnostics:\n")
print(method_diagnostics, digits = 4, row.names = FALSE)
cat("\nEligible method diagnostics:\n")
print(eligible_method_diagnostics, digits = 4, row.names = FALSE)
cat("\nEntry-zero method diagnostics:\n")
print(entry0_method_diagnostics, digits = 4, row.names = FALSE)
cat("\nReason diagnostics:\n")
print(reason_diagnostics, digits = 4, row.names = FALSE)
