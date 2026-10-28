suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(readxl)
  library(minpack.lm)
  library(rstan)
  library(stringr)
})

options(mc.cores = max(1L, parallel::detectCores() - 1L))
rstan_options(auto_write = TRUE)

# Use the R toolchain configured on the current machine.

inv_logit <- function(x) 1 / (1 + exp(-x))
calc_qcol <- function(x, prob) apply(x, 2, quantile, probs = prob, na.rm = TRUE)

extract_assignment_from_rmd <- function(rmd_path, var_name) {
  lines <- readLines(rmd_path, warn = FALSE)
  start_idx <- which(str_detect(lines, paste0("^", var_name, " <- ")))[1]
  if (is.na(start_idx)) stop("Could not find `", var_name, "` in ", rmd_path)

  expr_lines <- character()
  paren_balance <- 0L
  brace_balance <- 0L
  bracket_balance <- 0L

  for (i in start_idx:length(lines)) {
    line <- lines[[i]]
    expr_lines <- c(expr_lines, line)
    code <- sub("#.*$", "", line)
    paren_balance <- paren_balance + str_count(code, fixed("(")) - str_count(code, fixed(")"))
    brace_balance <- brace_balance + str_count(code, fixed("{")) - str_count(code, fixed("}"))
    bracket_balance <- bracket_balance + str_count(code, fixed("[")) - str_count(code, fixed("]"))
    if (i > start_idx && paren_balance <= 0L && brace_balance <= 0L && bracket_balance <= 0L) break
  }

  env <- new.env(parent = globalenv())
  eval(parse(text = expr_lines), envir = env)
  env[[var_name]]
}

select_smoke_countries <- function(obs_data) {
  chosen <- obs_data %>%
    count(region_prior, region, country, name = "n_surveys") %>%
    filter(n_surveys >= 4) %>%
    arrange(region_prior, desc(n_surveys), country) %>%
    group_by(region_prior) %>%
    slice_head(n = 2) %>%
    ungroup() %>%
    pull(country)

  if (length(chosen) < 8) {
    chosen <- obs_data %>%
      count(country, sort = TRUE, name = "n_surveys") %>%
      slice_head(n = 12) %>%
      pull(country)
  }

  unique(chosen)
}

build_fpet_data_objects <- function(root_dir, scope = c("global", "ssa"), mode = c("full", "smoke")) {
  scope <- match.arg(scope)
  mode <- match.arg(mode)

  source_rmd_path <- file.path(root_dir, "dhs_analysis_production.Rmd")
  region_label_lookup <- extract_assignment_from_rmd(source_rmd_path, "region_label_lookup")
  region_lookup <- extract_assignment_from_rmd(source_rmd_path, "region_lookup")
  wb_region_lookup <- extract_assignment_from_rmd(source_rmd_path, "wb_region_lookup")
  wb_country_name_lookup <- extract_assignment_from_rmd(source_rmd_path, "wb_country_name_lookup")
  region_prior_levels <- region_label_lookup$region_prior
  ssa_regions <- c("West Africa", "Central Africa", "East/Southern Africa")

  mcpr_model_data <- read.csv(file.path(root_dir, "mcpr_data.csv"))

  obs_data <- mcpr_model_data %>%
    mutate(
      region = unname(region_lookup[country]),
      y = round(mCPR * n_women),
      n = round(n_women)
    ) %>%
    filter(
      !is.na(country),
      !is.na(region),
      !is.na(year),
      !is.na(mCPR),
      !is.na(n),
      n > 0
    ) %>%
    left_join(region_label_lookup, by = "region") %>%
    group_by(country) %>%
    mutate(n_surveys = n()) %>%
    ungroup() %>%
    filter(n_surveys >= 2)

  if (scope == "ssa") {
    obs_data <- obs_data %>% filter(region %in% ssa_regions)
  }

  if (mode == "smoke") {
    obs_data <- obs_data %>% filter(country %in% select_smoke_countries(obs_data))
  }

  obs_data <- obs_data %>%
    arrange(region_prior, country, year) %>%
    mutate(row_id = row_number())

  wb_raw <- read_excel(file.path(root_dir, "wb_surveys.xlsx"), sheet = 1, skip = 3)
  year_cols <- names(wb_raw)[grepl("^\\d{4}$", names(wb_raw))]

  wb_long <- wb_raw %>%
    select(`Country Name`, `Country Code`, `Indicator Name`, `Indicator Code`, all_of(year_cols)) %>%
    pivot_longer(cols = all_of(year_cols), names_to = "year", values_to = "mcpr_pct") %>%
    mutate(
      year = as.integer(year),
      mcpr_pct = as.numeric(mcpr_pct),
      mcpr_prop = mcpr_pct / 100
    ) %>%
    left_join(wb_country_name_lookup, by = "Country Code") %>%
    mutate(`Country Name` = coalesce(country_name_english, `Country Name`)) %>%
    filter(
      year >= 1985,
      !is.na(`Country Name`),
      !is.na(`Country Code`),
      !is.na(mcpr_prop),
      between(mcpr_prop, 0, 1)
    ) %>%
    select(-country_name_english) %>%
    left_join(wb_region_lookup, by = "Country Code") %>%
    filter(!is.na(wb_region))

  wb_country_mle <- wb_long %>%
    group_by(`Country Name`, `Country Code`, wb_region) %>%
    filter(n_distinct(year) >= 5) %>%
    group_modify(~{
      dat <- .x %>% arrange(year) %>% mutate(year_center = year - 2000)
      fit <- tryCatch(
        nlsLM(
          mcpr_prop ~ K / (1 + exp(-(year_center - t0) / s)),
          data = dat,
          start = list(
            K = min(0.95, max(dat$mcpr_prop, na.rm = TRUE) * 1.20),
            t0 = stats::median(dat$year_center, na.rm = TRUE),
            s = 10
          ),
          lower = c(K = 0.02, t0 = -60, s = 0.5),
          upper = c(K = 0.99, t0 = 60, s = 50),
          control = nls.lm.control(maxiter = 400)
        ),
        error = function(e) NULL
      )
      if (is.null(fit)) {
        return(tibble(K_hat = NA_real_, t0_hat = NA_real_, s_hat = NA_real_))
      }
      co <- coef(fit)
      tibble(K_hat = unname(co[["K"]]), t0_hat = unname(co[["t0"]]), s_hat = unname(co[["s"]]))
    }) %>%
    ungroup() %>%
    filter(is.finite(K_hat), K_hat > 0, K_hat < 1)

  wb_region_prior_spec <- wb_country_mle %>%
    group_by(wb_region) %>%
    summarise(
      median_K = median(K_hat, na.rm = TRUE),
      p25_K = quantile(K_hat, 0.25, na.rm = TRUE),
      p75_K = quantile(K_hat, 0.75, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    left_join(region_label_lookup %>% rename(wb_region = region), by = "wb_region") %>%
    right_join(tibble(region_prior = region_prior_levels), by = "region_prior") %>%
    mutate(
      prior_center_K = if_else(is.na(median_K), 0.45, pmin(pmax(median_K, 0.01), 0.99)),
      p25_K = if_else(is.na(p25_K), pmax(0.05, prior_center_K - 0.10), p25_K),
      p75_K = if_else(is.na(p75_K), pmin(0.95, prior_center_K + 0.10), p75_K),
      q25_logitK = qlogis(pmin(pmax(p25_K, 0.01), 0.99)),
      q75_logitK = qlogis(pmin(pmax(p75_K, 0.01), 0.99)),
      prior_sd_logitK = pmax(0.30, pmin(1.10, (q75_logitK - q25_logitK) / 1.349)),
      prior_mean_logitK = qlogis(prior_center_K)
    ) %>%
    arrange(region_prior)

  wb_region_s_prior_spec <- wb_country_mle %>%
    filter(is.finite(s_hat), s_hat > 0.5) %>%
    left_join(region_label_lookup %>% rename(wb_region = region), by = "wb_region") %>%
    filter(!is.na(region_prior)) %>%
    group_by(region_prior) %>%
    summarise(
      s_region_median = median(s_hat, na.rm = TRUE),
      s_region_p25 = quantile(s_hat, 0.25, na.rm = TRUE),
      s_region_p75 = quantile(s_hat, 0.75, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    right_join(tibble(region_prior = region_prior_levels), by = "region_prior") %>%
    mutate(
      s_region_median = if_else(is.na(s_region_median), 8, s_region_median),
      s_region_p25 = if_else(is.na(s_region_p25), s_region_median / exp(0.5), s_region_p25),
      s_region_p75 = if_else(is.na(s_region_p75), s_region_median * exp(0.5), s_region_p75),
      prior_mean_logs = log(pmax(s_region_median, 0.5)),
      prior_sd_logs = pmax(0.20, pmin(0.90, (log(pmax(s_region_p75, 0.5)) - log(pmax(s_region_p25, 0.5))) / 1.349))
    ) %>%
    arrange(region_prior)

  wb_region_t0_prior_spec <- wb_country_mle %>%
    filter(is.finite(t0_hat), t0_hat >= -60, t0_hat <= 60) %>%
    left_join(region_label_lookup %>% rename(wb_region = region), by = "wb_region") %>%
    filter(!is.na(region_prior)) %>%
    group_by(region_prior) %>%
    summarise(
      t0_region_median = median(t0_hat, na.rm = TRUE),
      t0_region_p25 = quantile(t0_hat, 0.25, na.rm = TRUE),
      t0_region_p75 = quantile(t0_hat, 0.75, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    right_join(tibble(region_prior = region_prior_levels), by = "region_prior") %>%
    mutate(
      t0_region_median = if_else(is.na(t0_region_median), -2.5, t0_region_median),
      t0_region_p25 = if_else(is.na(t0_region_p25), t0_region_median - 4, t0_region_p25),
      t0_region_p75 = if_else(is.na(t0_region_p75), t0_region_median + 4, t0_region_p75),
      prior_mean_t0 = pmax(-40, pmin(40, t0_region_median)),
      prior_sd_t0 = pmax(2.0, pmin(10.0, (t0_region_p75 - t0_region_p25) / 1.349))
    ) %>%
    arrange(region_prior)

  list(
    obs_data = obs_data,
    wb_region_prior_spec = wb_region_prior_spec,
    wb_region_s_prior_spec = wb_region_s_prior_spec,
    wb_region_t0_prior_spec = wb_region_t0_prior_spec,
    region_label_lookup = region_label_lookup,
    region_lookup = region_lookup
  )
}

build_fpet_configs <- function(mode = c("smoke", "full"), config_filter = NA_character_) {
  mode <- match.arg(mode)
  all_configs <- list(
    list(
      name = "joint_region_shrink_no_ts",
      prior_sd_mult_logitK = 0.85,
      prior_sd_mult_logs = 0.85,
      prior_sd_mult_t0 = 0.90,
      sigma_logitK_country_scale = 0.30,
      sigma_logs_country_scale = 0.28,
      sigma_t0_country_scale = 4.5,
      sigma_delta_scale = 0.005,
      sigma_delta0_scale = 0.005,
      phi_alpha = 2,
      phi_beta = 8,
      adapt_delta = 0.96,
      max_treedepth = 12
    ),
    list(
      name = "joint_region_shrink_ar1",
      prior_sd_mult_logitK = 0.85,
      prior_sd_mult_logs = 0.85,
      prior_sd_mult_t0 = 0.90,
      sigma_logitK_country_scale = 0.30,
      sigma_logs_country_scale = 0.28,
      sigma_t0_country_scale = 4.5,
      sigma_delta_scale = 0.08,
      sigma_delta0_scale = 0.10,
      phi_alpha = 7,
      phi_beta = 2,
      adapt_delta = 0.98,
      max_treedepth = 13
    ),
    list(
      name = "joint_region_shrink_ar1_strong_anchor",
      prior_sd_mult_logitK = 0.55,
      prior_sd_mult_logs = 0.55,
      prior_sd_mult_t0 = 0.65,
      sigma_logitK_country_scale = 0.20,
      sigma_logs_country_scale = 0.20,
      sigma_t0_country_scale = 3.2,
      sigma_delta_scale = 0.05,
      sigma_delta0_scale = 0.08,
      phi_alpha = 7,
      phi_beta = 2,
      adapt_delta = 0.99,
      max_treedepth = 14
    ),
    list(
      name = "joint_histflex_low_persist",
      prior_sd_mult_logitK = 0.55,
      prior_sd_mult_logs = 0.55,
      prior_sd_mult_t0 = 0.65,
      sigma_logitK_country_scale = 0.20,
      sigma_logs_country_scale = 0.20,
      sigma_t0_country_scale = 3.2,
      sigma_delta_scale = 0.10,
      sigma_delta0_scale = 0.12,
      phi_alpha = 4,
      phi_beta = 3,
      adapt_delta = 0.99,
      max_treedepth = 14
    ),
    list(
      name = "joint_region_shrink_ar1_ultra_anchor",
      prior_sd_mult_logitK = 0.35,
      prior_sd_mult_logs = 0.40,
      prior_sd_mult_t0 = 0.50,
      sigma_logitK_country_scale = 0.12,
      sigma_logs_country_scale = 0.15,
      sigma_t0_country_scale = 2.5,
      sigma_delta_scale = 0.03,
      sigma_delta0_scale = 0.05,
      phi_alpha = 7,
      phi_beta = 2,
      adapt_delta = 0.995,
      max_treedepth = 14
    )
  )

  configs <- if (mode == "smoke") all_configs[1:2] else all_configs

  if (!is.na(config_filter) && nzchar(config_filter)) {
    keep_names <- trimws(strsplit(config_filter, ",", fixed = TRUE)[[1]])
    configs <- Filter(function(x) x$name %in% keep_names, configs)
    if (length(configs) == 0) stop("No configs matched --config=", config_filter)
  }

  configs
}

build_fpet_stan_inputs <- function(data_objs, config, year_end = 60L) {
  obs_data <- data_objs$obs_data
  year_end <- max(as.integer(year_end), max(obs_data$year - 2000))

  year_tbl <- tibble(year_center = seq.int(min(obs_data$year - 2000), year_end, by = 1L)) %>%
    mutate(year = year_center + 2000L, year_idx = row_number())

  region_tbl <- obs_data %>%
    distinct(region_prior, region) %>%
    arrange(region_prior) %>%
    mutate(region_idx = row_number())

  country_tbl <- obs_data %>%
    distinct(country, region_prior, region, n_surveys) %>%
    left_join(region_tbl, by = c("region_prior", "region")) %>%
    arrange(region_idx, country) %>%
    mutate(country_idx = row_number())

  obs_indexed <- obs_data %>%
    mutate(year_center = year - 2000) %>%
    left_join(country_tbl %>% select(country, country_idx), by = "country") %>%
    left_join(year_tbl %>% select(year, year_idx), by = "year") %>%
    arrange(country_idx, year_idx)

  prior_tbl <- region_tbl %>%
    left_join(data_objs$wb_region_prior_spec %>% select(region_prior, prior_mean_logitK, prior_sd_logitK), by = "region_prior") %>%
    left_join(data_objs$wb_region_s_prior_spec %>% select(region_prior, prior_mean_logs, prior_sd_logs), by = "region_prior") %>%
    left_join(data_objs$wb_region_t0_prior_spec %>% select(region_prior, prior_mean_t0, prior_sd_t0), by = "region_prior")

  stan_data <- list(
    N = nrow(obs_indexed),
    C = nrow(country_tbl),
    R = nrow(region_tbl),
    T = nrow(year_tbl),
    country_idx = obs_indexed$country_idx,
    year_idx = obs_indexed$year_idx,
    y = obs_indexed$y,
    n_trials = obs_indexed$n,
    region_of_country = country_tbl$region_idx,
    year_center = year_tbl$year_center,
    prior_mean_logitK = prior_tbl$prior_mean_logitK,
    prior_sd_logitK = prior_tbl$prior_sd_logitK,
    prior_mean_logs = prior_tbl$prior_mean_logs,
    prior_sd_logs = prior_tbl$prior_sd_logs,
    prior_mean_t0 = prior_tbl$prior_mean_t0,
    prior_sd_t0 = prior_tbl$prior_sd_t0,
    prior_sd_mult_logitK = config$prior_sd_mult_logitK,
    prior_sd_mult_logs = config$prior_sd_mult_logs,
    prior_sd_mult_t0 = config$prior_sd_mult_t0,
    sigma_logitK_country_scale = config$sigma_logitK_country_scale,
    sigma_logs_country_scale = config$sigma_logs_country_scale,
    sigma_t0_country_scale = config$sigma_t0_country_scale,
    sigma_delta_scale = config$sigma_delta_scale,
    sigma_delta0_scale = config$sigma_delta0_scale,
    phi_alpha = config$phi_alpha,
    phi_beta = config$phi_beta
  )

  list(stan_data = stan_data, obs_indexed = obs_indexed, country_tbl = country_tbl, region_tbl = region_tbl, year_tbl = year_tbl)
}

load_fpet_stan_model <- function(root_dir) {
  results_dir <- file.path(root_dir, "joint_ks_fpet_style")
  dir.create(results_dir, showWarnings = FALSE)
  compiled_model_path <- file.path(results_dir, "fpet_style_joint_ks_ar1_stanmodel.rds")
  stan_file <- file.path(root_dir, "scripts", "stan", "fpet_style_joint_ks_ar1.stan")
  if (file.exists(compiled_model_path)) {
    readRDS(compiled_model_path)
  } else {
    sm <- stan_model(file = stan_file, save_dso = TRUE)
    saveRDS(sm, compiled_model_path)
    sm
  }
}

make_fpet_fit <- function(stanfit, meta, config_name, scope, year_end, root_dir = NULL, mode = "full") {
  structure(
    list(
      stanfit = stanfit,
      meta = meta,
      config_name = config_name,
      scope = scope,
      year_end = year_end,
      root_dir = root_dir,
      mode = mode
    ),
    class = "fpet_fit"
  )
}

print.fpet_fit <- function(x, ...) {
  cat("FPET-style fit:", x$config_name, "| scope:", x$scope, "\n")
  print(summary(x$stanfit, ...))
}

plot.fpet_fit <- function(x, ...) {
  sampler_tbls <- rstan::get_sampler_params(x$stanfit, inc_warmup = FALSE)
  td_vals <- unlist(lapply(sampler_tbls, function(tbl) tbl[, "treedepth__"]))
  div_vals <- unlist(lapply(sampler_tbls, function(tbl) tbl[, "divergent__"]))
  energy_vals <- unlist(lapply(sampler_tbls, function(tbl) tbl[, "energy__"]))

  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par), add = TRUE)
  par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))

  hist(energy_vals, breaks = 30, main = "Hamiltonian energy", xlab = "energy__", col = "grey80", border = "white")
  hist(td_vals, breaks = max(10, length(unique(td_vals))), main = "Tree depth", xlab = "treedepth__", col = "grey80", border = "white")
  plot(div_vals, pch = 16, cex = 0.45, main = "Divergences by draw", xlab = "Draw", ylab = "divergent__", col = ifelse(div_vals > 0, "#C0392B", "#4C78A8"))
  boxplot(energy_vals, horizontal = TRUE, main = "energy__ spread", col = "#A6CEE3")
  invisible(x)
}

summary.fpet_fit <- function(object, ...) summary(object$stanfit, ...)

get_fpet_draws <- function(object) {
  if (!is.null(object$draw_cache)) return(object$draw_cache)
  rstan::extract(object$stanfit, pars = c("K_country", "s_country", "t0_country", "delta", "p_obs"), permuted = TRUE, inc_warmup = FALSE)
}

clamp_fpet_years <- function(object, year_value) {
  year_tbl <- object$meta$year_tbl
  pmin(pmax(as.integer(year_value), min(year_tbl$year)), max(year_tbl$year))
}

fpet_prob_draws_at_year <- function(object, year_value, countries = NULL) {
  meta <- object$meta
  draws <- get_fpet_draws(object)
  year_idx <- match(clamp_fpet_years(object, year_value), meta$year_tbl$year)

  if (is.null(countries)) {
    country_idx <- seq_len(nrow(meta$country_tbl))
    country_names <- meta$country_tbl$country
  } else {
    country_idx <- match(countries, meta$country_tbl$country)
    if (any(is.na(country_idx))) stop("Some requested countries are missing from the FPET fit.")
    country_names <- countries
  }

  out <- vapply(
    seq_along(country_idx),
    function(j) {
      c_idx <- country_idx[j]
      eta <- (meta$year_tbl$year_center[year_idx] - draws$t0_country[, c_idx]) / draws$s_country[, c_idx] +
        draws$delta[, c_idx, year_idx]
      draws$K_country[, c_idx] * inv_logit(eta)
    },
    numeric(nrow(draws$K_country))
  )

  if (is.null(dim(out))) out <- matrix(out, ncol = 1)
  colnames(out) <- country_names
  out
}

fpet_dpdt_draws_at_year <- function(object, year_value, countries = NULL) {
  meta <- object$meta
  draws <- get_fpet_draws(object)
  year_idx <- match(clamp_fpet_years(object, year_value), meta$year_tbl$year)

  if (is.null(countries)) {
    country_idx <- seq_len(nrow(meta$country_tbl))
    country_names <- meta$country_tbl$country
  } else {
    country_idx <- match(countries, meta$country_tbl$country)
    if (any(is.na(country_idx))) stop("Some requested countries are missing from the FPET fit.")
    country_names <- countries
  }

  out <- vapply(
    seq_along(country_idx),
    function(j) {
      c_idx <- country_idx[j]
      z <- (meta$year_tbl$year_center[year_idx] - draws$t0_country[, c_idx]) / draws$s_country[, c_idx] +
        draws$delta[, c_idx, year_idx]
      g <- inv_logit(z)
      draws$K_country[, c_idx] * g * (1 - g) / draws$s_country[, c_idx]
    },
    numeric(nrow(draws$K_country))
  )

  if (is.null(dim(out))) out <- matrix(out, ncol = 1)
  colnames(out) <- country_names
  out
}

fpet_d2pdt2_draws_at_year <- function(object, year_value, countries = NULL) {
  meta <- object$meta
  draws <- get_fpet_draws(object)
  year_idx <- match(clamp_fpet_years(object, year_value), meta$year_tbl$year)

  if (is.null(countries)) {
    country_idx <- seq_len(nrow(meta$country_tbl))
    country_names <- meta$country_tbl$country
  } else {
    country_idx <- match(countries, meta$country_tbl$country)
    if (any(is.na(country_idx))) stop("Some requested countries are missing from the FPET fit.")
    country_names <- countries
  }

  out <- vapply(
    seq_along(country_idx),
    function(j) {
      c_idx <- country_idx[j]
      z <- (meta$year_tbl$year_center[year_idx] - draws$t0_country[, c_idx]) / draws$s_country[, c_idx] +
        draws$delta[, c_idx, year_idx]
      g <- inv_logit(z)
      draws$K_country[, c_idx] * g * (1 - g) * (1 - 2 * g) / (draws$s_country[, c_idx]^2)
    },
    numeric(nrow(draws$K_country))
  )

  if (is.null(dim(out))) out <- matrix(out, ncol = 1)
  colnames(out) <- country_names
  out
}

fpet_predict_prob_draws <- function(object, newdata) {
  req_cols <- c("country", "year")
  if (!all(req_cols %in% names(newdata))) stop("newdata must contain country and year for fpet predictions.")

  meta <- object$meta
  country_tbl <- meta$country_tbl
  year_tbl <- meta$year_tbl
  draws <- get_fpet_draws(object)

  country_idx <- match(newdata$country, country_tbl$country)
  year_idx <- match(clamp_fpet_years(object, newdata$year), year_tbl$year)

  if (any(is.na(country_idx))) stop("Some countries in newdata are missing from the FPET fit.")

  n_draws <- nrow(draws$K_country)
  out <- matrix(NA_real_, nrow = n_draws, ncol = nrow(newdata))

  for (j in seq_len(nrow(newdata))) {
    c_idx <- country_idx[j]
    t_idx <- year_idx[j]
    eta <- (year_tbl$year_center[t_idx] - draws$t0_country[, c_idx]) / draws$s_country[, c_idx] + draws$delta[, c_idx, t_idx]
    out[, j] <- draws$K_country[, c_idx] * inv_logit(eta)
  }

  out
}

posterior_epred <- function(object, ...) UseMethod("posterior_epred")
posterior_linpred <- function(object, ...) UseMethod("posterior_linpred")
posterior_predict <- function(object, ...) UseMethod("posterior_predict")
nuts_params <- function(object, ...) UseMethod("nuts_params")

posterior_epred.default <- function(object, ...) brms::posterior_epred(object, ...)
posterior_linpred.default <- function(object, ...) brms::posterior_linpred(object, ...)
posterior_predict.default <- function(object, ...) brms::posterior_predict(object, ...)
nuts_params.default <- function(object, ...) brms::nuts_params(object, ...)

posterior_epred.fpet_fit <- function(object, newdata = NULL, re_formula = NULL, ...) {
  if (is.null(newdata)) {
    newdata <- object$meta$obs_indexed
  }
  p <- fpet_predict_prob_draws(object, newdata)
  n_vec <- if ("n" %in% names(newdata)) newdata$n else rep(1L, nrow(newdata))
  sweep(p, 2, n_vec, FUN = "*")
}

posterior_predict.fpet_fit <- function(object, newdata = NULL, re_formula = NULL, ...) {
  if (is.null(newdata)) newdata <- object$meta$obs_indexed
  ep <- posterior_epred.fpet_fit(object, newdata = newdata)
  n_draws <- nrow(ep)
  out <- matrix(NA_real_, nrow = n_draws, ncol = ncol(ep))
  for (j in seq_len(ncol(ep))) {
    size_j <- if ("n" %in% names(newdata)) newdata$n[j] else 1L
    p_j <- pmin(pmax(ep[, j] / size_j, 1e-8), 1 - 1e-8)
    out[, j] <- rbinom(n_draws, size = size_j, prob = p_j)
  }
  out
}

posterior_linpred.fpet_fit <- function(object, nlpar = NULL, newdata = NULL, re_formula = NULL, transform = FALSE, summary = FALSE, ...) {
  if (is.null(newdata)) {
    newdata <- object$meta$country_tbl %>% mutate(year = 2000, n = 1)
  }
  req_country <- match(newdata$country, object$meta$country_tbl$country)
  if (any(is.na(req_country))) stop("Some countries in newdata are missing from the FPET fit.")

  draws <- get_fpet_draws(object)
  t0_lower <- 1966 - 2000
  t0_upper <- 2035 - 2000
  t0_span <- t0_upper - t0_lower

  if (is.null(nlpar)) stop("nlpar must be supplied for fpet posterior_linpred.")

  out <- switch(
    nlpar,
    Kraw = qlogis(draws$K_country[, req_country, drop = FALSE]),
    logs = log(draws$s_country[, req_country, drop = FALSE]),
    t0raw = qlogis(pmin(pmax((draws$t0_country[, req_country, drop = FALSE] - t0_lower) / t0_span, 1e-6), 1 - 1e-6)),
    stop("Unsupported nlpar for fpet_fit: ", nlpar)
  )

  if (transform) out <- inv_logit(out)
  out
}

nuts_params.fpet_fit <- function(object, ...) {
  sampler_tbls <- rstan::get_sampler_params(object$stanfit, inc_warmup = FALSE)
  bind_rows(lapply(seq_along(sampler_tbls), function(i) {
    as_tibble(sampler_tbls[[i]]) %>%
      mutate(.iteration = row_number(), Chain = i) %>%
      pivot_longer(cols = -c(.iteration, Chain), names_to = "Parameter", values_to = "Value")
  }))
}

as_draws_df.fpet_fit <- function(x, ...) {
  posterior::as_draws_df(as.array(x$stanfit))
}

update.fpet_fit <- function(object, newdata = NULL, seed = 20260327L, ..., file = NULL,
                            iter = NULL, warmup = NULL, chains = 2L, cores = 2L) {
  root_dir <- object$root_dir
  if (is.null(root_dir) || !nzchar(root_dir)) {
    root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
  }

  cache_prefix <- NULL
  if (!is.null(file) && nzchar(file)) {
    cache_prefix <- tools::file_path_sans_ext(basename(file))
  }

  fit_fpet_model(
    root_dir = root_dir,
    obs_data = newdata,
    scope = object$scope,
    mode = if (is.null(object$mode)) "full" else object$mode,
    config_name = object$config_name,
    year_end = object$year_end,
    chains = as.integer(chains),
    iter = if (is.null(iter)) 700L else as.integer(iter),
    warmup = if (is.null(warmup)) 350L else as.integer(warmup),
    cores = as.integer(cores),
    seed = seed,
    cache_prefix = cache_prefix
  )
}

evaluate_fpet_fit <- function(object, model_name = object$config_name) {
  draws <- get_fpet_draws(object)
  obs_tbl <- object$meta$obs_indexed
  country_tbl <- object$meta$country_tbl
  year_tbl <- object$meta$year_tbl

  p_obs_draws <- draws$p_obs
  pred_mean <- colMeans(p_obs_draws)
  pred_p05 <- calc_qcol(p_obs_draws, 0.05)
  pred_p95 <- calc_qcol(p_obs_draws, 0.95)

  obs_eval <- obs_tbl %>%
    transmute(
      model = model_name,
      row_id,
      country,
      region,
      year,
      actual_mcpr = mCPR,
      pred_mean = pred_mean,
      pred_p05 = pred_p05,
      pred_p95 = pred_p95,
      error = pred_mean - actual_mcpr,
      abs_error = abs(error),
      covered = actual_mcpr >= pred_p05 & actual_mcpr <= pred_p95
    )

  latest_eval <- obs_eval %>%
    group_by(country) %>%
    slice_max(year, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    rename(
      last_obs_year = year,
      last_obs_mcpr = actual_mcpr,
      p_last_observed_year_model = pred_mean,
      p_last_observed_year_model_p05 = pred_p05,
      p_last_observed_year_model_p95 = pred_p95
    ) %>%
    mutate(
      last_obs_error = p_last_observed_year_model - last_obs_mcpr,
      last_obs_abs_error = abs(last_obs_error),
      last_obs_covered = last_obs_mcpr >= p_last_observed_year_model_p05 & last_obs_mcpr <= p_last_observed_year_model_p95
    )

  year_2025_idx <- year_tbl$year_idx[match(2025L, year_tbl$year)]
  p2025_draws <- sapply(seq_len(nrow(country_tbl)), function(j) {
    draws$K_country[, j] * inv_logit((25 - draws$t0_country[, j]) / draws$s_country[, j] + draws$delta[, j, year_2025_idx])
  })

  ks_corr <- vapply(
    seq_len(nrow(country_tbl)),
    function(j) {
      if (sd(draws$K_country[, j]) == 0 || sd(draws$s_country[, j]) == 0) return(NA_real_)
      cor(draws$K_country[, j], draws$s_country[, j])
    },
    numeric(1)
  )

  country_summary <- country_tbl %>%
    transmute(country, region, n_surveys) %>%
    mutate(
      model = model_name,
      K_mean = colMeans(draws$K_country),
      K_p05 = calc_qcol(draws$K_country, 0.05),
      K_p95 = calc_qcol(draws$K_country, 0.95),
      s_mean = colMeans(draws$s_country),
      s_p05 = calc_qcol(draws$s_country, 0.05),
      s_p95 = calc_qcol(draws$s_country, 0.95),
      t0_mean = colMeans(draws$t0_country) + 2000,
      t0_p05 = calc_qcol(draws$t0_country, 0.05) + 2000,
      t0_p95 = calc_qcol(draws$t0_country, 0.95) + 2000,
      p2025_mean = colMeans(p2025_draws),
      p2025_p05 = calc_qcol(p2025_draws, 0.05),
      p2025_p95 = calc_qcol(p2025_draws, 0.95),
      ks_corr = ks_corr,
      abs_ks_corr = abs(ks_corr),
      K_width95 = K_p95 - K_p05,
      s_width95 = s_p95 - s_p05
    ) %>%
    left_join(
      latest_eval %>%
        select(
          country, last_obs_year, last_obs_mcpr,
          p_last_observed_year_model, p_last_observed_year_model_p05, p_last_observed_year_model_p95,
          last_obs_error, last_obs_abs_error, last_obs_covered
        ),
      by = "country"
    )

  overall <- tibble(
    model = model_name,
    obs_rmse = sqrt(mean(obs_eval$error^2, na.rm = TRUE)),
    obs_mae = mean(obs_eval$abs_error, na.rm = TRUE),
    obs_coverage_90 = mean(obs_eval$covered, na.rm = TRUE),
    latest_rmse = sqrt(mean(country_summary$last_obs_error^2, na.rm = TRUE)),
    latest_mae = mean(country_summary$last_obs_abs_error, na.rm = TRUE),
    latest_bias = mean(country_summary$last_obs_error, na.rm = TRUE),
    latest_coverage_90 = mean(country_summary$last_obs_covered, na.rm = TRUE),
    median_abs_ks_corr = median(country_summary$abs_ks_corr, na.rm = TRUE),
    max_abs_ks_corr = max(country_summary$abs_ks_corr, na.rm = TRUE),
    median_K_width95 = median(country_summary$K_width95, na.rm = TRUE),
    median_s_width95 = median(country_summary$s_width95, na.rm = TRUE)
  )

  list(overall = overall, obs_eval = obs_eval, latest_eval = latest_eval, country_summary = country_summary)
}

summarise_fpet_diagnostics <- function(object, td_max = 15) {
  sum_tbl <- summary(object$stanfit)$summary
  sampler_tbls <- rstan::get_sampler_params(object$stanfit, inc_warmup = FALSE)
  td_vals <- unlist(lapply(sampler_tbls, function(x) x[, "treedepth__"]))
  div_vals <- unlist(lapply(sampler_tbls, function(x) x[, "divergent__"]))
  tibble(
    n_rhat_gt_101 = sum(sum_tbl[, "Rhat"] > 1.01, na.rm = TRUE),
    n_rhat_gt_105 = sum(sum_tbl[, "Rhat"] > 1.05, na.rm = TRUE),
    max_rhat = max(sum_tbl[, "Rhat"], na.rm = TRUE),
    min_ess_bulk = min(sum_tbl[, "n_eff"], na.rm = TRUE),
    divergences = sum(div_vals > 0, na.rm = TRUE),
    max_treedepth = if (length(td_vals) == 0) NA_real_ else max(td_vals),
    n_treedepth_at_max = if (length(td_vals) == 0) NA_real_ else sum(td_vals >= td_max)
  )
}

fit_fpet_model <- function(root_dir,
                           obs_data = NULL,
                           scope = c("global", "ssa"),
                           mode = c("full", "smoke"),
                           config_name = "joint_region_shrink_ar1_strong_anchor",
                           year_end = 60L,
                           chains = 2L,
                           iter = 700L,
                           warmup = 350L,
                           cores = 2L,
                           seed = 20260327L,
                           cache_prefix = NULL,
                           force = FALSE) {
  scope <- match.arg(scope)
  mode <- match.arg(mode)
  results_dir <- file.path(root_dir, "joint_ks_fpet_style")
  fits_dir <- file.path(results_dir, "fits")
  dir.create(results_dir, showWarnings = FALSE)
  dir.create(fits_dir, showWarnings = FALSE)

  data_objs <- build_fpet_data_objects(root_dir, scope = scope, mode = mode)
  if (!is.null(obs_data)) {
    obs_data <- obs_data %>%
      arrange(region_prior, country, year) %>%
      group_by(country) %>%
      mutate(n_surveys = n()) %>%
      ungroup() %>%
      mutate(row_id = row_number())
    data_objs$obs_data <- obs_data
  }

  config <- build_fpet_configs("full", config_filter = config_name)[[1]]
  meta <- build_fpet_stan_inputs(data_objs, config, year_end = year_end)

  fit_key <- if (is.null(cache_prefix)) paste0(config_name, "_", scope, "_", mode) else cache_prefix
  fit_path <- file.path(fits_dir, paste0(fit_key, ".rds"))
  stan_model_obj <- load_fpet_stan_model(root_dir)

  if (!force && file.exists(fit_path)) {
      return(make_fpet_fit(
        readRDS(fit_path),
        meta,
        config_name = config_name,
        scope = scope,
        year_end = year_end,
        root_dir = root_dir,
        mode = mode
      ))
  }

  fit_obj <- sampling(
    object = stan_model_obj,
    data = meta$stan_data,
    chains = chains,
    iter = iter,
    warmup = warmup,
    cores = cores,
    seed = seed,
    control = list(adapt_delta = config$adapt_delta, max_treedepth = config$max_treedepth),
    refresh = 50
  )

  saveRDS(fit_obj, fit_path)
  make_fpet_fit(
    fit_obj,
    meta,
    config_name = config_name,
    scope = scope,
    year_end = year_end,
    root_dir = root_dir,
    mode = mode
  )
}
