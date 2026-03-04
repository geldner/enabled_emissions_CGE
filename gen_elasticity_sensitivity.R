## GENERATE ELASTICITY SENSITIVITY PARAMETER FILES
## This script creates modified copies of default.prm with scaled elasticity parameters
## for sensitivity analysis of the CGE model.
##
## Output files:
##   - cap_low.prm:   EFKE (capital-energy substitution) scaled by 0.5
##   - cap_high.prm:  EFKE scaled by 1.5
##   - type_low.prm:  Energy type substitution elasticities scaled by 0.5
##   - type_high.prm: Energy type substitution elasticities scaled by 1.5
##   - both_low.prm:  Both capital-energy and energy type elasticities scaled by 0.5
##   - both_high.prm: Both scaled by 1.5
##
## Energy type headers: EFEB, EFEP, EPEB, EPEP, EGEB, EGEP, EIEB, EIEP

# Set working directory to GTAP model location
setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_20by5/gtpv7AI")

## CONFIGURATION
################

# Source file
source_file <- "default.prm"

# Headers for capital-energy substitution
cap_headers <- c("EFKE")

# Headers for energy type substitution
type_headers <- c("EFEB", "EFEP", "EPEB", "EPEP", "EGEB", "EGEP", "EIEB", "EIEP")

# Define all output configurations
output_configs <- list(
  list(
    dest_file = "cap_low.prm",
    headers = cap_headers,
    scale_factor = 0.5,
    description = "Capital-energy substitution elasticity (EFKE) scaled by 0.5"
  ),
  list(
    dest_file = "cap_high.prm",
    headers = cap_headers,
    scale_factor = 1.5,
    description = "Capital-energy substitution elasticity (EFKE) scaled by 1.5"
  ),
  list(
    dest_file = "type_low.prm",
    headers = type_headers,
    scale_factor = 0.5,
    description = "Energy type substitution elasticities scaled by 0.5"
  ),
  list(
    dest_file = "type_high.prm",
    headers = type_headers,
    scale_factor = 1.5,
    description = "Energy type substitution elasticities scaled by 1.5"
  ),
  list(
    dest_file = "both_low.prm",
    headers = c(cap_headers, type_headers),
    scale_factor = 0.5,
    description = "Both capital-energy and energy type elasticities scaled by 0.5"
  ),
  list(
    dest_file = "both_high.prm",
    headers = c(cap_headers, type_headers),
    scale_factor = 1.5,
    description = "Both capital-energy and energy type elasticities scaled by 1.5"
  )
)

## FUNCTION TO GENERATE STI FILE AND RUN MODHAR
###############################################

generate_scaled_prm <- function(source_file, dest_file, headers, scale_factor, description) {

  cat("\n========================================\n")
  cat("Generating:", dest_file, "\n")
  cat("========================================\n")
  cat("Description:", description, "\n")
  cat("Source file:", source_file, "\n")
  cat("Scale factor:", scale_factor, "\n")
  cat("Headers to modify:", paste(headers, collapse = ", "), "\n\n")

  # Build STI file name based on destination
  sti_file <- paste0("gen_", gsub("\\.prm$", "", dest_file), ".sti")

  # Start building STI content
  # MODHAR interactive flow for scaling:
  # 1. Start with existing file? y
  # 2. Source file name
  # 3. New file name
  # 4. For each header: mw -> header -> m -> s -> w -> s -> factor -> w -> n
  # 5. ex -> a -> attribution -> **end -> y

  sti_content <- c(
    "",                    # Initial blank line (modhar expects this)
    "y",                   # Yes, start with existing file
    source_file,           # Source HAR file
    dest_file              # Destination HAR file
  )

  # Process each header
  for (header in headers) {
    cat("  Adding scale command for header:", header, "\n")

    sti_content <- c(
      sti_content,
      "mw",              # Modify/write command
      header,            # Header name
      "m",               # Modify the data
      "s",               # Scale existing data (not replace)
      "w",               # Whole matrix (not one element at a time)
      "s",               # Same scaling factor for all entries
      as.character(scale_factor),  # The scaling factor
      "w",               # Write the modified header
      "n"                # No more operations on this header
    )
  }

  # Complete the STI file
  sti_content <- c(
    sti_content,
    "ex",                  # Exit modhar
    "a",                   # Apply changes
    "Geldner",             # Attribution
    "**end",               # End marker
    "y"                    # Confirm
  )

  # Write the STI file
  writeLines(sti_content, sti_file)
  cat("\n  Created STI file:", sti_file, "\n")

  # Display the STI file content for debugging
  cat("\n  --- STI File Contents ---\n")
  for (line in sti_content) {
    cat("  ", line, "\n", sep = "")
  }
  cat("  --- End STI File ---\n\n")

  # Run MODHAR
  cat("  Running modhar...\n")
  modhar_result <- system(paste0("modhar -sti ", sti_file), ignore.stdout = FALSE)

  if (modhar_result == 0 && file.exists(dest_file)) {
    cat("\n  *** SUCCESS! ***\n")
    cat("  Created", dest_file, "successfully\n")
    return(TRUE)
  } else {
    cat("\n  ERROR: modhar returned exit code", modhar_result, "\n")
    cat("  Check the STI file and modhar output for errors.\n")
    return(FALSE)
  }
}

## MAIN EXECUTION
#################

cat("========================================\n")
cat("ELASTICITY SENSITIVITY ANALYSIS\n")
cat("Parameter File Generation\n")
cat("========================================\n")

# Track results
results <- list()

# Generate each output file
for (config in output_configs) {
  success <- generate_scaled_prm(
    source_file = source_file,
    dest_file = config$dest_file,
    headers = config$headers,
    scale_factor = config$scale_factor,
    description = config$description
  )
  results[[config$dest_file]] <- success
}

## SUMMARY
##########

cat("\n\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

cat("Files generated:\n")
for (name in names(results)) {
  status <- if (results[[name]]) "SUCCESS" else "FAILED"
  cat("  ", name, ": ", status, "\n", sep = "")
}

cat("\nOutput files contain the following modifications:\n")
cat("  - cap_low.prm:   EFKE x 0.5\n")
cat("  - cap_high.prm:  EFKE x 1.5\n")
cat("  - type_low.prm:  EFEB, EFEP, EPEB, EPEP, EGEB, EGEP, EIEB, EIEP x 0.5\n")
cat("  - type_high.prm: EFEB, EFEP, EPEB, EPEP, EGEB, EGEP, EIEB, EIEP x 1.5\n")
cat("  - both_low.prm:  All above headers x 0.5\n")
cat("  - both_high.prm: All above headers x 1.5\n")

cat("\n========================================\n")
cat("DONE\n")
cat("========================================\n")
