# Validation

The saved production fit was audited directly: 4,000 retained draws, 63 countries,
minimum K ESS 1156.3, median K ESS 3258.2, maximum K Rhat 1.00243, zero divergences.
Nigeria K from the saved posterior is 27.98189%.

The full explanatory production report rebuilt from the packaged sources,
pinned inputs and saved high-ESS fit using R 4.1.3 and RStudio Pandoc. All **49
table contents** matched the historical high-ESS HTML exactly. Source hashes,
63-country inclusion, portable paths and fit-archive integrity passed checks.
All 10 R scripts/Rmd sources passed syntax checks. The launcher checks pinned
input hashes before reusing the cache. Tested package versions are recorded in
TESTED_R_PACKAGES.csv; these are environment evidence, not a lockfile.

The report retains its original skipped holdout-cache behavior and disabled
fixed-speed-refit appendix. Historical comparator holdout tables are bundled;
they were not refitted. Some existing plotting warnings concern one-point line
groups. No new DHS download or MCMC fit was run. Clean dependency installation
on another computer has not been tested.

The stable launcher completed successfully with exit code 0. After the repo
was renamed to `mcpr_trajectories`, its project-file check was updated and all R
sources were syntax-checked again. The report and numerical inputs are unchanged.
