source("scripts/fpet_model_helpers.R")
root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
data_objects <- build_fpet_data_objects(root_dir, scope = "global", mode = "full")
region_labels <- extract_assignment_from_rmd("dhs_analysis_production.Rmd", "region_label_lookup")
observations <- data_objects$obs_data %>%
  mutate(region_prior = factor(region_prior, levels = region_labels$region_prior)) %>%
  arrange(region_prior, country, year)
stopifnot(all(observations$n_surveys >= 2))
# Reproduce the two independent two-chain runs that form the saved production fit.
first <- fit_fpet_model(root_dir, obs_data = observations, scope = "global", mode = "full",
  config_name = "joint_histflex_low_persist", year_end = 60L,
  chains = 2L, iter = 1500L, warmup = 500L, cores = 2L, seed = 20260514L,
  cache_prefix = "production_high_ess_first_two_chains", force = TRUE)
second <- fit_fpet_model(root_dir, obs_data = observations, scope = "global", mode = "full",
  config_name = "joint_histflex_low_persist", year_end = 60L,
  chains = 2L, iter = 1500L, warmup = 500L, cores = 2L, seed = 20260517L,
  cache_prefix = "production_high_ess_second_two_chains", force = TRUE)
combined <- rstan::sflist2stanfit(list(first$stanfit, second$stanfit))
fit_path <- "joint_ks_fpet_style/fits/joint_histflex_low_persist_global_full_ge2_high_ess.rds"
saveRDS(combined, fit_path)
fit <- make_fpet_fit(combined, first$meta, "joint_histflex_low_persist", "global", 60L, root_dir)
print(summarise_fpet_diagnostics(fit, td_max = 14))
saveRDS(list(session = sessionInfo(), diagnostics = summarise_fpet_diagnostics(fit, td_max=14)),
        "refit_diagnostics_and_session.rds")
