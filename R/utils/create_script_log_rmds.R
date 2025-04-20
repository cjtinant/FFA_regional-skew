# ------------------------------------------------------------------
# create_script_log_rmds.R
# Purpose: Create .Rmd log templates for R scripts in a given folder
# Output: Markdown-based summaries to drop into reports/ folder
# ------------------------------------------------------------------

library(tidyverse)
library(here)
library(fs)

# Set folder containing R scripts
script_dir <- here("R", "01_download")

# Output folder for logs
log_dir <- here("reports", "script_logs")
dir_create(log_dir)

# Get all numbered R scripts
scripts <- dir_ls(script_dir, regexp = "\\d+[a-z]?_.*\\.R$")

# Template generator function
generate_rmd_template <- function(script_path) {
  script_name <- path_file(script_path)
  log_stub <- str_remove(script_name, "\\.R$")
  rmd_path <- path(log_dir, paste0(log_stub, ".Rmd"))
  
  header <- glue::glue(
    "---\ntitle: \"{log_stub}\"\noutput: html_document\n---\n\n"
  )
  
  body <- glue::glue(
    "## Overview\n\nSummary of `{script_name}`.\n\n---\n\n",
    "## 📥 Inputs\n\n- _Describe input files here._\n\n---\n\n",
    "## 🧭 Method\n\n1. _Step-by-step method_\n\n---\n\n",
    "## 📤 Outputs\n\n- _Describe outputs here._\n\n---\n\n",
    "## 📝 Notes\n\n- _Any assumptions, decisions, or gotchas._"
  )
  
  write_lines(c(header, body), rmd_path)
  message("✅ Created: ", rmd_path)
}

# Generate .Rmd logs
walk(scripts, generate_rmd_template)
