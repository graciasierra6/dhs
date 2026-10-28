get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) == 0) {
    stop("Run this script with Rscript so the script path is available.")
  }

  dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE))
}

script_dir <- get_script_dir()
project_root <- normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)

suppressPackageStartupMessages({
  library(readxl)
  library(readr)
  library(dplyr)
  library(tidyr)
})

wpp_path <- file.path(project_root, "WPP2024_POP_F01_3_POPULATION_SINGLE_AGE_FEMALE.xlsx")
mcpr_path <- file.path(project_root, "mcpr_data.csv")
output_path <- file.path(project_root, "country_pop_weights_15_49.csv")

region_lookup <- c(
  "Cambodia" = "East Asia and Pacific",
  "Indonesia" = "East Asia and Pacific",
  "Philippines" = "East Asia and Pacific",
  "Timor-Leste" = "East Asia and Pacific",
  "Vietnam" = "East Asia and Pacific",
  "Albania" = "Europe and Central Asia",
  "Armenia" = "Europe and Central Asia",
  "Kazakhstan" = "Europe and Central Asia",
  "Kyrgyz Republic" = "Europe and Central Asia",
  "Tajikistan" = "Europe and Central Asia",
  "Turkey" = "Europe and Central Asia",
  "Bolivia" = "Latin America and Carribbean",
  "Brazil" = "Latin America and Carribbean",
  "Colombia" = "Latin America and Carribbean",
  "Dominican Republic" = "Latin America and Carribbean",
  "Guatemala" = "Latin America and Carribbean",
  "Haiti" = "Latin America and Carribbean",
  "Honduras" = "Latin America and Carribbean",
  "Nicaragua" = "Latin America and Carribbean",
  "Peru" = "Latin America and Carribbean",
  "Egypt" = "Middle East and North Africa",
  "Jordan" = "Middle East and North Africa",
  "Morocco" = "Middle East and North Africa",
  "Yemen" = "Middle East and North Africa",
  "Bangladesh" = "South Asia",
  "India" = "South Asia",
  "Maldives" = "South Asia",
  "Nepal" = "South Asia",
  "Pakistan" = "South Asia",
  "Benin" = "West Africa",
  "Burkina Faso" = "West Africa",
  "Cote d'Ivoire" = "West Africa",
  "Gambia" = "West Africa",
  "Ghana" = "West Africa",
  "Guinea" = "West Africa",
  "Liberia" = "West Africa",
  "Mali" = "West Africa",
  "Niger" = "West Africa",
  "Nigeria" = "West Africa",
  "Senegal" = "West Africa",
  "Sierra Leone" = "West Africa",
  "Togo" = "West Africa",
  "Cameroon" = "Central Africa",
  "Chad" = "Central Africa",
  "Congo" = "Central Africa",
  "Congo Democratic Republic" = "Central Africa",
  "Gabon" = "Central Africa",
  "Angola" = "East/Southern Africa",
  "Burundi" = "East/Southern Africa",
  "Comoros" = "East/Southern Africa",
  "Ethiopia" = "East/Southern Africa",
  "Kenya" = "East/Southern Africa",
  "Lesotho" = "East/Southern Africa",
  "Madagascar" = "East/Southern Africa",
  "Malawi" = "East/Southern Africa",
  "Mozambique" = "East/Southern Africa",
  "Namibia" = "East/Southern Africa",
  "Rwanda" = "East/Southern Africa",
  "South Africa" = "East/Southern Africa",
  "Tanzania" = "East/Southern Africa",
  "Uganda" = "East/Southern Africa",
  "Zambia" = "East/Southern Africa",
  "Zimbabwe" = "East/Southern Africa"
)

harmonize_wpp_country_name <- function(x) {
  x_ascii <- iconv(x, from = "", to = "ASCII//TRANSLIT")

  dplyr::case_when(
    grepl("Ivoire", x, ignore.case = TRUE) | grepl("Ivoire", x_ascii, ignore.case = TRUE) ~ "Cote d'Ivoire",
    x == "Democratic Republic of the Congo" | x_ascii == "Democratic Republic of the Congo" ~ "Congo Democratic Republic",
    x == "United Republic of Tanzania" | x_ascii == "United Republic of Tanzania" ~ "Tanzania",
    x == "Kyrgyzstan" | x_ascii == "Kyrgyzstan" ~ "Kyrgyz Republic",
    x == "Bolivia (Plurinational State of)" | x_ascii == "Bolivia (Plurinational State of)" ~ "Bolivia",
    x == "Viet Nam" | x_ascii == "Viet Nam" ~ "Vietnam",
    grepl("^T.*rkiye$", x_ascii) | x == "Türkiye" ~ "Turkey",
    TRUE ~ x
  )
}

project_countries <- read_csv(mcpr_path, show_col_types = FALSE) %>%
  distinct(country) %>%
  filter(!is.na(country)) %>%
  mutate(region = unname(region_lookup[country])) %>%
  filter(!is.na(region))

wpp_raw <- read_excel(
  wpp_path,
  sheet = "Estimates",
  col_names = FALSE,
  skip = 14,
  .name_repair = "minimal"
)
wpp_headers <- as.character(unlist(wpp_raw[2, ]))
colnames(wpp_raw) <- wpp_headers

age_cols <- as.character(15:49)

country_pop_weights <- wpp_raw[-c(1, 2), ] %>%
  mutate(
    Type = as.character(Type),
    Year = as.integer(Year),
    country_wpp = as.character(`Region, subregion, country or area *`),
    iso3 = as.character(`ISO3 Alpha-code`),
    location_code = as.character(`Location code`)
  ) %>%
  filter(Type == "Country/Area") %>%
  mutate(across(all_of(age_cols), as.numeric)) %>%
  mutate(
    country = harmonize_wpp_country_name(country_wpp),
    women_15_49_thousands = rowSums(across(all_of(age_cols)), na.rm = TRUE),
    women_15_49 = round(women_15_49_thousands * 1000)
  ) %>%
  select(
    country,
    country_wpp,
    iso3,
    location_code,
    Year,
    women_15_49_thousands,
    women_15_49
  ) %>%
  inner_join(project_countries, by = "country") %>%
  arrange(region, country, Year)

missing_countries <- setdiff(project_countries$country, unique(country_pop_weights$country))
if (length(missing_countries) > 0) {
  stop(
    "Missing WPP women 15-49 weights for project countries: ",
    paste(missing_countries, collapse = ", ")
  )
}

write_csv(country_pop_weights, output_path)

cat("Wrote", nrow(country_pop_weights), "country-year rows to", output_path, "\n")
cat("Countries:", n_distinct(country_pop_weights$country), "\n")
cat("Years:", min(country_pop_weights$Year, na.rm = TRUE), "to", max(country_pop_weights$Year, na.rm = TRUE), "\n")
