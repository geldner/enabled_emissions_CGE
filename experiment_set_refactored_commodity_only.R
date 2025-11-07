## REFACTORED EXPERIMENTAL DESIGN - COMMODITY ONLY VERSION
## This R script implements a 4x4x4 experimental design with three dimensions:
## 1. Renewable technology shock level (none/low/medium/high)
## 2. Fossil fuel COMMODITY shock level (none/low/medium/high) - EXTRACTION/PRODUCTION ONLY
## 3. Fuel-neutral shock level (none/low/baseline/high)
##
## KEY DIFFERENCE: Fossil shocks include ONLY commodity shocks (Coal, Oil, Gas afeall)
## This version EXCLUDES fossil generation technology shocks (CoalBL, GasBL, OilBL, GasP, OilP)
## to avoid double-counting fossil fuel improvements in both extraction and generation.
##
## Fuel-neutral shocks include:
## - none: No TnD, ats, or aoall(En_Int_ind) shocks
## - low: TnD + ats + aoall(En_Int_ind) at low levels
## - baseline: TnD + ats + aoall(En_Int_ind) at baseline treatment levels
## - high: TnD + ats + aoall(En_Int_ind) at high levels
##
## Total simulations: 64 (4 × 4 × 4)
## Note: The none/none/none case (no shocks at all) is skipped and synthetic results are created

# Add user library path
.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

# Set working directory to GTAP model location (20x5 aggregation with 2024 calibrated baseline)
setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/gtap_p_20by5/gtpv7AI")

## UTILITY FUNCTIONS
####################

# Extract variables from solution files using GEMPACK's sltoht utility
extractvar <- function (solution.dir, solution.name, solution.out){
  system(
    paste("sltoht",
          paste(solution.dir,solution.name,sep=""),
          solution.out),
    ignore.stdout = TRUE
  )
}

# Read specific header of solution files, convert them into CSV files, and read them into R
readsol <- function (solution.dir, solution.out, csv.out, header){
  har2csv.status <- system(
    paste("har2csv",
          paste(solution.dir,solution.out, sep=""),
          csv.out, header, sep=" "),
    ignore.stdout = TRUE
  )
  if( har2csv.status == 0){
    y  <- read.csv(csv.out)
  }else{
    y <- NA
  }
}

# Generate shock strings for GEMPACK CMF files
generate_shock_string <- function(param, val) {
  paste0("Shock ", param, " = uniform ", val, ";")
}

# Function to append strings to a text file as additional lines
append_to_file <- function(input_file, output_file, strings_to_append) {
  if (file.exists(input_file)) {
    existing_content <- readLines(input_file, warn = FALSE)
  } else {
    existing_content <- character(0)
  }
  combined_content <- unlist(c(existing_content, strings_to_append))
  writeLines(combined_content, output_file)
}

## EXPERIMENTAL DESIGN SETUP
############################

exp_design_file <- "C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/gtap_p_exp_design.csv"
exp_design <- fread(exp_design_file)

# Fix escape character issues with quotes in parameter names
exp_design$param <- gsub('""', '"', exp_design$param, fixed = TRUE)

# Separate parameters into three categories
# NOTE: This version includes ONLY fossil COMMODITY shocks, excluding fossil generation technology shocks
renewable_params <- exp_design[renewable == TRUE]
fossil_params <- exp_design[fossil_commodity == TRUE]  # ONLY commodity shocks (Coal, Oil, Gas)
fuel_neutral_params <- exp_design[fuel_neutral == TRUE]

cat("Found", nrow(renewable_params), "renewable parameters\n")
cat("Found", nrow(fossil_params), "fossil fuel COMMODITY parameters (extraction/production only)\n")
cat("Found", nrow(fuel_neutral_params), "fuel-neutral parameters\n")

## GRID SETUP FOR EXPERIMENTAL DESIGN
######################################

# Create 4x4x4 grid
renewable_levels <- c("none", "low", "medium", "high")
fossil_levels <- c("none", "low", "medium", "high")
fuel_neutral_levels <- c("none", "low", "baseline", "high")

# Create all combinations
param_grid <- expand.grid(
  renewable_level = renewable_levels,
  fossil_level = fossil_levels,
  fuel_neutral_level = fuel_neutral_levels,
  stringsAsFactors = FALSE
)

# Add simulation identifiers
param_grid$sim_id <- paste0("sim_", sprintf("%02d", 1:nrow(param_grid)))

# Flag the no-shocks case (none/none/none) for special handling
param_grid$is_no_shocks <- (param_grid$renewable_level == "none" &
                             param_grid$fossil_level == "none" &
                             param_grid$fuel_neutral_level == "none")

cat("Created parameter grid with", nrow(param_grid), "combinations (4×4×4)\n")
cat("No-shocks case (none/none/none) will be handled synthetically\n")
cat("Total simulations to run:", sum(!param_grid$is_no_shocks), "\n")

## SHOCK CALCULATION FUNCTION
#############################

# Calculate shock values based on level
calculate_shock_value <- function(param_row, level) {
  if(level == "none") {
    return(0)  # No shock
  } else if(level == "low") {
    return(param_row$low)
  } else if(level == "medium" || level == "baseline") {
    return(param_row$`baseline treatment`)
  } else if(level == "high") {
    return(param_row$high)
  } else {
    stop("Invalid level: must be 'none', 'low', 'medium', 'high', or 'baseline'")
  }
}

# Base CMF template (2024 calibrated baseline)
# The calibrated GTAPDATA file includes renewable efficiency shocks that achieve
# a fossil fuel share of ~60%, matching 2024 real-world data
base_cmf_template <- c(
  "! Experimental design CMF file (commodity shocks only) using 2024 calibrated baseline !",
  "auxiliary files = gtapv7-ep;",
  "check-on-read elements = warn;",
  "cpu=yes ;",
  "log file = yes;",
  "start with MMNZ = 200000000;",
  "!servants = 1;",
  "",
  "! Input files - using 2024 calibrated baseline:",
  "File GTAPSETS = sets.har;",
  "File GTAPDATA = basedata_2024.har;",
  "File GTAPPARM = default.prm;",
  "! Output files:",
  "File GTAPSUM = <cmf>-SUM.har;",
  "File WELVIEW = <cmf>-WEL.har;",
  "File GTAPVOL = <cmf>-VOL.har;",
  "! Updated files:",
  "Updated File GTAPDATA = GTAPDATA.UPD;",
  "Solution file = <cmf>.sl4;",
  "",
  "! Solution method - maximum accuracy settings",
  "method = gragg ;",
  "steps = 2 4 6 ;",
  "subintervals = 10;",
  "automatic accuracy = yes;",
  "",
  "! Standard GTAP closure: psave varies by region, pfactwld is numeraire",
  "Exogenous",
  "          pop",
  "          psaveslack pfactwld",
  "          profitslack incomeslack endwslack",
  "          cgdslack",
  "          tradslack",
  "          ams atm atf ats atd",
  "          aosec aoreg",
  "          afcom afsec afreg afecom afesec afereg",
  "          aoall afall afeall",
  "          au dppriv dpgov dpsave",
  "          to tinc",
  "          tpreg tm tms tx txs",
  "          qe",
  "          qesf",
  "! Additional exogenous variables for GTAP-E",
  "          del_ctgshr del_rctaxb pemp",
  "",
  "          ;",
  "Rest endogenous;",
  "",
  "Verbal Description = Experimental design shock ;"
)

## GENERATE CMF FILES FOR EACH SIMULATION
#########################################

# Create CMF directory if it doesn't exist
dir.create('../cmf_refactored_commodity_only', recursive = TRUE, showWarnings = FALSE)

# Clear old output files from previous runs to avoid reading stale results
cat("Cleaning up old output files from cmf_refactored_commodity_only directory...\n")
old_files <- list.files('../cmf_refactored_commodity_only', pattern = "\\.(sl4|har|sol)$", full.names = TRUE, recursive = FALSE)
if(length(old_files) > 0) {
  file.remove(old_files)
  cat("Removed", length(old_files), "old output files\n")
}

# Clear old files from solfiles subdirectory
if(dir.exists('../cmf_refactored_commodity_only/solfiles')) {
  old_solfiles <- list.files('../cmf_refactored_commodity_only/solfiles', pattern = ".*", full.names = TRUE, recursive = FALSE)
  if(length(old_solfiles) > 0) {
    file.remove(old_solfiles)
    cat("Removed", length(old_solfiles), "old files from solfiles subdirectory\n")
  }
}

cat("Generating CMF files for", sum(!param_grid$is_no_shocks), "simulations...\n")
cat("(Skipping no-shocks case)\n")

for(i in 1:nrow(param_grid)) {
  # Skip the no-shocks case
  if(param_grid$is_no_shocks[i]) {
    cat("Skipping sim_id", param_grid$sim_id[i], "(none/none/none - no shocks case)\n")
    next
  }

  sim_id <- param_grid$sim_id[i]
  renewable_level <- param_grid$renewable_level[i]
  fossil_level <- param_grid$fossil_level[i]
  fuel_neutral_level <- param_grid$fuel_neutral_level[i]

  # Generate shocks for renewable parameters
  renewable_shocks <- character(0)
  if(nrow(renewable_params) > 0) {
    for(j in 1:nrow(renewable_params)) {
      shock_val <- calculate_shock_value(renewable_params[j,], renewable_level)
      shock_string <- generate_shock_string(renewable_params$param[j], shock_val)
      renewable_shocks <- c(renewable_shocks, shock_string)
    }
  }

  # Generate shocks for fossil fuel parameters
  fossil_shocks <- character(0)
  if(nrow(fossil_params) > 0) {
    for(j in 1:nrow(fossil_params)) {
      shock_val <- calculate_shock_value(fossil_params[j,], fossil_level)
      shock_string <- generate_shock_string(fossil_params$param[j], shock_val)
      fossil_shocks <- c(fossil_shocks, shock_string)
    }
  }

  # Generate shocks for fuel-neutral parameters
  fuel_neutral_shocks <- character(0)
  if(nrow(fuel_neutral_params) > 0) {
    for(j in 1:nrow(fuel_neutral_params)) {
      # For fuel-neutral level:
      # - "none": no shocks (0)
      # - "low": TnD + ats + aoall(En_Int_ind) at low levels
      # - "baseline": TnD + ats + aoall(En_Int_ind) at baseline treatment
      # - "high": TnD + ats + aoall(En_Int_ind) at high levels

      param_name <- fuel_neutral_params$param[j]

      if(fuel_neutral_level == "none") {
        # Skip all fuel-neutral shocks
        next
      } else if(fuel_neutral_level == "low") {
        shock_val <- fuel_neutral_params$low[j]
      } else if(fuel_neutral_level == "baseline") {
        shock_val <- fuel_neutral_params$`baseline treatment`[j]
      } else if(fuel_neutral_level == "high") {
        shock_val <- fuel_neutral_params$high[j]
      }

      shock_string <- generate_shock_string(param_name, shock_val)
      fuel_neutral_shocks <- c(fuel_neutral_shocks, shock_string)
    }
  }

  # Combine all shocks for this simulation
  all_shocks <- c(renewable_shocks, fossil_shocks, fuel_neutral_shocks)

  # Create CMF file for this simulation
  cmf_file <- paste0('../cmf_refactored_commodity_only/', sim_id, '.cmf')
  writeLines(c(base_cmf_template, "", all_shocks), cmf_file)

  # Progress indicator
  cat("Generated CMF", i, "of", nrow(param_grid), ":",
      renewable_level, "/", fossil_level, "/", fuel_neutral_level, "\n")
}

## RUN SIMULATIONS
##################

cat("\nStarting simulation runs...\n")

sims_to_run <- which(!param_grid$is_no_shocks)
for(i in seq_along(sims_to_run)) {
  row_idx <- sims_to_run[i]
  sim_id <- param_grid$sim_id[row_idx]
  cmf_file <- paste0('../cmf_refactored_commodity_only/', sim_id, '.cmf')

  # Create output directory for this simulation
  soldir.i <- paste0("../run_out_refactored_commodity_only/", sim_id)
  dir.create(soldir.i, recursive = TRUE, showWarnings = FALSE)

  # Copy CMF file to simulation directory
  file.copy(from = cmf_file, to = soldir.i, overwrite = TRUE)

  # Run GTAP model
  exp <- paste0('GTAPV7-EP.exe -cmf ', cmf_file)
  system(exp, ignore.stdout = TRUE)
  #system(exp, ignore.stdout = FALSE)

  # Move output files to run_out_refactored_commodity_only directory
  # if(file.exists(paste0(sim_id, '.sl4'))) {
  #   file.copy(paste0('../cmf_refactored_commodity_only/',sim_id, '.sl4'), paste0('../run_out_refactored_commodity_only/', sim_id, '/', sim_id, '.sl4'), overwrite = TRUE)
  # }
  # if(file.exists(paste0(sim_id, '-VOL.har'))) {
  #   file.copy(paste0('../cmf_refactored_commodity_only/',sim_id, '-VOL.har'), paste0('../run_out_refactored_commodity_only/', sim_id, '/', sim_id, '-VOL.har'), overwrite = TRUE)
  # }
  # if(file.exists(paste0(sim_id, '-SUM.har'))) {
  #   file.copy(paste0('../cmf_refactored_commodity_only/',sim_id, '-SUM.har'), paste0('../run_out_refactored_commodity_only/', sim_id, '/', sim_id, '-SUM.har'), overwrite = TRUE)
  # }
  # if(file.exists(paste0(sim_id, '-WEL.har'))) {
  #   file.copy(paste0('../cmf_refactored_commodity_only/',sim_id, '-WEL.har'), paste0('../run_out_refactored_commodity_only/', sim_id, '/', sim_id, '-WEL.har'), overwrite = TRUE)
  # }

  # Clean up GTAPDATA.UPD to avoid contaminating next simulation
  if(file.exists("GTAPDATA.UPD")) {
    file.remove("GTAPDATA.UPD")
  }

  # Progress indicator
  cat("Completed simulation", i, "of", length(sims_to_run), "\n")
}

cat("All simulations completed!\n")

## EXTRACT SOLUTION DATA
########################

cat("\nExtracting solution data...\n")

# Create solfiles directory if it doesn't exist
dir.create('../cmf_refactored_commodity_only/solfiles', recursive = TRUE, showWarnings = FALSE)

# Extract solution files for all simulations (skip no-shocks case)
for(i in seq_along(sims_to_run)) {
  row_idx <- sims_to_run[i]
  sim_id <- param_grid$sim_id[row_idx]

  ext.status <- extractvar(
    solution.dir = paste0("../cmf_refactored_commodity_only"),
    solution.name = paste0("/", sim_id, ".sl4"),
    solution.out = paste0("../cmf_refactored_commodity_only/solfiles/", sim_id, ".sol")
  )

  if(i %% 10 == 0) {
    cat("Extracted", i, "of", length(sims_to_run), "solution files\n")
  }
}

## READ AND COMPILE RESULTS
###########################

cat("Reading and compiling results...\n")

# gco2t is header 0038 (CO2 emissions from transport)
results_list <- list()

for(i in 1:nrow(param_grid)) {
  sim_id <- param_grid$sim_id[i]

  # Handle no-shocks case specially - create synthetic zero-change results
  if(param_grid$is_no_shocks[i]) {
    cat("Creating synthetic zero-change results for", sim_id, "(none/none/none)\n")

    # Get structure from any other simulation (use sim_02 as template)
    template_sim <- param_grid$sim_id[2]
    readsol(
      paste0("../cmf_refactored_commodity_only/solfiles/"),
      paste0(template_sim, ".sol"),
      paste0("../cmf_refactored_commodity_only/solfiles/", template_sim, "_gco2t.csv"),
      "0038"
    )
    template_results <- fread(paste0("../cmf_refactored_commodity_only/solfiles/", template_sim, "_gco2t.csv"))

    # Create zero-change version
    these_results <- copy(template_results)
    # Set all value columns to 0 (no change from baseline)
    value_cols <- names(these_results)[sapply(these_results, is.numeric)]
    these_results[, (value_cols) := 0]

    these_results$sim_id <- sim_id
    these_results$renewable_level <- param_grid$renewable_level[i]
    these_results$fossil_level <- param_grid$fossil_level[i]
    these_results$fuel_neutral_level <- param_grid$fuel_neutral_level[i]

    results_list[[i]] <- these_results
    next
  }

  # Read solution data for CO2 emissions
  readsol(
    paste0("../cmf_refactored_commodity_only/solfiles/"),
    paste0(sim_id, ".sol"),
    paste0("../cmf_refactored_commodity_only/solfiles/", sim_id, "_gco2t.csv"),
    "0038"
  )

  # Load results and add metadata
  these_results <- fread(paste0("../cmf_refactored_commodity_only/solfiles/", sim_id, "_gco2t.csv"))
  these_results$sim_id <- sim_id
  these_results$renewable_level <- param_grid$renewable_level[i]
  these_results$fossil_level <- param_grid$fossil_level[i]
  these_results$fuel_neutral_level <- param_grid$fuel_neutral_level[i]

  results_list[[i]] <- these_results

  if(i %% 10 == 0) {
    cat("Processed", i, "of", nrow(param_grid), "result files\n")
  }
}

# Combine all results into a single table
res_table <- rbindlist(results_list)

# Create results directory if needed
dir.create('../results', recursive = TRUE, showWarnings = FALSE)

# Save parameter grid for reference
fwrite(param_grid, '../results/experiment_refactored_commodity_only_parameter_grid.csv')

# Save compiled results
fwrite(res_table, '../results/experiment_refactored_commodity_only_results.csv')

cat("\nFactorial Scenario experiment completed successfully!\n")
cat("Parameter grid saved to: ../results/experiment_refactored_commodity_only_parameter_grid.csv\n")
cat("Results saved to: ../results/experiment_refactored_commodity_only_results.csv\n")

## SUMMARY STATISTICS
#####################

cat("\nSummary of Commodity-Only Experiment:\n")
cat("Total parameter combinations:", nrow(param_grid), "(4×4×4)\n")
cat("Simulations actually run:", length(sims_to_run), "(excluding none/none/none)\n")
cat("Renewable levels:", paste(unique(param_grid$renewable_level), collapse=", "), "\n")
cat("Fossil fuel levels:", paste(unique(param_grid$fossil_level), collapse=", "), "\n")
cat("Fuel-neutral levels:", paste(unique(param_grid$fuel_neutral_level), collapse=", "), "\n")
cat("Number of renewable parameters:", nrow(renewable_params), "\n")
cat("Number of fossil fuel parameters:", nrow(fossil_params), "\n")
cat("Number of fuel-neutral parameters:", nrow(fuel_neutral_params), "\n")
cat("Total observations in results:", nrow(res_table), "\n")
cat("\nNote: The none/none/none case has synthetic zero-change results\n")
