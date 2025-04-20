
# ==============================================================================
# Instructions for Registering for PRISM Data Access
# ==============================================================================

# To download PRISM climate data using the prism R package, you must register 
# for a free PRISM API key.

# 1. Visit the PRISM Climate Group registration page:
#    https://prism.oregonstate.edu/normals/

# 2. Complete the short registration form with your name, email, and affiliation.

# 3. After registering, you will receive an API key via email.
#    (Example format: abc123xyz456abcdef789)

# 4. Store this key safely in your .Renviron file using:
#    usethis::edit_r_environ()

# Add this line to .Renviron:
# PRISM_API_KEY=your_actual_key_here

# 5. Restart RStudio to load your environment variables.

# 6. In any R script, access the API key like this:
# prism_api_key <- Sys.getenv("PRISM_API_KEY")
# prism_set_api_key(prism_api_key)

# 7. Ensure .Renviron is in .gitignore to prevent committing sensitive data:
# .Renviron

# ==============================================================================
