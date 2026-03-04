## EXTRACT PRIMARY ENERGY MIX FROM BASEDATA HAR FILES
## This script extracts the primary energy mix from basedata.har (2017)
## and basedata_2024.har (calibrated to 2024) and saves the results to CSV.
##
## Primary energy is calculated from three volume headers:
##   EDF: Electricity demand by fuel type (ERG x ACTS x REG)
##   EDP: Electricity demand by peaking fuel type (ERG x REG)
##   EXI: Energy commodity volumes (ERG x REG)
##
## Renewable generation values are multiplied by 1/0.4 to convert to
## primary energy equivalents (accounting for generation conversion ratios).
##
## Fossil primary energy uses raw commodity values (Coal, Oil, Gas),
## excluding Oil_pcts and fossil fuel generation to avoid double-counting.

.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_20by5/gtpv7AI")

## CONFIGURATION
renewable_sectors <- c("NuclearBL", "HydroBL", "WindBL", "HydroP", "SolarP", "OtherBL")
fossil_commodity_sectors <- c("Coal", "Oil", "Gas")
all_sectors <- c(renewable_sectors, fossil_commodity_sectors)

# Conversion factor: renewable generation to primary energy equivalent
renewable_conversion <- 1 / 0.4

har_files <- list(
  "basedata_2017" = "basedata.har",
  "basedata_2024" = "basedata_2024.har"
)

## FUNCTION: Extract primary energy mix from a HAR file
extract_energy_mix <- function(har_file, label) {
  cat("Processing:", har_file, "(", label, ")\n")

  if (!file.exists(har_file)) {
    stop(paste("ERROR: File not found:", har_file))
  }

  # Create temp directory for CSV extracts
  tmp_dir <- paste0("../energy_mix_tmp/", label)
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)

  # Extract the three primary energy headers
  headers <- c("EDF", "EDP", "EXI")
  volumes_list <- list()

  for (h in headers) {
    csv_file <- paste0(tmp_dir, "/", h, ".csv")
    result <- system(
      paste("har2csv", har_file, csv_file, h),
      ignore.stdout = TRUE
    )

    if (result != 0 || !file.exists(csv_file)) {
      cat("  WARNING: Failed to extract header", h, "from", har_file, "\n")
      next
    }

    dt <- fread(csv_file, showProgress = FALSE)
    dt[, Value := as.numeric(Value)]

    # Sum by ERG and REG (EDF has ACTS dimension, EDP/EXI may vary)
    vol_sum <- dt[, .(consumption = sum(Value)), by = .(ERG, REG)]
    volumes_list[[h]] <- vol_sum
    cat("  Extracted", h, ":", nrow(dt), "rows\n")
  }

  if (length(volumes_list) == 0) {
    stop(paste("ERROR: No headers could be extracted from", har_file))
  }

  # Combine all volume sources and sum by ERG
  all_volumes <- rbindlist(volumes_list)
  output_by_erg <- all_volumes[, .(output = sum(consumption)), by = .(ERG)]

  # Filter to primary energy sectors (excludes Oil_pcts and fossil generation)
  gen_data <- output_by_erg[ERG %in% all_sectors]

  # Apply renewable conversion factor (generation to primary energy equivalent)
  gen_data[ERG %in% renewable_sectors, output := output * renewable_conversion]

  # Calculate total primary energy and shares
  total_primary <- gen_data[, sum(output)]
  gen_data[, share := output / total_primary]
  gen_data[, dataset := label]

  cat("  Total primary energy:", round(total_primary, 2), "\n")
  cat("  Sectors found:", paste(gen_data$ERG, collapse = ", "), "\n\n")

  return(gen_data)
}

## EXTRACT FROM BOTH HAR FILES
results <- list()

for (label in names(har_files)) {
  har_file <- har_files[[label]]
  results[[label]] <- extract_energy_mix(har_file, label)
}

## COMBINE AND FORMAT RESULTS
combined <- rbindlist(results)

# Pivot to wide format for easier comparison
wide <- dcast(combined, ERG ~ dataset, value.var = c("output", "share"))

# Order by 2017 output descending
setorder(wide, -output_basedata_2017)

# Add combined Hydro rows
hydro_2017_output <- wide[ERG %in% c("HydroBL", "HydroP"), sum(output_basedata_2017, na.rm = TRUE)]
hydro_2024_output <- wide[ERG %in% c("HydroBL", "HydroP"), sum(output_basedata_2024, na.rm = TRUE)]
hydro_2017_share <- wide[ERG %in% c("HydroBL", "HydroP"), sum(share_basedata_2017, na.rm = TRUE)]
hydro_2024_share <- wide[ERG %in% c("HydroBL", "HydroP"), sum(share_basedata_2024, na.rm = TRUE)]

# Fossil primary energy (commodity values only, no generation)
fossil_2017_output <- wide[ERG %in% fossil_commodity_sectors, sum(output_basedata_2017, na.rm = TRUE)]
fossil_2024_output <- wide[ERG %in% fossil_commodity_sectors, sum(output_basedata_2024, na.rm = TRUE)]
fossil_2017_share <- wide[ERG %in% fossil_commodity_sectors, sum(share_basedata_2017, na.rm = TRUE)]
fossil_2024_share <- wide[ERG %in% fossil_commodity_sectors, sum(share_basedata_2024, na.rm = TRUE)]

# Renewable primary energy (generation * 1/0.4, already applied in extraction)
renewable_2017_output <- wide[ERG %in% renewable_sectors, sum(output_basedata_2017, na.rm = TRUE)]
renewable_2024_output <- wide[ERG %in% renewable_sectors, sum(output_basedata_2024, na.rm = TRUE)]
renewable_2017_share <- wide[ERG %in% renewable_sectors, sum(share_basedata_2017, na.rm = TRUE)]
renewable_2024_share <- wide[ERG %in% renewable_sectors, sum(share_basedata_2024, na.rm = TRUE)]

summary_rows <- data.table(
  ERG = c("Hydro_combined", "Fossil_primary", "Renewable_primary"),
  output_basedata_2017 = c(hydro_2017_output, fossil_2017_output, renewable_2017_output),
  output_basedata_2024 = c(hydro_2024_output, fossil_2024_output, renewable_2024_output),
  share_basedata_2017 = c(hydro_2017_share, fossil_2017_share, renewable_2017_share),
  share_basedata_2024 = c(hydro_2024_share, fossil_2024_share, renewable_2024_share)
)

wide_with_summary <- rbind(wide, summary_rows)

## PRINT SUMMARY
cat("========================================\n")
cat("PRIMARY ENERGY MIX COMPARISON\n")
cat("========================================\n\n")
cat(sprintf("%-20s %12s %12s %12s %12s\n",
            "Sector", "Output_2017", "Share_2017", "Output_2024", "Share_2024"))
cat(paste(rep("-", 72), collapse = ""), "\n")

for (i in seq_len(nrow(wide_with_summary))) {
  row <- wide_with_summary[i]
  cat(sprintf("%-20s %12.2f %11.2f%% %12.2f %11.2f%%\n",
              row$ERG,
              row$output_basedata_2017,
              row$share_basedata_2017 * 100,
              row$output_basedata_2024,
              row$share_basedata_2024 * 100))
}

## SAVE TO CSV
output_dir <- "C:/Users/natha/Documents/Two Brothers/enabled emissions/results"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Save long format (all data)
output_file_long <- file.path(output_dir, "primary_energy_mix.csv")
fwrite(combined, output_file_long)
cat("\nSaved long-format data to:", output_file_long, "\n")

# Save wide format with summary rows
output_file_wide <- file.path(output_dir, "primary_energy_mix_wide.csv")
fwrite(wide_with_summary, output_file_wide)
cat("Saved wide-format comparison to:", output_file_wide, "\n")

## CLEAN UP TEMP FILES
unlink("../energy_mix_tmp", recursive = TRUE)
cat("\nDone.\n")
