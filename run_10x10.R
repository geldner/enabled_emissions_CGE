## 10×10 EXPERIMENTS DRIVER SCRIPT
## This script runs all three 10×10 experiments under different FN shock levels
## to generate figures for analysis.
##
## EXPERIMENTS TO RUN:
## 1. Generation-only (fossil generation technology only)
## 2. Generation and Commodity (both fossil generation technology and commodity shocks)
## 3. Commodity-only (fossil commodity shocks only)
##
## FN SHOCK LEVELS:
## - no_fn: No fuel-neutral shocks (TnD=0, ats=0, aoall(En_Int_ind)=0)
## - low_fn: Low fuel-neutral shocks
## - medium_fn: Medium/baseline fuel-neutral shocks
## - high_fn: High fuel-neutral shocks
##
## This creates 12 total experiment combinations (3 fossil approaches × 4 FN levels)

# Add user library path
.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

# Set working directory to GTAP model location
setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/gtap_p_20by5/gtpv7AI")

cat("=================================================================\n")
cat("10×10 EXPERIMENTS - Grid Sensitivity Analysis\n")
cat("=================================================================\n")
cat("\nThis script will run 12 experiment combinations:\n")
cat("  - 3 fossil parameter approaches (generation-only, generation and commodity, commodity-only)\n")
cat("  - 4 FN levels (none, low, medium, high)\n")
cat("\nEach experiment runs 100 simulations (10×10 grid)\n")
cat("Total simulations: 1200\n")
cat("\n")

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

# Calculate shock values based on intensity parameter
calculate_shock_value <- function(intensity) {
  return(0 + 100 * intensity)
}

# Base CMF template (2024 calibrated baseline)
get_base_cmf_template <- function(experiment_name) {
  c(
    paste0("! ", experiment_name, " - 10x10 sensitivity analysis using 2024 calibrated baseline !"),
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
    paste0("Verbal Description = ", experiment_name, " ;")
  )
}

## EXPERIMENTAL DESIGN SETUP
############################

exp_design_file <- "C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/gtap_p_exp_design.csv"
exp_design <- fread(exp_design_file)

# Fix escape character issues with quotes in parameter names
exp_design$param <- gsub('""', '"', exp_design$param, fixed = TRUE)

## GRID SETUP FOR SENSITIVITY ANALYSIS
######################################

# Create 10×10 grid for sensitivity analysis
grid_size <- 10
renewable_int_values <- seq(0, 1, length.out = grid_size)
fossil_int_values <- seq(0, 1, length.out = grid_size)

# Create all combinations of the two parameters
param_grid <- expand.grid(
  renewable_int = renewable_int_values,
  fossil_int = fossil_int_values
)

# Add simulation identifiers
param_grid$sim_id <- paste0("sim_", sprintf("%03d", 1:nrow(param_grid)))

cat("Created parameter grid with", nrow(param_grid), "combinations (10×10)\n\n")

## FUNCTION TO RUN A SINGLE EXPERIMENT VARIANT
##############################################

run_experiment <- function(fossil_approach, fn_level) {

  # Determine experiment name and directories
  if(fossil_approach == "generation_only") {
    experiment_name <- paste0("10x10_", fn_level, "_fn_generation_only")
    fossil_filter <- "renewable == FALSE & fuel_neutral == FALSE & fossil_commodity == FALSE"
  } else if(fossil_approach == "gen_and_commodity") {
    experiment_name <- paste0("10x10_", fn_level, "_fn_gen_and_commodity")
    fossil_filter <- "renewable == FALSE & fuel_neutral == FALSE"
  } else if(fossil_approach == "commodity_only") {
    experiment_name <- paste0("10x10_", fn_level, "_fn_commodity_only")
    fossil_filter <- "fossil_commodity == TRUE"
  } else {
    stop("Unknown fossil_approach: ", fossil_approach)
  }

  cmf_dir <- paste0("../cmf_", experiment_name)
  run_out_dir <- paste0("../run_out_", experiment_name)

  cat("\n=================================================================\n")
  cat("STARTING EXPERIMENT:", experiment_name, "\n")
  cat("Fossil approach:", fossil_approach, "\n")
  cat("FN level:", fn_level, "\n")
  cat("=================================================================\n\n")

  # Get parameter sets
  renewable_params <- exp_design[renewable == TRUE]
  fossil_params <- exp_design[eval(parse(text = fossil_filter))]
  fuel_neutral_params <- exp_design[fuel_neutral == TRUE]

  cat("Found", nrow(renewable_params), "renewable parameters\n")
  cat("Found", nrow(fossil_params), "fossil fuel parameters\n")
  cat("Found", nrow(fuel_neutral_params), "fuel-neutral parameters\n\n")

  ## GENERATE CMF FILES
  #####################

  # Create directories
  dir.create(cmf_dir, recursive = TRUE, showWarnings = FALSE)

  # Clean up old output files
  cat("Cleaning up old output files...\n")
  old_files <- list.files(cmf_dir, pattern = "\\.(sl4|har|sol)$", full.names = TRUE, recursive = FALSE)
  if(length(old_files) > 0) {
    file.remove(old_files)
    cat("Removed", length(old_files), "old output files\n")
  }

  # Clean solfiles subdirectory
  solfiles_dir <- file.path(cmf_dir, "solfiles")
  if(dir.exists(solfiles_dir)) {
    old_solfiles <- list.files(solfiles_dir, pattern = ".*", full.names = TRUE, recursive = FALSE)
    if(length(old_solfiles) > 0) {
      file.remove(old_solfiles)
      cat("Removed", length(old_solfiles), "old files from solfiles subdirectory\n")
    }
  }

  cat("Generating CMF files for", nrow(param_grid), "simulations...\n")

  for(i in 1:nrow(param_grid)) {
    sim_id <- param_grid$sim_id[i]
    renewable_int <- param_grid$renewable_int[i]
    fossil_int <- param_grid$fossil_int[i]

    # Generate shocks for renewable parameters
    renewable_shocks <- character(0)
    if(nrow(renewable_params) > 0) {
      for(j in 1:nrow(renewable_params)) {
        shock_val <- calculate_shock_value(renewable_int)
        shock_string <- generate_shock_string(renewable_params$param[j], shock_val)
        renewable_shocks <- c(renewable_shocks, shock_string)
      }
    }

    # Generate shocks for fossil fuel parameters
    fossil_shocks <- character(0)
    if(nrow(fossil_params) > 0) {
      for(j in 1:nrow(fossil_params)) {
        shock_val <- calculate_shock_value(fossil_int)
        shock_string <- generate_shock_string(fossil_params$param[j], shock_val)
        fossil_shocks <- c(fossil_shocks, shock_string)
      }
    }

    # Generate shocks for fuel-neutral parameters
    fuel_neutral_shocks <- character(0)
    if(fn_level != "no" && nrow(fuel_neutral_params) > 0) {
      for(j in 1:nrow(fuel_neutral_params)) {
        if(fn_level == "low") {
          shock_val <- fuel_neutral_params$low[j]
        } else if(fn_level == "medium") {
          shock_val <- fuel_neutral_params$`baseline treatment`[j]
        } else if(fn_level == "high") {
          shock_val <- fuel_neutral_params$high[j]
        } else {
          stop("Unknown fn_level: ", fn_level)
        }
        shock_string <- generate_shock_string(fuel_neutral_params$param[j], shock_val)
        fuel_neutral_shocks <- c(fuel_neutral_shocks, shock_string)
      }
    }

    # Combine all shocks for this simulation
    all_shocks <- c(renewable_shocks, fossil_shocks, fuel_neutral_shocks)

    # Create CMF file for this simulation
    cmf_file <- file.path(cmf_dir, paste0(sim_id, '.cmf'))
    writeLines(c(get_base_cmf_template(experiment_name), "", all_shocks), cmf_file)

    # Progress indicator
    if(i %% 10 == 0) {
      cat("Generated", i, "of", nrow(param_grid), "CMF files\n")
    }
  }

  ## RUN SIMULATIONS
  ##################

  cat("\nStarting simulation runs...\n")

  # Track failed and skipped simulations
  failed_or_skipped_sims <- character(0)

  for(i in 1:nrow(param_grid)) {
    sim_id <- param_grid$sim_id[i]
    current_renewable_int <- param_grid$renewable_int[i]
    current_fossil_int <- param_grid$fossil_int[i]
    cmf_file <- file.path(cmf_dir, paste0(sim_id, '.cmf'))

    # Check if we should skip this simulation
    should_skip <- FALSE

    if(current_fossil_int > 0) {
      # Find the previous fossil intensity value
      fossil_int_index <- which(fossil_int_values == current_fossil_int)
      if(fossil_int_index > 1) {
        previous_fossil_int <- fossil_int_values[fossil_int_index - 1]

        # Look up the simulation with same renewable_int but previous fossil_int
        previous_sim_index <- which(
          param_grid$renewable_int == current_renewable_int &
          param_grid$fossil_int == previous_fossil_int
        )

        if(length(previous_sim_index) > 0) {
          previous_sim_id <- param_grid$sim_id[previous_sim_index]

          # Check if previous simulation failed or was skipped
          if(previous_sim_id %in% failed_or_skipped_sims) {
            should_skip <- TRUE
            cat("  Skipping", sim_id, "(renewable=", sprintf("%.3f", current_renewable_int),
                ", fossil=", sprintf("%.3f", current_fossil_int),
                ") because", previous_sim_id, "failed/skipped\n")
          }
        }
      }
    }

    if(should_skip) {
      # Add to failed/skipped set
      failed_or_skipped_sims <- c(failed_or_skipped_sims, sim_id)
    } else {
      # Create output directory for this simulation
      soldir.i <- file.path(run_out_dir, sim_id)
      dir.create(soldir.i, recursive = TRUE, showWarnings = FALSE)

      # Copy CMF file to simulation directory
      file.copy(from = cmf_file, to = soldir.i, overwrite = TRUE)

      # Run GTAP-E model
      exp <- paste0('GTAPV7-EP.exe -cmf ', cmf_file)
      result <- system(exp, ignore.stdout = TRUE)

      # Clean up GTAPDATA.UPD to avoid contaminating next simulation
      if(file.exists("GTAPDATA.UPD")) {
        file.remove("GTAPDATA.UPD")
      }

      # Check if simulation succeeded
      if(result != 0) {
        cat("  WARNING: Simulation", sim_id, "failed with exit code", result, "\n")
        failed_or_skipped_sims <- c(failed_or_skipped_sims, sim_id)
      }

      # Progress indicator
      if(i %% 10 == 0) {
        cat("Completed", i, "of", nrow(param_grid), "simulations (",
            length(failed_or_skipped_sims), "failed/skipped)\n")
      }
    }
  }

  cat("All simulations completed!\n")

  ## EXTRACT SOLUTION DATA
  ########################

  cat("\nExtracting solution data...\n")

  # Create solfiles directory
  dir.create(solfiles_dir, recursive = TRUE, showWarnings = FALSE)

  # Extract solution files for all simulations
  for(i in 1:nrow(param_grid)) {
    sim_id <- param_grid$sim_id[i]

    ext.status <- extractvar(
      solution.dir = cmf_dir,
      solution.name = paste0("/", sim_id, ".sl4"),
      solution.out = file.path(solfiles_dir, paste0(sim_id, ".sol"))
    )

    if(i %% 10 == 0) {
      cat("Extracted", i, "of", nrow(param_grid), "solution files\n")
    }
  }

  ## READ AND COMPILE RESULTS
  ###########################

  cat("Reading and compiling results...\n")

  # gco2t is header 0038 (CO2 emissions from transport)
  results_list <- list()

  for(i in 1:nrow(param_grid)) {
    sim_id <- param_grid$sim_id[i]

    # Check if solution file exists
    sol_file <- file.path(solfiles_dir, paste0(sim_id, ".sol"))
    if(!file.exists(sol_file)) {
      cat("Skipping", sim_id, "- solution file not found (simulation likely failed)\n")
      next
    }

    # Read solution data for CO2 emissions
    readsol(
      paste0(solfiles_dir, "/"),
      paste0(sim_id, ".sol"),
      file.path(solfiles_dir, paste0(sim_id, "_gco2t.csv")),
      "0038"
    )

    # Check if CSV was created successfully
    csv_file <- file.path(solfiles_dir, paste0(sim_id, "_gco2t.csv"))
    if(!file.exists(csv_file)) {
      cat("Skipping", sim_id, "- failed to extract gco2t data\n")
      next
    }

    # Load results and add metadata
    these_results <- fread(csv_file)
    these_results$sim_id <- sim_id
    these_results$renewable_int <- param_grid$renewable_int[i]
    these_results$fossil_int <- param_grid$fossil_int[i]
    these_results$fuel_neutral_level <- fn_level
    these_results$fossil_approach <- fossil_approach

    results_list[[i]] <- these_results

    if(i %% 10 == 0) {
      cat("Processed", i, "of", nrow(param_grid), "result files\n")
    }
  }

  # Combine all results into a single table
  res_table <- rbindlist(results_list)

  # Create results directory if needed
  dir.create('../results', recursive = TRUE, showWarnings = FALSE)

  # Save parameter grid and results
  param_grid_file <- paste0('../results/experiment_', experiment_name, '_parameter_grid.csv')
  results_file <- paste0('../results/experiment_', experiment_name, '_results.csv')

  fwrite(param_grid, param_grid_file)
  fwrite(res_table, results_file)

  cat("\n", experiment_name, "experiment completed successfully!\n")
  cat("Parameter grid saved to:", param_grid_file, "\n")
  cat("Results saved to:", results_file, "\n")

  # Return summary statistics
  list(
    experiment = experiment_name,
    fossil_approach = fossil_approach,
    fn_level = fn_level,
    total_sims = nrow(param_grid),
    failed_sims = length(failed_or_skipped_sims),
    result_count = nrow(res_table)
  )
}

## MAIN EXECUTION - RUN ALL EXPERIMENT COMBINATIONS
###################################################

# Define experiment combinations
fossil_approaches <- c("generation_only", "gen_and_commodity", "commodity_only")
fn_levels <- c("no", "low", "medium", "high")

# Track all experiment results
all_experiment_summaries <- list()
experiment_counter <- 1

# Run all combinations
for(fossil_approach in fossil_approaches) {
  for(fn_level in fn_levels) {
    cat("\n\n#################################################################\n")
    cat("EXPERIMENT", experiment_counter, "of 12\n")
    cat("#################################################################\n")

    summary <- run_experiment(fossil_approach, fn_level)
    all_experiment_summaries[[experiment_counter]] <- summary

    experiment_counter <- experiment_counter + 1
  }
}

## FINAL SUMMARY
################

cat("\n\n=================================================================\n")
cat("ALL 10×10 EXPERIMENTS COMPLETED!\n")
cat("=================================================================\n\n")

cat("Summary of all experiments:\n\n")
summary_table <- rbindlist(all_experiment_summaries)
print(summary_table)

cat("\n\nAll results saved to ../results/ directory\n")
cat("CMF files saved to ../cmf_10x10_*_fn* directories\n")
cat("Run outputs saved to ../run_out_10x10_*_fn* directories\n")
