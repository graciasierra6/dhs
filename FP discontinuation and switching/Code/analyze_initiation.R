# Observed contraceptive method initiation and dynamic method mix
#
# This analysis produces two complementary measures:
#
# 1. Initiation mix: the distribution of observed contraceptive episode starts
#    across method categories. The denominator is all observed method starts,
#    including starts after non-use, starts after pregnancy-related calendar
#    states, and starts that represent a switch from another method.
#
# 2. Initiation rate: observed contraceptive episode starts divided by all
#    observed calendar woman-months in the analysis period, reported per 1,000
#    weighted woman-months. Unlike initiation mix, this describes the frequency
#    of starting episodes rather than the composition of starts.
#
# Starts are observed within the 3-62 month analysis period and must have their
# immediately preceding calendar state observed. Episodes already underway at
# the oldest calendar boundary are not treated as observed initiations.

required_objects <- c(
  "episodes", "events_all", "calendar", "method_numeric", "derived_dir"
)
missing_objects <- required_objects[!vapply(required_objects, exists, logical(1))]
if (length(missing_objects) > 0L) {
  stop(
    "Initiation analysis is missing required objects: ",
    paste(missing_objects, collapse = ", "),
    call. = FALSE
  )
}

method_group_from_code <- function(code) {
  out <- rep("Other", length(code))
  out[code == 1L] <- "Pill"
  out[code == 3L] <- "Injectables"
  out[code == 11L] <- "Implants"
  out[code == 16L] <- "Emergency contraception"
  out
}

contraceptive_codes <- as.integer(unname(method_numeric))

# Add the preceding full calendar state to every event run.
events_for_starts <- events_all[order(events_all$caseid, events_all$event_start),]
events_for_starts$previous_full_code <- NA_integer_
events_split <- split(seq_len(nrow(events_for_starts)), events_for_starts$caseid)
for (idx in events_split) {
  if (length(idx) > 1L) {
    events_for_starts$previous_full_code[idx[-1L]] <-
      events_for_starts$method_code[idx[-length(idx)]]
  }
}

episode_key <- paste(episodes$caseid, episodes$event_start, sep = "|")
event_key <- paste(
  events_for_starts$caseid, events_for_starts$event_start, sep = "|"
)
episodes$previous_full_code <- events_for_starts$previous_full_code[
  match(episode_key, event_key)
]

observed_starts <- episodes[
  episodes$months_start_to_interview >= 3L &
    episodes$months_start_to_interview <= 62L &
    !is.na(episodes$previous_full_code),
]

observed_starts$start_type <- "Other observed transition"
observed_starts$start_type[observed_starts$previous_full_code == 0L] <-
  "After non-use"
observed_starts$start_type[
  observed_starts$previous_full_code %in% contraceptive_codes
] <- "Method switch"
observed_starts$start_type[
  observed_starts$previous_full_code %in% c(81L, 82L, 83L)
] <- "After pregnancy/birth/termination"

initiation_method_order <- c(
  "Injectables", "Implants", "Pill", "Emergency contraception", "Other"
)

mix_rows <- lapply(initiation_method_order, function(method_name) {
  dat <- observed_starts[observed_starts$method_group == method_name,]
  data.frame(
    Method = method_name,
    `Observed starts (unweighted)` = nrow(dat),
    `Observed starts (weighted)` = sum(dat$weight),
    `Weighted starts after non-use` =
      sum(dat$weight[dat$start_type == "After non-use"]),
    `Weighted starts via method switch` =
      sum(dat$weight[dat$start_type == "Method switch"]),
    `Weighted starts after pregnancy/birth/termination` =
      sum(dat$weight[
        dat$start_type == "After pregnancy/birth/termination"
      ]),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
})
initiation_mix <- do.call(rbind, mix_rows)
total_weighted_starts <- sum(initiation_mix$`Observed starts (weighted)`)
initiation_mix$`Share of observed starts (%)` <-
  initiation_mix$`Observed starts (weighted)` / total_weighted_starts * 100
initiation_mix <- rbind(
  initiation_mix,
  data.frame(
    Method = "All methods",
    `Observed starts (unweighted)` = nrow(observed_starts),
    `Observed starts (weighted)` = total_weighted_starts,
    `Weighted starts after non-use` =
      sum(observed_starts$weight[
        observed_starts$start_type == "After non-use"
      ]),
    `Weighted starts via method switch` =
      sum(observed_starts$weight[
        observed_starts$start_type == "Method switch"
      ]),
    `Weighted starts after pregnancy/birth/termination` =
      sum(observed_starts$weight[
        observed_starts$start_type == "After pregnancy/birth/termination"
      ]),
    `Share of observed starts (%)` = 100,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
)

# Calendar-year method mix shows whether the composition of observed starts
# changes during the calendar period. CMC 1 is January 1900.
observed_starts$start_year <-
  1900L + (as.integer(observed_starts$event_start) - 1L) %/% 12L
annual_start_totals <- aggregate(
  observed_starts$weight,
  by = list(
    Year = observed_starts$start_year,
    Method = observed_starts$method_group
  ),
  FUN = sum
)
names(annual_start_totals)[3] <- "Weighted starts"
annual_year_totals <- aggregate(
  annual_start_totals$`Weighted starts`,
  by = list(Year = annual_start_totals$Year),
  FUN = sum
)
names(annual_year_totals)[2] <- "All weighted starts"
annual_initiation_mix <- merge(
  annual_start_totals, annual_year_totals, by = "Year", all.x = TRUE
)
annual_initiation_mix$`Share of starts within year (%)` <-
  annual_initiation_mix$`Weighted starts` /
    annual_initiation_mix$`All weighted starts` * 100
annual_initiation_mix <- annual_initiation_mix[
  order(annual_initiation_mix$Year,
        match(annual_initiation_mix$Method, initiation_method_order)),
]

# Create the requested method-by-year initiation table. Each year column is a
# survey-weighted percentage distribution of observed contraceptive episode
# starts, so the five method rows sum to 100% within a year. This is a method
# mix among starts, not a population initiation rate.
annual_method_initiation_percent <- data.frame(
  Method = initiation_method_order,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
for (year_value in sort(unique(annual_initiation_mix$Year))) {
  dat <- annual_initiation_mix[annual_initiation_mix$Year == year_value,]
  annual_method_initiation_percent[[as.character(year_value)]] <- vapply(
    initiation_method_order,
    function(method_name) {
      value <- dat$`Share of starts within year (%)`[
        dat$Method == method_name
      ]
      if (length(value) == 0L) 0 else value[1L]
    },
    numeric(1)
  )
}

# Annual calendar-based contraceptive-use prevalence. The denominator is every
# valid, observed calendar woman-month 3-62 months before interview. The
# numerator is the subset coded as use of any contraceptive method, or use of a
# modern method. Pregnancy, birth, termination, and non-use months remain in
# the denominator; unknown or blank states are excluded as unobservable.
modern_method_codes <- c(1L:7L, 11L:18L)
traditional_method_codes <- c(8L, 9L, 10L)
valid_calendar_states <- c("0", names(method_numeric), "B", "P", "T")

annual_month_rows <- vector("list", nrow(calendar))
for (i in seq_len(nrow(calendar))) {
  start_position <- as.integer(calendar$v018[i])
  calendar_length <- as.integer(calendar$v019[i])
  if (is.na(start_position) || is.na(calendar_length)) next

  last_position <- min(80L, start_position + calendar_length - 1L)
  positions <- start_position + 3L:62L
  positions <- positions[positions <= last_position & positions <= 80L]
  if (length(positions) == 0L) next

  state_alpha <- substring(calendar$vcal_1[i], positions, positions)
  valid <- state_alpha %in% valid_calendar_states
  if (!any(valid)) next
  positions <- positions[valid]
  state_alpha <- state_alpha[valid]
  month_cmc <- as.integer(calendar$v008[i]) - (positions - start_position)
  state_numeric <- rep(NA_integer_, length(state_alpha))
  state_numeric[state_alpha == "0"] <- 0L
  method_state <- state_alpha %in% names(method_numeric)
  state_numeric[method_state] <- as.integer(
    unname(method_numeric[state_alpha[method_state]])
  )
  respondent_weight <- as.numeric(calendar$v005[i]) / 1e6

  annual_month_rows[[i]] <- data.frame(
    caseid = as.character(calendar$caseid[i]),
    Year = 1900L + (month_cmc - 1L) %/% 12L,
    Month = (month_cmc - 1L) %% 12L + 1L,
    Weight = respondent_weight,
    Any_use = as.integer(state_numeric %in% contraceptive_codes),
    Modern_use = as.integer(state_numeric %in% modern_method_codes),
    Traditional_use = as.integer(state_numeric %in% traditional_method_codes),
    stringsAsFactors = FALSE
  )
}
annual_months <- do.call(rbind, annual_month_rows)
if (is.null(annual_months) || nrow(annual_months) == 0L) {
  stop("No valid calendar woman-months were available for annual use estimates.")
}
full_sample_weight <- sum(as.numeric(calendar$v005) / 1e6)

annual_use_rows <- lapply(sort(unique(annual_months$Year)), function(year_value) {
  dat <- annual_months[annual_months$Year == year_value,]
  total_weight <- sum(dat$Weight)
  represented_months <- sort(unique(dat$Month))
  equivalent_full_sample_months <- total_weight / full_sample_weight
  data.frame(
    `Calendar year` = year_value,
    `Any contraceptive method use (%)` =
      sum(dat$Weight * dat$Any_use) / total_weight * 100,
    `Modern contraceptive method use (%)` =
      sum(dat$Weight * dat$Modern_use) / total_weight * 100,
    `Traditional method use (%)` =
      sum(dat$Weight * dat$Traditional_use) / total_weight * 100,
    `Observed calendar woman-months (unweighted)` = nrow(dat),
    `Observed calendar woman-months (weighted)` = total_weight,
    `Women contributing (unweighted)` = length(unique(dat$caseid)),
    `Equivalent months of full-sample coverage` =
      equivalent_full_sample_months,
    `Calendar months represented` = paste0(
      min(represented_months), "-", max(represented_months),
      " (", length(represented_months), " months)"
    ),
    `Coverage` = if (
      length(represented_months) == 12L &&
        abs(equivalent_full_sample_months - 12) < 0.01
    ) {
      "Complete full-sample calendar year"
    } else {
      "Partial boundary-year coverage"
    },
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
})
annual_calendar_contraceptive_use <- do.call(rbind, annual_use_rows)

# Like-for-like current-use validation. v312 is measured once, at interview,
# and therefore cannot provide retrospective estimates for earlier calendar
# years. Compare it with the calendar state in that same interview month,
# overall and by interview year. v313 supplies the DHS modern/traditional
# classification for the survey-question measure.
interview_position <- as.integer(calendar$v018)
interview_state_alpha <- substring(
  calendar$vcal_1, interview_position, interview_position
)
interview_state_numeric <- rep(NA_integer_, nrow(calendar))
interview_state_numeric[interview_state_alpha == "0"] <- 0L
interview_method_state <- interview_state_alpha %in% names(method_numeric)
interview_state_numeric[interview_method_state] <- as.integer(
  unname(method_numeric[interview_state_alpha[interview_method_state]])
)
valid_current_use <-
  interview_state_alpha %in% valid_calendar_states &
  !is.na(calendar$v312) & !is.na(calendar$v313)
current_use_frame <- data.frame(
  Interview_year = 1900L + (as.integer(calendar$v008) - 1L) %/% 12L,
  Weight = as.numeric(calendar$v005) / 1e6,
  Survey_any = as.integer(as.numeric(calendar$v312) > 0),
  Survey_modern = as.integer(as.numeric(calendar$v313) == 3),
  Calendar_any = as.integer(interview_state_numeric %in% contraceptive_codes),
  Calendar_modern = as.integer(interview_state_numeric %in% modern_method_codes),
  stringsAsFactors = FALSE
)
current_use_frame <- current_use_frame[valid_current_use,]

current_use_row <- function(dat, label) {
  total_weight <- sum(dat$Weight)
  survey_any <- sum(dat$Weight * dat$Survey_any) / total_weight * 100
  calendar_any <- sum(dat$Weight * dat$Calendar_any) / total_weight * 100
  survey_modern <- sum(dat$Weight * dat$Survey_modern) / total_weight * 100
  calendar_modern <- sum(dat$Weight * dat$Calendar_modern) / total_weight * 100
  data.frame(
    `Interview period` = label,
    `v312 any-method current use (%)` = survey_any,
    `Calendar interview-month any-method use (%)` = calendar_any,
    `Calendar minus v312 any-method difference (percentage points)` =
      calendar_any - survey_any,
    `v312/v313 modern-method current use (%)` = survey_modern,
    `Calendar interview-month modern-method use (%)` = calendar_modern,
    `Calendar minus survey modern-method difference (percentage points)` =
      calendar_modern - survey_modern,
    `Women (unweighted)` = nrow(dat),
    `Women (weighted)` = total_weight,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}
interview_years <- sort(unique(current_use_frame$Interview_year))
current_use_comparison <- do.call(
  rbind,
  c(
    lapply(interview_years, function(year_value) {
      current_use_row(
        current_use_frame[
          current_use_frame$Interview_year == year_value,
        ],
        as.character(year_value)
      )
    }),
    list(current_use_row(current_use_frame, "All interviews"))
  )
)

# Add the corresponding interview-year v312 benchmarks to the annual calendar
# file when the year overlaps fieldwork. Historical years remain unavailable.
annual_calendar_contraceptive_use$`v312 any-method current use (%)` <- NA_real_
annual_calendar_contraceptive_use$`v312/v313 modern-method current use (%)` <-
  NA_real_
for (year_value in interview_years) {
  annual_match <-
    annual_calendar_contraceptive_use$`Calendar year` == year_value
  comparison_match <- current_use_comparison$`Interview period` ==
    as.character(year_value)
  if (any(annual_match) && any(comparison_match)) {
    annual_calendar_contraceptive_use$`v312 any-method current use (%)`[
      annual_match
    ] <- current_use_comparison$`v312 any-method current use (%)`[
      comparison_match
    ]
    annual_calendar_contraceptive_use$`v312/v313 modern-method current use (%)`[
      annual_match
    ] <- current_use_comparison$`v312/v313 modern-method current use (%)`[
      comparison_match
    ]
  }
}

annual_use_identity_error <- max(abs(
  annual_calendar_contraceptive_use$`Any contraceptive method use (%)` -
    annual_calendar_contraceptive_use$`Modern contraceptive method use (%)` -
    annual_calendar_contraceptive_use$`Traditional method use (%)`
))
if (annual_use_identity_error > 1e-8) {
  stop("Annual any-use prevalence does not equal modern plus traditional use.")
}
year_share_sums <- colSums(
  annual_method_initiation_percent[, -1, drop = FALSE]
)
if (any(abs(year_share_sums - 100) > 1e-8)) {
  stop("Annual method initiation shares do not sum to 100% within each year.")
}
annual_calendar_validation <- data.frame(
  `Calendar year` = annual_calendar_contraceptive_use$`Calendar year`,
  `Any minus modern plus traditional (percentage points)` =
    annual_calendar_contraceptive_use$`Any contraceptive method use (%)` -
      annual_calendar_contraceptive_use$`Modern contraceptive method use (%)` -
      annual_calendar_contraceptive_use$`Traditional method use (%)`,
  `Initiation method-share sum (%)` = as.numeric(year_share_sums[
    as.character(annual_calendar_contraceptive_use$`Calendar year`)
  ]),
  `Coverage` = annual_calendar_contraceptive_use$Coverage,
  `Status` = ifelse(
    abs(
      annual_calendar_contraceptive_use$`Any contraceptive method use (%)` -
        annual_calendar_contraceptive_use$`Modern contraceptive method use (%)` -
        annual_calendar_contraceptive_use$`Traditional method use (%)`
    ) < 1e-8 &
      abs(as.numeric(year_share_sums[
        as.character(annual_calendar_contraceptive_use$`Calendar year`)
      ]) - 100) < 1e-8,
    "PASS", "FAIL"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# The initiation-rate denominator is all calendar woman-months observed 3-62
# months before interview. It is deliberately broader than non-use exposure:
# the numerator includes every observed method start, including switches and
# starts after pregnancy-related calendar states.
observed_calendar_months_unweighted <- 0L
observed_calendar_months_weighted <- 0
for (i in seq_len(nrow(calendar))) {
  start_position <- as.integer(calendar$v018[i])
  calendar_length <- as.integer(calendar$v019[i])
  if (is.na(start_position) || is.na(calendar_length)) next
  last_position <- min(80L, start_position + calendar_length - 1L)
  positions <- start_position + 3L:62L
  observed_count <- sum(positions <= last_position & positions <= 80L)
  observed_calendar_months_unweighted <-
    observed_calendar_months_unweighted + observed_count
  observed_calendar_months_weighted <-
    observed_calendar_months_weighted +
      observed_count * as.numeric(calendar$v005[i]) / 1e6
}

observed_initiation_rates <- data.frame(
  Method = initiation_mix$Method,
  `Observed starts (unweighted)` =
    initiation_mix$`Observed starts (unweighted)`,
  `Observed starts (weighted)` =
    initiation_mix$`Observed starts (weighted)`,
  `Observed calendar woman-months (unweighted)` =
    observed_calendar_months_unweighted,
  `Observed calendar woman-months (weighted)` =
    observed_calendar_months_weighted,
  `Observed starts per 1,000 weighted calendar woman-months` =
    initiation_mix$`Observed starts (weighted)` /
      observed_calendar_months_weighted * 1000,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

# Count non-use month-to-next-month opportunities and transitions into methods.
# An offset of 4-63 months before interview permits starts 3-62 months before
# interview while ensuring that both calendar months are observed.
nonuse_exposure_weighted <- 0
nonuse_exposure_unweighted <- 0L
transition_weighted <- setNames(
  rep(0, length(initiation_method_order)), initiation_method_order
)
transition_unweighted <- setNames(
  rep(0L, length(initiation_method_order)), initiation_method_order
)

decode_method <- function(code) {
  if (code == "0") return(0L)
  if (code %in% names(method_numeric)) {
    return(as.integer(unname(method_numeric[code])))
  }
  NA_integer_
}

for (i in seq_len(nrow(calendar))) {
  start_position <- as.integer(calendar$v018[i])
  calendar_length <- as.integer(calendar$v019[i])
  if (is.na(start_position) || is.na(calendar_length)) next
  respondent_weight <- as.numeric(calendar$v005[i]) / 1e6

  for (months_before in 4L:63L) {
    current_position <- start_position + months_before
    next_position <- current_position - 1L
    if (current_position > 80L ||
        current_position > start_position + calendar_length - 1L ||
        next_position < start_position) next

    current_code <- substring(
      calendar$vcal_1[i], current_position, current_position
    )
    if (current_code != "0") next

    nonuse_exposure_weighted <-
      nonuse_exposure_weighted + respondent_weight
    nonuse_exposure_unweighted <- nonuse_exposure_unweighted + 1L

    next_code <- decode_method(substring(
      calendar$vcal_1[i], next_position, next_position
    ))
    if (!is.na(next_code) && next_code %in% contraceptive_codes) {
      method_name <- method_group_from_code(next_code)
      transition_weighted[method_name] <-
        transition_weighted[method_name] + respondent_weight
      transition_unweighted[method_name] <-
        transition_unweighted[method_name] + 1L
    }
  }
}

initiation_rates <- data.frame(
  Method = initiation_method_order,
  `Initiations after non-use (unweighted)` =
    as.integer(transition_unweighted[initiation_method_order]),
  `Initiations after non-use (weighted)` =
    as.numeric(transition_weighted[initiation_method_order]),
  `Eligible non-use woman-months (unweighted)` =
    nonuse_exposure_unweighted,
  `Eligible non-use woman-months (weighted)` =
    nonuse_exposure_weighted,
  `Initiations per 1,000 weighted non-use woman-months` =
    as.numeric(transition_weighted[initiation_method_order]) /
      nonuse_exposure_weighted * 1000,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
initiation_rates <- rbind(
  initiation_rates,
  data.frame(
    Method = "All methods",
    `Initiations after non-use (unweighted)` = sum(transition_unweighted),
    `Initiations after non-use (weighted)` = sum(transition_weighted),
    `Eligible non-use woman-months (unweighted)` =
      nonuse_exposure_unweighted,
    `Eligible non-use woman-months (weighted)` =
      nonuse_exposure_weighted,
    `Initiations per 1,000 weighted non-use woman-months` =
      sum(transition_weighted) / nonuse_exposure_weighted * 1000,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
)

if (abs(sum(initiation_mix$`Share of observed starts (%)`[
  initiation_mix$Method != "All methods"
]) - 100) > 1e-8) {
  stop("Initiation mix does not sum to 100%.")
}
if (abs(
  sum(initiation_rates$`Initiations per 1,000 weighted non-use woman-months`[
    initiation_rates$Method != "All methods"
  ]) - initiation_rates$`Initiations per 1,000 weighted non-use woman-months`[
    initiation_rates$Method == "All methods"
  ]
) > 1e-8) {
  stop("Method-specific initiation rates do not sum to the all-method rate.")
}

write.csv(
  initiation_mix,
  file.path(derived_dir, "observed_method_initiation_mix.csv"),
  row.names = FALSE
)
write.csv(
  initiation_rates,
  file.path(derived_dir, "initiation_after_nonuse_rates.csv"),
  row.names = FALSE
)
write.csv(
  observed_initiation_rates,
  file.path(derived_dir, "observed_method_initiation_rates.csv"),
  row.names = FALSE
)
write.csv(
  annual_initiation_mix,
  file.path(derived_dir, "annual_observed_method_initiation_mix.csv"),
  row.names = FALSE
)
write.csv(
  annual_method_initiation_percent,
  file.path(derived_dir, "annual_method_initiation_percent.csv"),
  row.names = FALSE
)
write.csv(
  annual_calendar_contraceptive_use,
  file.path(derived_dir, "annual_calendar_contraceptive_use.csv"),
  row.names = FALSE
)
write.csv(
  current_use_comparison,
  file.path(derived_dir, "calendar_vs_v312_current_use.csv"),
  row.names = FALSE
)
write.csv(
  annual_calendar_validation,
  file.path(derived_dir, "annual_calendar_validation.csv"),
  row.names = FALSE
)

message(
  "Created initiation mix for ", nrow(observed_starts),
  " observed starts and rates from ",
  observed_calendar_months_unweighted, " observed calendar woman-months."
)
