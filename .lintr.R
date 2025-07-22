linters <- lintr::linters_with_defaults(
  # Enforce tidyverse naming and assignment
  object_name_linter = lintr::object_name_linter(styles = "snake_case"),
  assignment_linter = lintr::assignment_linter(),        # Use <-, not =

  # Spacing and formatting
  line_length_linter = lintr::line_length_linter(100),   # 100-character lines
  infix_spaces_linter = lintr::infix_spaces_linter(),    # space around +, -, =
  function_left_parentheses_linter = lintr::function_left_parentheses_linter(),  # no space before (
  trailing_whitespace_linter = lintr::trailing_whitespace_linter(),  # clean endings
  spaces_inside_linter = lintr::spaces_inside_linter(),  # no space inside ()

  # Tidy control flow and logic
  commas_linter = lintr::commas_linter(),                # space after commas
  equals_na_linter = lintr::equals_na_linter(),          # use is.na(), not == NA
  vector_logic_linter = lintr::vector_logic_linter(),    # use all(), any()

  # Preferred base R practices
  seq_linter = lintr::seq_linter(),                      # use seq_len(), seq_along()

  # Turn off noisy or tidyverse-incompatible linters
  object_usage_linter = NULL,        # too aggressive with NSE/tidy eval
  commented_code_linter = NULL,      # often false positives in dev code
  camel_case_linter = NULL,          # snake_case is preferred
  single_quotes_linter = NULL        # tidyverse allows double quotes
)






