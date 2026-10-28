# mcpr_trajectories

**Main report:** [production_report.html](production_report.html). Its full explanatory
R Markdown is [production_report.Rmd](production_report.Rmd). Download the HTML
to open it in a browser; GitHub's file viewer displays HTML source.

This is the later production-labeled canonical >=2-survey FPET-style model with
exogenous country K, region-informed priors, country-specific speed and timing,
and AR(1) deviations. It is our own fitted model, not official UN/Track20 FPET.
The full report includes model explanation, prior construction, diagnostics,
country/weighted regional results, goal figures and model-comparison evidence.

## Why this version

The saved final fit contains four chains and 4,000 retained draws. The recorded
K diagnostics improved from median ESS 487 in the original short fit to 3,258,
with minimum K ESS 1,156, maximum K Rhat 1.0024 and zero divergences. This reduces
Monte Carlo error; it does not automatically improve predictive performance or
make credible intervals narrower. The older presentation's Nigeria K=27.4%
is historical; the saved high-ESS fit gives Nigeria K approximately **28.0%**.
It is not forced to reproduce the older 27.4% value. Do not mix its tables
with this report. See [version details](docs/PROVENANCE.md).

## Rebuild from the saved production fit

Requirements: R, Pandoc (included in RStudio) and the R packages installed below.
Refitting additionally needs an RStan-compatible C++ compiler/toolchain. Package
dependencies are declared but not locked to the historical versions.

1. Extract the repo and open `mcpr_trajectories.Rproj`.
2. Run `Rscript install_packages.R`.
3. Extract `mcpr_trajectories_fit_cache.zip` into the repo, retaining
   `joint_ks_fpet_style/fits/` and its RDS file.
4. Run `Rscript run_pipeline.R` from the repo root.
5. Open `output/production_report.html`.

The frozen root HTML is preserved. The cached-render command checks the pinned
DHS, WB and WPP input hashes before reusing the fit; changed inputs require a refit. Each execution stages its sources and inputs
under `work/run_TIMESTAMP/`; CSV exports stay there as internal artifacts.
The fit cache is separate because its 484 MB RDS exceeds GitHub's normal file
limit. It belongs in local storage or a release asset, not a normal Git commit.

## DHS download -> data processing -> model -> full report

Configure your approved DHS account using `rdhs::set_rdhs_config()` outside the
repo; the commented setup in `get_dhs.Rmd` shows the fields. Then:

```sh
Rscript run_pipeline.R --from-dhs
```

This downloads DHS IR data, constructs age-15–49 weighted modern-use estimates
and design-based standard errors, stops on recorded extraction errors, fits the
>=2-survey global model, and renders the full production report. Downloads and
MCMC can take hours. Raw data and account configuration are excluded from Git.

To refit only the pinned aggregate inputs:

```sh
Rscript run_pipeline.R --refit
```

The refit script preserves the saved production recipe: two chains at seed
20260514 plus two at seed 20260517, 1,500 iterations and 500 warmup per chain,
then `rstan::sflist2stanfit`. Country and region factor ordering is explicit.
Inspect diagnostics after any new fit. Different software, data or random
sampling can change results; exact saved-posterior reporting uses the cache.

## Inputs and interpretation

- `mcpr_data.csv`: pinned DHS-derived national observations.
- `wb_surveys.xlsx`: pinned World Bank data for logistic prior calibration.
- `country_pop_weights_15_49.csv`: pinned WPP female ages 15–49 weights.
- `scripts/fpet_model_helpers.R` and `scripts/stan/`: model implementation.
- `dhs_analysis_production.Rmd`: historical report used only for geographic
  lookup definitions by the helper, not a second production-model choice.
- `holdout_model_comparison_30/`: archived model-comparison evidence. Refreshing
  DHS/refitting production does not rerun all comparator fits or their holdouts.
- `diagnostics/`: saved ESS/Rhat evidence for the production chain extensions.

The original extraction selects delivery formats and aggregates country/year
records; review duplicate formats and country-specific survey universes when
refreshing data. Filtering ages 15–49 does not recover women absent from an
ever-married-only survey. The likelihood uses rounded weighted modern-use counts
and weighted denominators; exported design SEs are not its likelihood. K is the
long-run ceiling, not prevalence in a particular target year. Smooth logistic
curves and AR-inclusive annual estimates must be distinguished.

The bundled WB calibration and WPP weights remain fixed on new DHS runs. To
rebuild WPP weights, obtain `WPP2024_POP_F01_3_POPULATION_SINGLE_AGE_FEMALE.xlsx`
separately, place it at the root, and run `Rscript scripts/build_country_pop_weights.R`.
That large workbook is not included. The full report skips unavailable holdout
caches and disables the optional fixed-speed refit appendix by default, as in
the saved high-ESS source. It reports archived model-selection evidence.

## Checks and GitHub upload

```sh
python scripts/validate_bundle.py
Rscript scripts/check_r_syntax.R
```

See [validation](docs/VALIDATION.md) and [source hashes](docs/SOURCE_MANIFEST.json).
Upload this folder's contents or push its local Git repository to a new GitHub
repo. Do not upload the fit-cache ZIP as a source file. No remote is configured
and nothing is published. No open-source license has been assumed; choose one
before granting redistribution rights. Source-data terms continue to apply.
