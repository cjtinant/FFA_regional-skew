  # ============================================================================
  # Script Name: f_process_geometries.R
  # Author: Charles Jason Tinant
  # written with ChatGPT 4.0 on 2024-06-06
  # Date Created: June 2024
  #
  # Purpose:
  # This function, `process_geometries()`, takes an sf (simple features) object 
  # and ensures all geometries are valid before calculating centroids and extracting 
  # x/y coordinates for labeling or spatial analysis. The function is designed to 
  # handle invalid geometries safely and returns a modified sf object with additional 
  # columns for centroid coordinates.
  #
  # Workflow Summary:
  # 1. Validate all geometries using st_make_valid()
  # 2. For each feature:
  #    - If geometry is valid:
  #       - Calculate centroid (st_centroid)
  #       - Extract x (text_x) and y (text_y) coordinates
  #    - If geometry is invalid or empty:
  #       - Assign NA to coordinates
  # 3. Return modified sf object with new columns: text_x and text_y
  #
  # Output:
  # Modified sf object with additional columns:
  # - text_x → Longitude coordinate of centroid (or NA)
  # - text_y → Latitude coordinate of centroid (or NA)
  #
  # Dependencies:
  # - sf          → Spatial data and geometry operations
  # - tidyverse   → General data wrangling (used here for loading)
  #
  # Notes:
  # - This function applies strict checks for geometry validity and centroid 
  #   coordinate extraction to avoid errors during plotting or labeling.
  # - Safeguards include:
  #   - Checks for NA geometries
  #   - Checks for empty or NULL centroids
  #   - Explicit verification of coordinate matrix structure before extraction
  # - Useful for map labeling, visualization, or spatial summaries where centroid 
  #   locations are required.
  #
  # Details about process_geometries:
  # Geometry Validation:
  #   st_make_valid() is used to correct any invalid geometries within the
  #     spatial data frame. The function identifies indices of valid geometries
  #     to ensure that centroids and subsequent operations are only applied to
  #     them.
  # Centroid Calculation:
  #   st_centroid() is applied conditionally only to valid geometries using
  #     ifelse().
  #   If a geometry is invalid, NA is used as a fallback.
  #      st_centroid() is applied only to the valid parts of the geometry column.
  #   Centroids are stored in a list to handle any type of geometry being returned
  #      from st_centroid().
  #   Each geometry is processed individually within a loop to allow more control
  #      over handling each item and better debugging capabilities if errors occur.
  #   !is_empty(centroid) checks if the centroid is not empty. 
  #   The function also ensures that st_coordinates(centroid) actually returns
  #      a non-empty data frame before trying to access its elements.
  # Conditional Coordinates Extraction:
  #   The x and y coordinates are extracted from the centroid. If the centroid
  #      is NA (because the geometry was invalid), the coordinate fields are set
  #      to NA.
  #   Coordinates are extracted only if there are valid centroids. This is
  #      safeguarded by checking if there are valid indices before attempting to
  #      extract coordinates.
  #   text_x and text_y are initialized with NA_real_ to ensure that the type
  #      consistency is maintained for cases where centroids might not be
  #      computable.
  #   Before extracting coordinates, the function checks if the centroid is not NA
  #      and contains rows. Then it ensures that the coordinates can be indexed
  #      properly, and has the required number of columns 
  #        (at least two, for x and y coordinates).
  # Additional checks:
  #   Separate Checks for NAs and Data Structure Validity: The function checks
  #       for NAs and the structure of coords are now more explicit.
  #     The function checks if centroid is not NA and not empty. Then, if coords
  #       is derived, the function ensures it is not NA and has the necessary rows
  #       and columns.
  #   Avoid Coercion Errors: By ensuring each part of the conditional is valid
  #       before evaluating the next part, this prevents logical operations on
  #       possibly undefined or inappropriate data types.
  #   Direct Evaluation of Conditions: The logic is structured to progressively
  #       verify conditions before accessing potentially problematic attributes
  #       like the number of rows or columns.
  #   Check for null in coords: The function ensures that coords is not null
  #       before proceeding to check its dimensions. This prevents logical errors
  #       when coords might be an unexpected type or structure.
  #   Explicit Structure Check: By using is.null along with checks for the number
  #       of rows and columns in coords, the function can more reliably ensure
  #       that the data structure is correct before attempting to access its
  #       elements.
  
  # ==============================================================================


# packages needed for this script
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
  
  # Return the modified sf object
  return(sf_object)
}