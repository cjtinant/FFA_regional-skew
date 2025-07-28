# =============================================================================
# Script Name:     run_lintr_on_a_directory.R
# Author:          Charles Jason Tinant — with ChatGPT 4o
# Date Created:    2025-07-22
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-28     Update header information;
#
# Purpose:         A very short function to run lintr on a file folder.
#
# Workflow Summary:
# 1. Set directory
# 2. Run lintr
#
# Input/Data URLs:
# - FFA_regional_skew/.lintr.R
# - user-defined directory
# Outputs:
# - Not Applicable
#
# Dependencies:
# - lintr          Checks adherence to a given style, syntax errors and possible
#                  semantic issues.
#
# Helper Functions:
#
# Related Milestone Reports:
#
# =============================================================================
# --- Load libraries ---
library(lintr)

setwd("~/Documents/Rprojects_not-class/FFA_regional-skew/R")

lint_dir()
