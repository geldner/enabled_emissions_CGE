# Compare Energy Mix: basedata_ctax_104.har vs gsdfvole.har
# This script extracts and compares energy generation shares from two HAR files

# Add user library path
.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

# Set working directory to GTAP model location
setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_20by5/gtpv7AI/")

# ============================================================================
# UTILITY FUNCTION: Extract energy mix from a HAR file
# ============================================================================

extract_energy_mix <- function(har_file, label) {
  cat("\n========================================\n")
  cat("Extracting energy mix from:", label, "\n")
  cat("File:", har_file, "\n")
  cat("========================================\n\n")

  # Create temporary CSV file names
  prefix <- gsub("\\.har$", "", basename(har_file))
  edf_csv <- paste0("../../temp_", prefix, "_edf.csv")
  emf_csv <- paste0("../../temp_", prefix, "_emf.csv")
  edp_csv <- paste0("../../temp_", prefix, "_edp.csv")
  emp_csv <- paste0("../../temp_", prefix, "_emp.csv")

  # Extract consumption headers
  # EDF: Electricity demand by fuel type (ERG*ACTS*REG)
  # EMF: Electricity manufacturing by fuel type (ERG*ACTS*REG)
  # EDP: Electricity demand by peaking fuel type (ERG*REG)
  # EMP: Electricity manufacturing by peaking fuel type (ERG*REG)

  system(paste("har2csv", har_file, edf_csv, "EDF"), ignore.stdout = TRUE)
  system(paste("har2csv", har_file, emf_csv, "EMF"), ignore.stdout = TRUE)
  system(paste("har2csv", har_file, edp_csv, "EDP"), ignore.stdout = TRUE)
  system(paste("har2csv", har_file, emp_csv, "EMP"), ignore.stdout = TRUE)

  # Check if extraction worked
  if(!file.exists(edf_csv) || !file.exists(emf_csv) ||
     !file.exists(edp_csv) || !file.exists(emp_csv)) {
    cat("ERROR: Failed to extract energy volume data from", har_file, "\n")
    return(NULL)
  }

  # Read all four consumption headers
  edf <- fread(edf_csv)
  emf <- fread(emf_csv)
  edp <- fread(edp_csv)
  emp <- fread(emp_csv)

  # Convert Value columns to numeric
  edf[, Value := as.numeric(Value)]
  emf[, Value := as.numeric(Value)]
  edp[, Value := as.numeric(Value)]
  emp[, Value := as.numeric(Value)]

  # Sum all consumption by ERG (aggregating across ACTS and REG)
  edf_sum <- edf[, .(consumption = sum(Value)), by = .(ERG)]
  emf_sum <- emf[, .(consumption = sum(Value)), by = .(ERG)]
  edp_sum <- edp[, .(consumption = sum(Value)), by = .(ERG)]
  emp_sum <- emp[, .(consumption = sum(Value)), by = .(ERG)]

  # Combine all consumption sources by ERG
  volumes <- rbindlist(list(edf_sum, emf_sum, edp_sum, emp_sum))
  output_by_erg <- volumes[, .(total_output = sum(consumption)), by = .(ERG)]

  # Clean up temp files
  file.remove(edf_csv, emf_csv, edp_csv, emp_csv)

  return(output_by_erg)
}

# ============================================================================
# EXTRACT ENERGY MIX FROM BOTH FILES
# ============================================================================

# Extract from basedata_ctax_160.har (calibrated with carbon tax)
ctax_mix <- extract_energy_mix("basedata_ctax_160.har", "basedata_ctax_160.har (Carbon Tax Calibrated)")

# Extract from gsdfvole.har (original baseline volumes)
gsdf_mix <- extract_energy_mix("gsdfvole.har", "gsdfvole.har (Original Baseline)")

if(is.null(ctax_mix) || is.null(gsdf_mix)) {
  stop("Failed to extract energy mix from one or both files")
}

# ============================================================================
# COMPARE ENERGY MIX
# ============================================================================

cat("\n========================================\n")
cat("ENERGY MIX COMPARISON\n")
cat("========================================\n\n")

# All generation technologies
all_sectors <- c("CoalBL", "GasBL", "OilBL", "GasP", "OilP",
                 "NuclearBL", "HydroBL", "WindBL", "HydroP", "SolarP", "OtherBL")

# Calculate totals
ctax_total <- ctax_mix[ERG %in% all_sectors, sum(total_output, na.rm = TRUE)]
gsdf_total <- gsdf_mix[ERG %in% all_sectors, sum(total_output, na.rm = TRUE)]

# Build comparison table
comparison <- data.table(
  Technology = character(),
  GSDF_Output = numeric(),
  GSDF_Share = numeric(),
  CTAX_Output = numeric(),
  CTAX_Share = numeric(),
  Output_Change = numeric(),
  Share_Change = numeric()
)

cat(sprintf("%-12s | %12s %7s | %12s %7s | %12s %7s\n",
            "Technology", "GSDF Output", "Share", "CTAX Output", "Share", "Change", "Diff"))
cat(paste(rep("-", 85), collapse = ""), "\n")

for(tech in all_sectors) {
  gsdf_output <- gsdf_mix[ERG == tech, sum(total_output, na.rm = TRUE)]
  ctax_output <- ctax_mix[ERG == tech, sum(total_output, na.rm = TRUE)]

  gsdf_share <- (gsdf_output / gsdf_total) * 100
  ctax_share <- (ctax_output / ctax_total) * 100

  output_change <- ctax_output - gsdf_output
  share_change <- ctax_share - gsdf_share

  comparison <- rbind(comparison, data.table(
    Technology = tech,
    GSDF_Output = gsdf_output,
    GSDF_Share = round(gsdf_share, 2),
    CTAX_Output = ctax_output,
    CTAX_Share = round(ctax_share, 2),
    Output_Change = round(output_change, 2),
    Share_Change = round(share_change, 2)
  ))

  cat(sprintf("%-12s | %12.2f %6.2f%% | %12.2f %6.2f%% | %+12.2f %+6.2f%%\n",
              tech, gsdf_output, gsdf_share, ctax_output, ctax_share, output_change, share_change))
}

cat(paste(rep("-", 85), collapse = ""), "\n")
cat(sprintf("%-12s | %12.2f %7s | %12.2f %7s | %+12.2f\n",
            "TOTAL", gsdf_total, "100%", ctax_total, "100%", ctax_total - gsdf_total))

# ============================================================================
# COMBINED CATEGORIES
# ============================================================================

cat("\n\nCombined Categories:\n")
cat(paste(rep("-", 85), collapse = ""), "\n")

# Fossil
gsdf_fossil <- gsdf_mix[ERG %in% c("CoalBL", "GasBL", "OilBL", "GasP", "OilP"), sum(total_output, na.rm = TRUE)]
ctax_fossil <- ctax_mix[ERG %in% c("CoalBL", "GasBL", "OilBL", "GasP", "OilP"), sum(total_output, na.rm = TRUE)]
cat(sprintf("%-12s | %12.2f %6.2f%% | %12.2f %6.2f%% | %+12.2f %+6.2f%%\n",
            "Fossil", gsdf_fossil, (gsdf_fossil/gsdf_total)*100,
            ctax_fossil, (ctax_fossil/ctax_total)*100,
            ctax_fossil - gsdf_fossil, (ctax_fossil/ctax_total - gsdf_fossil/gsdf_total)*100))

# Hydro (combined)
gsdf_hydro <- gsdf_mix[ERG %in% c("HydroBL", "HydroP"), sum(total_output, na.rm = TRUE)]
ctax_hydro <- ctax_mix[ERG %in% c("HydroBL", "HydroP"), sum(total_output, na.rm = TRUE)]
cat(sprintf("%-12s | %12.2f %6.2f%% | %12.2f %6.2f%% | %+12.2f %+6.2f%%\n",
            "Hydro", gsdf_hydro, (gsdf_hydro/gsdf_total)*100,
            ctax_hydro, (ctax_hydro/ctax_total)*100,
            ctax_hydro - gsdf_hydro, (ctax_hydro/ctax_total - gsdf_hydro/gsdf_total)*100))

# All Renewables (non-fossil)
gsdf_renew <- gsdf_mix[ERG %in% c("NuclearBL", "HydroBL", "WindBL", "HydroP", "SolarP", "OtherBL"), sum(total_output, na.rm = TRUE)]
ctax_renew <- ctax_mix[ERG %in% c("NuclearBL", "HydroBL", "WindBL", "HydroP", "SolarP", "OtherBL"), sum(total_output, na.rm = TRUE)]
cat(sprintf("%-12s | %12.2f %6.2f%% | %12.2f %6.2f%% | %+12.2f %+6.2f%%\n",
            "Renewables", gsdf_renew, (gsdf_renew/gsdf_total)*100,
            ctax_renew, (ctax_renew/ctax_total)*100,
            ctax_renew - gsdf_renew, (ctax_renew/ctax_total - gsdf_renew/gsdf_total)*100))

# ============================================================================
# SAVE RESULTS
# ============================================================================

fwrite(comparison, "../../energy_mix_comparison.csv")
cat("\n\nComparison saved to: energy_mix_comparison.csv\n")
