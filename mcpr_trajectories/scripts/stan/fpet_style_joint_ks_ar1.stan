data {
  int<lower=1> N;
  int<lower=1> C;
  int<lower=1> R;
  int<lower=1> T;
  int<lower=1, upper=C> country_idx[N];
  int<lower=1, upper=T> year_idx[N];
  int<lower=0> y[N];
  int<lower=1> n_trials[N];
  int<lower=1, upper=R> region_of_country[C];
  vector[T] year_center;

  vector[R] prior_mean_logitK;
  vector<lower=0>[R] prior_sd_logitK;
  vector[R] prior_mean_logs;
  vector<lower=0>[R] prior_sd_logs;
  vector[R] prior_mean_t0;
  vector<lower=0>[R] prior_sd_t0;

  real<lower=0> prior_sd_mult_logitK;
  real<lower=0> prior_sd_mult_logs;
  real<lower=0> prior_sd_mult_t0;

  real<lower=0> sigma_logitK_country_scale;
  real<lower=0> sigma_logs_country_scale;
  real<lower=0> sigma_t0_country_scale;

  real<lower=0> sigma_delta_scale;
  real<lower=0> sigma_delta0_scale;
  real<lower=0> phi_alpha;
  real<lower=0> phi_beta;
}

parameters {
  vector[R] mu_logitK_region;
  vector[R] mu_logs_region;
  vector[R] mu_t0_region;

  real<lower=0> sigma_logitK_country;
  real<lower=0> sigma_logs_country;
  real<lower=0> sigma_t0_country;

  vector[C] z_logitK_country;
  vector[C] z_logs_country;
  vector[C] z_t0_country;

  real<lower=0, upper=0.995> phi;
  real<lower=0> sigma_delta;
  real<lower=0> sigma_delta0;
  matrix[C, T] z_delta;
}

transformed parameters {
  vector[C] logitK_country;
  vector[C] logs_country;
  vector[C] t0_country;
  vector[C] K_country;
  vector[C] s_country;
  matrix[C, T] delta;

  for (c in 1:C) {
    int r = region_of_country[c];
    logitK_country[c] = mu_logitK_region[r] + sigma_logitK_country * z_logitK_country[c];
    logs_country[c] = mu_logs_region[r] + sigma_logs_country * z_logs_country[c];
    t0_country[c] = mu_t0_region[r] + sigma_t0_country * z_t0_country[c];
    K_country[c] = inv_logit(logitK_country[c]);
    s_country[c] = exp(logs_country[c]);

    delta[c, 1] = sigma_delta0 * z_delta[c, 1];
    for (t in 2:T) {
      delta[c, t] = phi * delta[c, t - 1] + sigma_delta * z_delta[c, t];
    }
  }
}

model {
  mu_logitK_region ~ normal(prior_mean_logitK, prior_sd_logitK * prior_sd_mult_logitK);
  mu_logs_region ~ normal(prior_mean_logs, prior_sd_logs * prior_sd_mult_logs);
  mu_t0_region ~ normal(prior_mean_t0, prior_sd_t0 * prior_sd_mult_t0);

  sigma_logitK_country ~ normal(0, sigma_logitK_country_scale);
  sigma_logs_country ~ normal(0, sigma_logs_country_scale);
  sigma_t0_country ~ normal(0, sigma_t0_country_scale);

  z_logitK_country ~ std_normal();
  z_logs_country ~ std_normal();
  z_t0_country ~ std_normal();

  phi ~ beta(phi_alpha, phi_beta);
  sigma_delta ~ normal(0, sigma_delta_scale);
  sigma_delta0 ~ normal(0, sigma_delta0_scale);
  to_vector(z_delta) ~ std_normal();

  for (n in 1:N) {
    int c = country_idx[n];
    int t = year_idx[n];
    real eta = (year_center[t] - t0_country[c]) / s_country[c] + delta[c, t];
    real p = K_country[c] * inv_logit(eta);
    y[n] ~ binomial(n_trials[n], p);
  }
}

generated quantities {
  vector[N] p_obs;
  vector[N] log_lik;

  for (n in 1:N) {
    int c = country_idx[n];
    int t = year_idx[n];
    real eta = (year_center[t] - t0_country[c]) / s_country[c] + delta[c, t];
    real p = K_country[c] * inv_logit(eta);
    p_obs[n] = p;
    log_lik[n] = binomial_lpmf(y[n] | n_trials[n], p);
  }
}
