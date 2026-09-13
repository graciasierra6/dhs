# Complementary observed-start ("leaky bucket") analysis
#
# The primary discontinuation analysis follows the DHS life-table population,
# which includes eligible episodes observed at risk in the analysis window and
# permits delayed entry for episodes that began earlier in the recorded
# calendar. This script adds a complementary cohort restricted to episodes
# whose method start and immediately preceding calendar state are both
# observed. It does not replace the DHS-comparable estimates.

required_objects <- c(
  "episodes", "observed_starts", "reinitiation", "method_order",
  "published_group_life_table", "life_table_by_group", "derived_dir"
)
missing_objects <- required_objects[!vapply(required_objects, exists, logical(1))]
if (length(missing_objects) > 0L) {
  stop(
    "Leaky-bucket analysis is missing required objects: ",
    paste(missing_objects, collapse = ", "),
    call. = FALSE
  )
}

episode_id <- function(dat) paste(dat$caseid, dat$event_start, sep = "|")

observed_start_cohort <- observed_starts
if (anyDuplicated(episode_id(observed_start_cohort))) {
  stop("Observed-start cohort contains duplicate episode identifiers.")
}
if (any(observed_start_cohort$entry != 0L)) {
  stop("Observed-start cohort unexpectedly contains delayed-entry episodes.")
}

leaky_bucket_life_table <- life_table_by_group(
  observed_start_cohort,
  "method_group",
  method_order
)

primary_columns <- c(
  "Method", "3 months", "6 months", "9 months", "12 months",
  "Weighted episodes", "Unweighted entering month 1"
)
leaky_bucket_discontinuation <- merge(
  published_group_life_table[, primary_columns],
  leaky_bucket_life_table[, primary_columns],
  by = "Method",
  suffixes = c(" - DHS-style population", " - observed-start cohort"),
  all = TRUE,
  sort = FALSE
)
leaky_bucket_discontinuation <- leaky_bucket_discontinuation[
  match(method_order, leaky_bucket_discontinuation$Method),
]

# Reinitiation pathways distinguish a same-method restart from a switch to a
# different contraceptive method. Pregnancy before reinitiation is retained as
# a competing event; interview is right censoring.
observed_start_ids <- episode_id(observed_start_cohort)
reinitiation$analysis_episode_id <- episode_id(reinitiation)
leaky_reinitiation <- reinitiation[
  reinitiation$analysis_episode_id %in% observed_start_ids,
]

pathway_cif <- function(dat, horizons = c(1L, 3L, 6L, 9L, 12L)) {
  dat$path_status <- 0L
  is_restart <- dat$status == 1L
  has_next_method <- !is.na(dat$next_contra_method) & !is.na(dat$method_code)
  dat$path_status[
    is_restart & has_next_method & dat$next_contra_method != dat$method_code
  ] <- 1L
  dat$path_status[
    is_restart & has_next_method & dat$next_contra_method == dat$method_code
  ] <- 2L
  dat$path_status[dat$status == 2L] <- 3L

  if (any(is_restart & !dat$path_status %in% c(1L, 2L))) {
    stop("A reinitiation could not be classified as same- or different-method.")
  }

  survival <- 1
  cif <- setNames(numeric(3), c("different", "same", "pregnancy"))
  output <- vector("list", length(horizons))

  for (month in seq_len(max(horizons))) {
    at_risk <- dat$event_month >= month
    risk_weight <- sum(dat$weight[at_risk])
    if (risk_weight > 0) {
      events <- vapply(
        1L:3L,
        function(status_value) {
          sum(dat$weight[
            dat$event_month == month & dat$path_status == status_value
          ])
        },
        numeric(1)
      )
      cif <- cif + survival * events / risk_weight
      survival <- survival * (1 - sum(events) / risk_weight)
    }

    if (month %in% horizons) {
      output[[match(month, horizons)]] <- data.frame(
        Month = month,
        `Switched to different method (%)` = cif["different"] * 100,
        `Restarted same method (%)` = cif["same"] * 100,
        `Any-method reinitiation (%)` =
          (cif["different"] + cif["same"]) * 100,
        `Pregnancy before reinitiation (%)` = cif["pregnancy"] * 100,
        `No observed event (%)` = survival * 100,
        `Weighted eligible episodes` = sum(dat$weight),
        `Unweighted eligible episodes` = nrow(dat),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }
  }
  do.call(rbind, output)
}

cohort_definitions <- list(
  `DHS-style eligible discontinuations` = reinitiation,
  `Observed-start leaky-bucket cohort` = leaky_reinitiation
)

reinitiation_switching_pathways <- do.call(
  rbind,
  lapply(names(cohort_definitions), function(cohort_name) {
    cohort_data <- cohort_definitions[[cohort_name]]
    do.call(
      rbind,
      lapply(method_order, function(method_name) {
        dat <- if (method_name == "All methods") {
          cohort_data
        } else {
          cohort_data[cohort_data$method_group == method_name,]
        }
        data.frame(
          Cohort = cohort_name,
          Method = method_name,
          pathway_cif(dat),
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      })
    )
  })
)
rownames(reinitiation_switching_pathways) <- NULL

pathway_identity_error <- max(abs(
  reinitiation_switching_pathways$`Switched to different method (%)` +
    reinitiation_switching_pathways$`Restarted same method (%)` +
    reinitiation_switching_pathways$`Pregnancy before reinitiation (%)` +
    reinitiation_switching_pathways$`No observed event (%)` - 100
))
restart_identity_error <- max(abs(
  reinitiation_switching_pathways$`Switched to different method (%)` +
    reinitiation_switching_pathways$`Restarted same method (%)` -
    reinitiation_switching_pathways$`Any-method reinitiation (%)`
))
if (pathway_identity_error > 1e-8 || restart_identity_error > 1e-8) {
  stop("Switching/reinitiation pathway identities failed.")
}

leaky_bucket_validation <- data.frame(
  Check = c(
    "Observed-start episode identifiers are unique",
    "Observed-start episodes have entry month zero",
    "Observed-start reinitiation episodes are a subset of observed starts",
    "Switching, same-method restart, pregnancy, and no event sum to 100%",
    "Different-method plus same-method restart equals any reinitiation"
  ),
  Value = c(
    anyDuplicated(episode_id(observed_start_cohort)),
    sum(observed_start_cohort$entry != 0L),
    sum(!leaky_reinitiation$analysis_episode_id %in% observed_start_ids),
    pathway_identity_error,
    restart_identity_error
  ),
  Status = "PASS",
  stringsAsFactors = FALSE
)

write.csv(
  leaky_bucket_discontinuation,
  file.path(derived_dir, "leaky_bucket_discontinuation_comparison.csv"),
  row.names = FALSE
)
write.csv(
  reinitiation_switching_pathways,
  file.path(derived_dir, "reinitiation_switching_pathways.csv"),
  row.names = FALSE
)
write.csv(
  leaky_bucket_validation,
  file.path(derived_dir, "leaky_bucket_validation.csv"),
  row.names = FALSE
)

message(
  "Created leaky-bucket analysis for ", nrow(observed_start_cohort),
  " observed starts and ", nrow(leaky_reinitiation),
  " eligible post-discontinuation episodes."
)
