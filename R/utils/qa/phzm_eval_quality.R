# ==============================================================================
# Script Name:     phzm_eval_quality.R
# Purpose:         QA for PHZM zonal summaries (dominance, gaps, flags, map)
# Author:          CJ Tinant — with Gepeto (GPT-5 Thinking)
# Date Created:    2025-09-15
# Last Updated:    2025-09-15
#
# Inputs:
#   - phzm_tbl : tibble/data.frame produced by phzm_summary(); must include:
#                {id_col}, phzm_class_count, phzm_top1, phzm_top1_prop,
#                phzm_top2, phzm_top2_prop
#   - zones    : polygons (sf or SpatVector) that contain {id_col}
#
# Parameters:
#   - id_col        : join key in both phzm_tbl and zones (default "macro_id")
#   - min_top1      : minimum dominance for top class to consider “good” (0–1)
#   - min_gap       : minimum gap (top1_prop - top2_prop) for “good”
#   - max_classes_warn : warn/flag when too many distinct PHZM classes present
#   - make_map      : if TRUE, return a quick ggplot map object
#
# Outputs:
#   Returns a list with:
#     $quality_table : phzm_tbl + QA fields (dominance_gap, flags, keep)
#     $map           : ggplot (or NULL if make_map = FALSE)
#
# Dependencies: sf, dplyr, ggplot2, rlang, tibble
# CRS Default: NAD83 / EPSG:4269 (project convention)
#
# Changelog:
# - 2025-09-15  v0.1  Initial version: dominance gap, flags, optional map
# ==============================================================================

phzm_eval_quality <- function(
  phzm_tbl,
  zones,
  id_col             = "macro_id",
  min_top1           = 0.60,
  min_gap            = 0.20,
  max_classes_warn   = 8L,
  make_map           = TRUE
) {

  # ---- deps ----
  stopifnot(requireNamespace("sf", quietly = TRUE))
  stopifnot(requireNamespace("dplyr", quietly = TRUE))
  stopifnot(requireNamespace("ggplot2", quietly = TRUE))
  stopifnot(requireNamespace("rlang", quietly = TRUE))

  id_sym <- rlang::sym(id_col)

  # ---- 0) Light checks -------------------------------------------------------
  needed_cols <- c(
    id_col,
    "phzm_class_count",
    "phzm_top1",
    "phzm_top1_prop",
    "phzm_top2",
    "phzm_top2_prop"
  )

  missing_cols <- setdiff(needed_cols, names(phzm_tbl))
  if (length(missing_cols) > 0) {
    stop("phzm_eval_quality(): missing columns in phzm_tbl -> ",
         paste(missing_cols, collapse = ", "))
  }

  # ensure zones is sf; enforce 'geom' geometry column per project preference
  if (inherits(zones, "SpatVector")) {
    zones <- sf::st_as_sf(zones)
  }
  stopifnot(inherits(zones, "sf"))
  if (!id_col %in% names(zones)) {
    stop("phzm_eval_quality(): id_col '", id_col, "' not found in zones.")
  }
  if (!"geom" %in% names(zones)) {
    sf::st_geometry(zones) <- "geom"
  } else {
    sf::st_geometry(zones) <- "geom"
  }

  # ---- 1) Score & flag -------------------------------------------------------
  qa_tbl <-
    phzm_tbl %>%
    dplyr::mutate(
      dominance_gap      = phzm_top1_prop - phzm_top2_prop,
      is_well_char       = (phzm_top1_prop >= min_top1) &
                           (dominance_gap   >= min_gap),
      # fine-grained flags to diagnose *why* it failed
      flag_detail = dplyr::case_when(
        is_well_char                                   ~ "ok",
        phzm_class_count > max_classes_warn            ~ "many_classes",
        phzm_top1_prop   < min_top1  &
          dominance_gap   < min_gap                    ~ "low_dom_low_gap",
        phzm_top1_prop   < min_top1                    ~ "low_dominance",
        dominance_gap     < min_gap                    ~ "small_gap",
        TRUE                                            ~ "review"
      ),
      # coarse flag for quick filtering
      keep = is_well_char
    )

  # ---- 2) Optional quick map -------------------------------------------------
  plt <- NULL
  if (isTRUE(make_map)) {
    # join to polygons; keep only zones that have a summary row
    zones_joined <-
      zones %>%
      dplyr::semi_join(qa_tbl, by = dplyr::join_by(!!id_sym)) %>%
      dplyr::left_join(qa_tbl,  by = dplyr::join_by(!!id_sym))

    # coerce top1 to a labeled factor for a discrete palette
    zones_joined$phzm_top1_f <-
      factor(zones_joined$phzm_top1,
             levels = sort(unique(zones_joined$phzm_top1)),
             labels = paste0("Z", zones_joined$phzm_top1))

    plt <-
      ggplot2::ggplot(zones_joined) +
      ggplot2::geom_sf(
        ggplot2::aes(fill  = phzm_top1_f,
                     alpha = phzm_top1_prop),
        linewidth = 0.1
      ) +
      ggplot2::scale_alpha(range = c(0.35, 1.0), guide = "none") +
      ggplot2::scale_fill_brewer(palette = "Spectral", name = "PHZM top1") +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::labs(
        title    = "PHZM Dominant Class by Zone",
        subtitle = paste0("Alpha = top1 proportion; flagged (keep=FALSE) outlines in black"),
        caption  = "Project CRS default: NAD83 / EPSG:4269"
      ) +
      ggplot2::theme(
        panel.grid.major   = ggplot2::element_blank(),
        panel.grid.minor   = ggplot2::element_blank()
      )

    # add thin outlines for flagged zones to make them pop
    flagged <-
      zones_joined %>% dplyr::filter(!keep)
    if (nrow(flagged) > 0) {
      plt <- plt +
        ggplot2::geom_sf(
          data = flagged,
          fill = NA,
          color = "black",
          linewidth = 0.25
        )
    }
  }

  # ---- 3) Return -------------------------------------------------------------
  return(
    list(
      quality_table = qa_tbl,
      map           = plt
    )
  )
}

How to use

# assume you already have:
#   r_phzm       : PHZM raster (terra SpatRaster, single band)
#   z_phzm_sf    : polygons (sf) with macro_id
#   phzm_tbl     : from phzm_summary(...)

qa <- phzm_eval_quality(
        phzm_tbl           = phzm_tbl,
        zones              = z_phzm_sf,
        id_col             = "macro_id",
        min_top1           = 0.60,
        min_gap            = 0.20,
        max_classes_warn   = 8L,
        make_map           = TRUE
      )

qa$quality_table %>% dplyr::count(flag_detail)
print(qa$map)