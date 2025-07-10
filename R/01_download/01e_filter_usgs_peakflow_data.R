# ==============================================================================
# Script Name:    01e_filter_usgs_peakflow_data.R
# Author:         Charles Jason Tinant — with ChatGPT 4o
# Date Created:   April 2025
# Last Updated:   2025-07-09
#
# Purpose:
# Filters and tags raw USGS peak flow records for reliability and modeling use.
# Applies exclusions based on:
# - Missing discharge or dates
# - Dam failure and known regulation flags
# - Short record lengths (< 20 years)
# - Optional: flags for suspect measurements (unknown regulation)
#
# Generates both "core" and "blended" analysis datasets:
# - Core     = excludes suspect (flag 5) records
# - Blended  = includes all non-regulated, non-dam-break records
#
# Workflow Summary:
# 1. Load raw peak flow dataset
# 2. Drop records with missing discharge or dates
# 3. Fill missing peak dates with AG DT where available
# 4. Tag records for dam break (code 3), regulated (code 6), and suspect (code 5)
# 5. Remove regulated and dam break records
# 6. Filter sites to those with ≥ 20 years of data
# 7. Define analysis paths (core vs blended) and summarize impact
# 8. Export cleaned datasets, summary tables, and metadata
#
# Output Files:
# data/processed/peakflow_gages/
# - peakflow_gages/data_pk_core.csv          modeling-ready core data
# - alternative dataset w/ suspect gages     data_pk_blended.csv
# data/meta/
# - peakflow_sites_dropped_in_core.csv       sites lost in core-only analysis
# - peakflow_sites_dropped_summary.csv       summary of dropped site count
# - data/meta/summary_pk_by_site.csv         site-year counts (for 20-yr filter)
#
# Dependencies:
# - tidyverse     → dplyr, purrr, readr, stringr, etc.
# - glue          → string interpolation
# - here          → relative path handling
# - fs            → file system ops (dir_create)
#
# Notes:
# - Peak codes are comma-separated and must be parsed for reliable flagging
# - Suspect data are retained in the blended analysis for sensitivity checks
# - Use `filter_summary` to trace record reduction across pipeline steps
# ==============================================================================
# Load required libraries
library(tidyverse)      # dplyr, purrr, readr, etc.
library(glue)           # Dynamic string construction
library(here)           # Robust relative file paths
library(readr)
library(fs)

# ---------------------------------------------------------
# 1. Load peak flow data
data_pk <- read_csv(here("data/raw/peakflow_gages/usgs_data_pk_all.csv")) 

# ---------------------------------------------------------
# 2. Drop NA discharge
data_pk_drop_na <- data_pk %>% filter(!is.na(peak_va))

# ---------------------------------------------------------
# 3. Fill missing peak date with ag_dt
data_pk_fill_date <- data_pk_drop_na %>%
  mutate(peak_dt = coalesce(peak_dt, ag_dt)) %>%
  filter(!is.na(peak_dt))

# ---------------------------------------------------------
# 4. Tag exclusion flags
# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------
min_record_years <- 20

codes <- list(
  dam_break    = "3",
  regulated    = "6",
  suspect      = "5"
)

has_peak_flag <- function(x, code) {
  str_detect(x, glue("(^|,)\\s*{code}(,|$)"))
}

data_pk_tagged <- data_pk_fill_date %>%
  mutate(
    is_break     = has_peak_flag(peak_cd, codes$dam_break),
    is_regulated = has_peak_flag(peak_cd, codes$regulated),
    is_suspect   = has_peak_flag(peak_cd, codes$suspect)
  ) %>%
  mutate(across(c(is_break, is_regulated, is_suspect), 
                ~replace_na(.x, FALSE)))

# ---------------------------------------------------------
# 5. Remove dam break and regulated codes
data_pk_filtered <- data_pk_tagged %>%
  filter(!is_break & !is_regulated) %>%
  mutate(peak_year = year(peak_dt)) %>%
  select(-date_parse_failed, -is_break, -is_regulated)

# ---------------------------------------------------------
# 6. Remove sites with fewer than 20 years of data
site_counts <- data_pk_filtered %>%
  group_by(site_no) %>%
  summarise(n_years = n_distinct(year(peak_dt)), .groups = "drop")

data_pk_filtered_20yr <- data_pk_filtered %>%
  left_join(site_counts, by = c("site_no")) %>%
  filter(n_years >= min_record_years)

# ---------------------------------------------------------
# 7. Define analysis paths: Core vs Blended
# ---------------------------------------------------------

# (a) CORE ANALYSIS: exclude suspect records
data_core <- data_pk_filtered_20yr %>%
  filter(!is_suspect)

# (b) BLENDED ANALYSIS: include suspect records (full filtered set)
data_blended <- data_pk_filtered_20yr

# ---------------------------------------------------------
# 8. Identify "at-risk" sites that would be lost in core analysis
site_counts_core <- data_core %>%
  group_by(site_no) %>%
  summarise(n_years_core = n_distinct(year(peak_dt)), .groups = "drop")

site_counts_blended <- data_blended %>%
  group_by(site_no) %>%
  summarise(n_years_blended = n_distinct(year(peak_dt)), .groups = "drop")

site_risk_tbl <- site_counts_blended %>%
  left_join(site_counts_core, by = "site_no") %>%
  mutate(
    n_years_core = replace_na(n_years_core, 0),
    dropped_in_core = n_years_blended >= min_record_years &
      n_years_core < min_record_years
  ) %>%
  filter(dropped_in_core)

# Summary
site_risk_summary <- site_risk_tbl %>%
  summarise(
    n_sites_dropped = n(),
    min_n_years_core = min(n_years_core),
    max_n_years_blended = max(n_years_blended)
  )

print(site_risk_summary)

filter_summary <- tibble::tibble(
  step = c("Raw", "Drop NA discharge", 
           "Fill dates", 
           "Remove regulated/break", 
           "Core (no suspect)"),
  n_records = c(
    nrow(data_pk),
    nrow(data_pk_drop_na),
    nrow(data_pk_fill_date),
    nrow(data_pk_filtered),
    nrow(data_core)
  ),
  n_sites = c(
    n_distinct(data_pk$site_no),
    n_distinct(data_pk_drop_na$site_no),
    n_distinct(data_pk_fill_date$site_no),
    n_distinct(data_pk_filtered$site_no),
    n_distinct(data_core$site_no)
  )
)

# ---------------------------------------------------------
# 9. Project to Albers Conic
# ---------------------------------------------------------











# ---------------------------------------------------------
# 10. Export datasets and metadata
# ---------------------------------------------------------
# Create a folder named "peakflow_gages" inside data/processed
dir_create(here("data", "processed", "peakflow_gages"))

write_csv(data_core, here("data/processed/peakflow_gages/data_pk_core.csv"))
write_csv(data_blended, here("data/processed/peakflow_gages/data_pk_blended.csv"))
write_csv(site_risk_tbl, here("data/meta/peakflow_sites_dropped_in_core.csv"))
write_csv(site_risk_summary, here("data/meta/peakflow_sites_dropped_summary.csv"))
write_csv(site_counts, here("data/meta/summary_pk_by_site.csv"))

# Optional message
message(glue(
  "Blended analysis retains {nrow(data_blended)} records across ",
  "{n_distinct(data_blended$site_no)} sites.\n",
  "Core analysis retains {nrow(data_core)} records across ",
  "{n_distinct(data_core$site_no)} sites.\n",
  "{nrow(site_risk_tbl)} sites would be dropped in core due to suspect-only records."
))


