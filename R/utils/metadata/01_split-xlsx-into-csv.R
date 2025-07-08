# ==============================================================================
# Script Name: 01_split-xlsx-into-csv.R
# Author: Charles Jason Tinant with ChatGPT ver 4o
# Date Created: May 2025
#

# Purpose:
# Extract each worksheet from a covariate metadata Excel workbook (.xlsx)
# into a separate, modular .csv file. These CSVs are lightweight, versionable,
# GitHub-compatible, and suitable for direct use in R scripts or automated QA.
# This script supports a clean, maintainable metadata structure for modeling.

library(readxl)
library(readr)

# Define input and output
xlsx_path <- "docs/skew_covariates_metadata_v01.xlsx"
output_dir <- "docs/covariates_metadata_split/"

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) dir.create(output_dir)

# List all worksheet names
sheets <- excel_sheets(xlsx_path)

# Loop through sheets and export each as a CSV
for (sheet in sheets) {
  df <- read_excel(xlsx_path, sheet = sheet)
  csv_name <- paste0(output_dir, "covariates_", gsub(" ", "_", sheet), ".csv")
  write_csv(df, csv_name)
}
