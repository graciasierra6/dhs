source("scripts/fpet_model_helpers.R")
fit_path <- "joint_ks_fpet_style/fits/joint_histflex_low_persist_global_full_ge2_high_ess.rds"
stanfit <- readRDS(fit_path)
data_objects <- build_fpet_data_objects(getwd(), scope="global",mode="full")
labels <- extract_assignment_from_rmd("dhs_analysis_production.Rmd","region_label_lookup")
data_objects$obs_data <- data_objects$obs_data %>%
  mutate(region_prior=factor(region_prior,levels=labels$region_prior)) %>%
  arrange(region_prior,country,year)
config <- build_fpet_configs("full",config_filter="joint_histflex_low_persist")[[1]]
meta <- build_fpet_stan_inputs(data_objects,config,year_end=60L)
draws <- rstan::extract(stanfit,pars="K_country",permuted=TRUE)$K_country
stopifnot(nrow(draws)==4000L,ncol(draws)==63L,nrow(meta$country_tbl)==63L)
s <- summary(stanfit,pars="K_country")$summary
sp <- rstan::get_sampler_params(stanfit,inc_warmup=FALSE)
diagnostics <- data.frame(retained_draws=nrow(draws),countries=ncol(draws),
  min_K_ESS=min(s[,"n_eff"]),median_K_ESS=median(s[,"n_eff"]),
  max_K_Rhat=max(s[,"Rhat"]),
  divergences=sum(vapply(sp,function(x)sum(x[,"divergent__"]),numeric(1))))
stopifnot(diagnostics$min_K_ESS>1000,diagnostics$max_K_Rhat<1.01,diagnostics$divergences==0)
print(diagnostics)
country_results <- data.frame(country=meta$country_tbl$country,K_percent=100*colMeans(draws))
print(country_results[country_results$country=="Nigeria",])
write.csv(diagnostics,"diagnostics/saved_fit_verified.csv",row.names=FALSE)
write.csv(country_results,"diagnostics/saved_fit_K_country_summary.csv",row.names=FALSE)
