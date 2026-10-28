# Rscript run_pipeline.R [--refit | --from-dhs]
args <- commandArgs(trailingOnly = TRUE)
if (any(!args %in% c("--refit", "--from-dhs"))) stop("Unknown argument")
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!file.exists("mcpr_trajectories.Rproj")) stop("Run from the repository root")
fit_rel <- "joint_ks_fpet_style/fits/joint_histflex_low_persist_global_full_ge2_high_ess.rds"
refit <- any(args %in% c("--refit", "--from-dhs"))
if (!refit) {
  pinned <- read.csv("docs/PINNED_INPUT_MD5.csv", stringsAsFactors=FALSE)
  if (any(unname(tools::md5sum(pinned$path)) != pinned$md5))
    stop("Pinned inputs changed. Use --refit rather than reusing the saved production cache.")
}
if (!refit && !file.exists(fit_rel)) stop("Extract the companion production fit-cache ZIP into this repository, or use --refit")
runtime <- file.path(root, "work", paste0("run_", format(Sys.time(), "%Y%m%d_%H%M%S")))
dir.create(runtime, recursive = TRUE)
for (name in c("scripts", "holdout_model_comparison_30", "production_report.Rmd", "get_dhs.Rmd",
               "dhs_analysis_production.Rmd", "mcpr_data.csv", "wb_surveys.xlsx", "country_pop_weights_15_49.csv")) {
  if (!file.copy(file.path(root,name), runtime, recursive=TRUE)) stop("Copy failed: ",name)
}
if (!refit) {
  dir.create(file.path(runtime,dirname(fit_rel)),recursive=TRUE)
  if (!file.copy(file.path(root,fit_rel),file.path(runtime,fit_rel))) stop("Fit copy failed")
}
setwd(runtime)
if ("--from-dhs" %in% args) {
  extracted <- tempfile(fileext=".R")
  knitr::purl("get_dhs.Rmd",output=extracted,documentation=0,quiet=TRUE)
  sys.source(extracted,envir=globalenv())
  unlink(extracted)
  if (nrow(mCPR_errors)) stop("DHS extraction errors: inspect mcpr_data_extraction_errors.csv in ",runtime)
}
if (refit) source("scripts/fit_production_model.R")
output <- file.path(root,"output")
dir.create(output,showWarnings=FALSE)
rmarkdown::render("production_report.Rmd",output_dir=output,knit_root_dir=runtime,
  envir=new.env(parent=globalenv()),encoding="UTF-8")
message("Full report: ",file.path(output,"production_report.html"))
message("Internal outputs and the exact render sources: ",runtime)
