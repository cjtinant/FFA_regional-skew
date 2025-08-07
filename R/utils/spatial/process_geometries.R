# ============================================================================
# Script Name:     process_geometries.R
# Author:          Charles Jason Tinant with ChatGPT 4o
# Date Created:    2024-06-06
# Last Updated:    2025-07-28
# Change Log:
# - 2025-07-28     Update header information;
#                  move notes to `script-notes_and_developer-log`.
#
# Purpose:         The function is returns a modified sf object with additional
#                  columns for centroid coordinates.
#
# Workflow Summary:
# 1. Validate geometries of sf objects using st_make_valid().
# 2. Calculate centroid (st_centroid).
# 3. Extract x (longitude) and y (latitude) coordinates of centroid; or NA if
#    geometry is invalid or empty.
# 4. Implicitly return a modified sf object with new columns: text_x and text_y
#    sf object -- 'return(sf_object)' is not needed in the function.
#
# Input/Data URLs:
# - A user-defined sf object.
# Output:
# - A modified sf object with additional columns,
#
# Dependencies:
# - sf             Spatial data and geometry operations
# - tidyverse      General data wrangling (used here for loading)
#
# Helper Functions
#
# Related Milestone Reports:
#
# ==============================================================================
# --- load libraries ---
pkgs <- c("sf", "tidyverse")
walk(pkgs, require, character.only = TRUE)

process_geometries <- function(sf_object) {
  # Ensure all geometries are valid
  sf_object$geometry <- st_make_valid(sf_object$geometry)

  # Initialize columns for centroids and coordinates
  sf_object$text_x <- rep(NA_real_, nrow(sf_object))
  sf_object$text_y <- rep(NA_real_, nrow(sf_object))

  # Calculate centroids for valid geometries and extract coordinates
  for (i in seq_len(nrow(sf_object))) {
    if (st_is_valid(sf_object$geometry[i])) {
      centroid <- st_centroid(sf_object$geometry[i])
      if (!is.na(centroid) && !st_is_empty(centroid)) {
        coords <- st_coordinates(centroid)
        # Explicit check for coords' validity and structure
        if (!is.null(coords) && nrow(coords) > 0 && ncol(coords) >= 2) {
          sf_object$text_x[i] <- coords[1, 1]
          sf_object$text_y[i] <- coords[1, 2]
        }
      }
    }
  }
}
