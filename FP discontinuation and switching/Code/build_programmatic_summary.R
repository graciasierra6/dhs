# Build a concise, self-contained summary of completed analyses and extensions.

project_dir <- getOption("ethiopia_discontinuation_project_dir")
if (is.null(project_dir)) {
  stop("Set ethiopia_discontinuation_project_dir before running this script.")
}

derived_dir <- file.path(project_dir, "Analyses", "derived")
output_dir <- file.path(project_dir, "output")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

read_result <- function(name) {
  path <- file.path(derived_dir, name)
  if (!file.exists(path)) stop("Missing required result: ", path)
  read.csv(path, check.names = FALSE)
}

initiation <- read_result("observed_method_initiation_mix.csv")
all_cause <- read_result("all_cause_life_table_published_groups.csv")
reinitiation <- read_result("reinitiation_competing_risk_1_3_6_9_12.csv")
destinations <- read_result(
  "post_discontinuation_destination_among_reinitiators.csv"
)
summary_n <- read_result("reinitiation_sample_summary.csv")

fmt <- function(x) sprintf("%.1f", as.numeric(x))
method_rows <- c("Injectables", "Implants", "Pill")

reinit_12 <- reinitiation[
  reinitiation$Method == "All methods" &
    reinitiation$Horizon == "12 months",
]
dest_12 <- destinations[
  destinations$`Discontinued method` == "All methods" &
    destinations$Month == 12,
]
sample_all <- summary_n[
  summary_n$Method == "All methods",
  "Eligible discontinued episodes (unweighted)"
]

discontinuation_rows <- paste0(vapply(method_rows, function(method_name) {
  dat <- all_cause[all_cause$Method == method_name,]
  paste0(
    "<tr><th scope='row'>", method_name, "</th><td>",
    fmt(dat$`3 months`), "%</td><td>", fmt(dat$`6 months`),
    "%</td><td>", fmt(dat$`9 months`), "%</td><td>",
    fmt(dat$`12 months`), "%</td></tr>"
  )
}, character(1)), collapse = "")

html <- paste0(
"<!doctype html><html lang='en'><head><meta charset='utf-8'>",
"<meta name='viewport' content='width=device-width,initial-scale=1'>",
"<title>Ethiopia contraceptive discontinuation: analysis and extensions</title>",
"<style>",
":root{--ink:#243746;--muted:#667085;--line:#d9ddd8;--paper:#fff;--soft:#f6f7f4;--teal:#0f766e;--gold:#b7791f;--red:#b42318}",
"*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Arial,sans-serif;line-height:1.55}",
"header,main,footer{max-width:1120px;margin:auto;padding:28px 34px}header{padding-top:50px;border-bottom:1px solid var(--line)}",
"h1,h2,h3{font-family:Georgia,serif;font-weight:400}h1{font-size:40px;line-height:1.1;margin:4px 0 14px}h2{font-size:28px;margin:0 0 16px}h3{font-size:20px;margin:0 0 7px}",
".eyebrow{font-size:12px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:var(--teal)}",
".lead{max-width:850px;color:var(--muted);font-size:17px}.section{padding:32px 0;border-bottom:1px solid var(--line)}",
".grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.card{border:1px solid var(--line);padding:18px;background:var(--soft)}",
".value{font-family:Georgia,serif;font-size:34px;color:var(--teal);margin:4px 0}.small{font-size:13px;color:var(--muted)}",
"table{border-collapse:collapse;width:100%;margin:14px 0;font-size:14px}th,td{padding:10px 12px;border-bottom:1px solid var(--line);text-align:right;vertical-align:top}th:first-child,td:first-child{text-align:left}thead th{background:var(--soft)}",
".analysis-list{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.analysis-item{padding:16px 0;border-top:2px solid var(--teal)}",
".priority{display:inline-block;min-width:68px;font-size:12px;font-weight:700;color:var(--teal)}ul{padding-left:21px}.caution{border-left:4px solid var(--gold);padding:12px 16px;background:var(--soft)}",
"@media(max-width:760px){header,main,footer{padding:24px 18px}.grid,.analysis-list{grid-template-columns:1fr}h1{font-size:32px}.table-wrap{overflow-x:auto}}",
"</style></head><body><header><p class='eyebrow'>Ethiopia DHS 2024&ndash;25</p>",
"<h1>Contraceptive discontinuation and switching</h1>",
"<p class='lead'>Summary of the completed contraceptive-calendar analyses, the program questions they address, and the most useful extensions for family-planning teams.</p></header><main>",
"<section class='section'><h2>Completed analysis</h2><div class='analysis-list'>",
"<div class='analysis-item'><h3>Initiation and method mix</h3><p>Describes which methods begin during observed calendar time and how frequently starts occur.</p><p class='small'>Weighted descriptive episode-start shares and rates.</p></div>",
"<div class='analysis-item'><h3>Discontinuation timing</h3><p>Estimates when stopping occurs during the first 12 months and identifies months with elevated stopping hazards.</p><p class='small'>Weighted discrete-time life tables and nonparametric monthly hazards.</p></div>",
"<div class='analysis-item'><h3>Reasons for discontinuation</h3><p>Separates failure, fertility intentions, side effects, method concerns, partner opposition, and other reasons.</p><p class='small'>Weighted Aalen&ndash;Johansen competing-risk cumulative incidence.</p></div>",
"<div class='analysis-item'><h3>Reinitiation and contraceptive gaps</h3><p>Measures how quickly contraception resumes, pregnancy before restart, and remaining event-free through month 12.</p><p class='small'>Weighted Aalen&ndash;Johansen estimation with interview censoring.</p></div>",
"<div class='analysis-item'><h3>Destination and effectiveness pathways</h3><p>Identifies the first method used after discontinuation and whether the pathway returns to the same method or moves to another tier.</p><p class='small'>Destination-specific competing-risk cumulative incidence.</p></div>",
"<div class='analysis-item'><h3>Previous method &times; reason</h3><p>Shows whether post-discontinuation outcomes differ depending on both the method that ended and why it ended.</p><p class='small'>Separate descriptive competing-risk estimates with sparse-cell suppression.</p></div>",
"</div></section>",
"<section class='section'><h2>Selected current findings</h2><div class='grid'>",
"<div class='card'><h3>Reinitiated by 12 months</h3><p class='value'>", fmt(reinit_12$`Reinitiated (%)`), "%</p><p class='small'>Among ", format(sample_all, big.mark=","), " eligible discontinued episodes.</p></div>",
"<div class='card'><h3>Pregnancy before restart</h3><p class='value'>", fmt(reinit_12$`Pregnancy competing event (%)`), "%</p><p class='small'>Estimated first competing outcome by month 12.</p></div>",
"<div class='card'><h3>No observed event</h3><p class='value'>", fmt(reinit_12$`No observed event (%)`), "%</p><p class='small'>Neither restart nor pregnancy observed by month 12 after accounting for censoring.</p></div>",
"</div><h3 style='margin-top:25px'>All-cause discontinuation by method</h3><div class='table-wrap'><table><thead><tr><th>Method</th><th>3 months</th><th>6 months</th><th>9 months</th><th>12 months</th></tr></thead><tbody>", discontinuation_rows, "</tbody></table></div>",
"<h3 style='margin-top:25px'>First method among estimated reinitiations by month 12</h3><div class='grid'>",
"<div class='card'><h3>Injectables</h3><p class='value'>", fmt(dest_12$Injectables), "%</p></div>",
"<div class='card'><h3>Implants</h3><p class='value'>", fmt(dest_12$Implants), "%</p></div>",
"<div class='card'><h3>Pill</h3><p class='value'>", fmt(dest_12$Pill), "%</p></div></div>",
"<p class='caution'><strong>Interpretation:</strong> these are survey-weighted descriptive point estimates. They do not yet include design-adjusted confidence intervals, and they do not establish that a stated reason caused a later outcome.</p></section>",
"<section class='section'><h2>Program decisions supported now</h2><ul>",
"<li>Identify methods for which discontinuation accumulates early and target counseling or follow-up accordingly.</li>",
"<li>Distinguish pregnancy-intent discontinuation from potentially service-responsive reasons such as side effects, access, or desire for a more effective method.</li>",
"<li>Estimate how quickly contraceptive protection resumes and which previous methods are followed by longer gaps.</li>",
"<li>Plan the replacement-method mix required for women who reinitiate contraception.</li>",
"<li>Identify method&ndash;reason combinations associated with low reinitiation or pregnancy before restart for deeper investigation.</li>",
"</ul></section>",
"<section class='section'><h2>Recommended extensions</h2><div class='table-wrap'><table><thead><tr><th>Priority</th><th>Extension</th><th>What it would answer</th><th>Programmatic value</th></tr></thead><tbody>",
"<tr><td><span class='priority'>First</span></td><td><strong>Design-adjusted uncertainty</strong></td><td>Which apparent differences are estimated precisely?</td><td>Add confidence intervals and reliability flags accounting for survey PSUs, strata, weights, censoring, and repeated episodes.</td></tr>",
"<tr><td><span class='priority'>First</span></td><td><strong>Reason-specific destination and gap pathways</strong></td><td>After a given method ends for a given reason, which method is adopted and how long is the gap?</td><td>Connects side-effect support, referrals, commodity needs, and follow-up timing in one output.</td></tr>",
"<tr><td><span class='priority'>Second</span></td><td><strong>Equity stratification</strong></td><td>Do pathways differ by region, residence, age, wealth, parity, or education?</td><td>Identifies populations facing longer gaps or limited method choice.</td></tr>",
"<tr><td><span class='priority'>Second</span></td><td><strong>Adjusted discrete-time competing-risk models</strong></td><td>Do method and reason differences persist after accounting for population characteristics?</td><td>Produces standardized predicted probabilities for targeting while avoiding reliance on raw subgroup composition.</td></tr>",
"<tr><td><span class='priority'>Later</span></td><td><strong>Trend and cross-country comparison</strong></td><td>Are continuation and switching pathways improving over time or differing across settings?</td><td>Supports portfolio learning and distinguishes persistent system issues from survey-specific patterns.</td></tr>",
"</tbody></table></div></section>",
"<section class='section'><h2>Recommended next build</h2><p>Start with design-adjusted confidence intervals and a reason-specific pathway view that combines previous method, discontinuation reason, gap duration, and first destination method. Use broader destination and timing categories when sample sizes are insufficient, and retain pregnancy and no observed event so each 12-month outcome row forms a complete 100% partition.</p></section>",
"</main><footer><p class='small'>Source: Ethiopia DHS 2024&ndash;25 Individual Recode contraceptive calendar. Unit of analysis: eligible contraceptive-use episode; a woman may contribute multiple episodes.</p></footer></body></html>"
)

output_file <- file.path(
  output_dir, "ethiopia_discontinuation_analysis_and_extensions.html"
)
writeLines(enc2utf8(html), output_file, useBytes = TRUE)
message("Created programmatic summary: ", output_file)
