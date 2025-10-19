# .lintr (R config)
linters <- lintr::linters_with_defaults(
  # Style
  object_name_linter = lintr::object_name_linter(styles = "snake_case"),
  assignment_linter  = lintr::assignment_linter(),          # prefer <-
  line_length_linter = lintr::line_length_linter(100L),
  
  # Spacing / formatting
  infix_spaces_linter               = lintr::infix_spaces_linter(),
  function_left_parentheses_linter  = lintr::function_left_parentheses_linter(),
  trailing_whitespace_linter        = lintr::trailing_whitespace_linter(),
  spaces_inside_linter              = lintr::spaces_inside_linter(),
  commas_linter                     = lintr::commas_linter(),
  
  # Logic / correctness
  equals_na_linter   = lintr::equals_na_linter(),
  vector_logic_linter= lintr::vector_logic_linter(),
  seq_linter         = lintr::seq_linter(),
  
  # Quiet noisy ones for tidyverse/NSE
  object_usage_linter  = NULL,
  commented_code_linter= NULL
)

# Optional: don’t lint vendored or generated stuff
exclusions <- list(
  "renv/*",
  "data/*",
  "docs/*",
  "notebooks/*",
  ".Rproj.user/*"
)
