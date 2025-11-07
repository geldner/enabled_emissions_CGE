## ITERATIVE RENEWABLE CALIBRATION FROM 2017 TO 2024 LEVELS
## This script iteratively applies renewable technology efficiency shocks (aoall) to match
## 2024 generation shares for each individual renewable technology.
##
## Base Year: 2017 (GTAP database year)
## Target Year: 2024 (7 years forward)
## Target: Match 2024 generation shares from Our World in Data / Ember (2024)
##
## Target generation shares (% of total electricity):
## - NuclearBL: 9%
## - HydroBL + HydroP (combined): 16%
## - WindBL: 8%
## - SolarP: 5%
## - OtherBL: 0.5%
## - Fossil (CoalBL + GasBL + OilBL + GasP + OilP): 61.5%
##
## Approach:
## 1. Start with all renewable technology shocks = 0
## 2. At each iteration, find the renewable technology furthest below its target (proportionally)
## 3. Increment that technology's aoall shock by 10
## 4. Run simulation and extract generation shares
## 5. Repeat until all technologies reach or surpass their targets
## 6. Note: HydroBL and HydroP are shocked together to hit combined 16% target


# Add user library path
.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

# Set working directory to GTAP model location
setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/gtap_p_20by5/gtpv7AI")

## CONFIGURATION
################

# Read baseline data from CSV to calculate target shares
baseline_csv <- "C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/baseline_data.csv"
baseline_data <- fread(baseline_csv)

# Get 2024 data (last row)
baseline_2024 <- baseline_data[Year == 2024]

# Extract values from CSV (using the first set of columns)
other_renewables <- baseline_2024$`Other renewables excluding bioenergy - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
bioenergy <- baseline_2024$`Electricity from bioenergy - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
solar <- baseline_2024$`Electricity from solar - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
wind <- baseline_2024$`Electricity from wind - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
hydro <- baseline_2024$`Electricity from hydro - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
nuclear <- baseline_2024$`Electricity from nuclear - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
oil <- baseline_2024$`Electricity from oil - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
gas <- baseline_2024$`Electricity from gas - TWh (adapted for visualization of chart electricity-prod-source-stacked)`
coal <- baseline_2024$`Electricity from coal - TWh (adapted for visualization of chart electricity-prod-source-stacked)`

# Calculate total generation
total_generation_2024 <- other_renewables + bioenergy + solar + wind + hydro + nuclear + oil + gas + coal

# Calculate target generation shares (2024 levels from Our World in Data / Ember 2024)
# Note: Hydro target is for combined HydroBL + HydroP
# Note: OtherBL target is for combined bioenergy + other renewables
TARGET_SHARES <- list(
  NuclearBL = nuclear / total_generation_2024,
  Hydro = hydro / total_generation_2024,       # combined HydroBL + HydroP
  WindBL = wind / total_generation_2024,
  SolarP = solar / total_generation_2024,
  OtherBL = (bioenergy + other_renewables) / total_generation_2024  # combined bioenergy + other renewables
)


# Shock increment
SHOCK_INCREMENT <- 10

# Maximum iterations (safety limit)
MAX_ITERATIONS <- 500

## UTILITY FUNCTIONS
####################

# Extract variables from solution files
extractvar <- function(solution.dir, solution.name, solution.out){
  system(
    paste("sltoht",
          paste(solution.dir, solution.name, sep=""),
          solution.out),
    ignore.stdout = TRUE
  )
}

# Read specific header of solution files
readsol <- function(solution.dir, solution.out, csv.out, header){
  har2csv.status <- system(
    paste("har2csv",
          paste(solution.dir, solution.out, sep=""),
          csv.out, header, sep=" "),
    ignore.stdout = TRUE
  )
  if(har2csv.status == 0){
    y <- read.csv(csv.out)
  } else {
    y <- NA
  }
  return(y)
}

# Generate shock strings for CMF files
generate_shock_string <- function(param, val) {
  paste0("Shock ", param, " = uniform ", val, ";")
}

# Append strings to a text file
append_to_file <- function(input_file, output_file, strings_to_append) {
  if (file.exists(input_file)) {
    existing_content <- readLines(input_file, warn = FALSE)
  } else {
    existing_content <- character(0)
  }
  combined_content <- unlist(c(existing_content, strings_to_append))
  writeLines(combined_content, output_file)
}

## LOAD EXPERIMENTAL DESIGN
###########################

exp_design_file <- "C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/gtap_p_exp_design.csv"
exp_design <- fread(exp_design_file)

# Fix escape character issues
exp_design$param <- gsub('""', '"', exp_design$param, fixed = TRUE)

# Get renewable parameters only (we'll use aoall shocks)
renewable_params <- exp_design[renewable == TRUE]

cat("Found", nrow(renewable_params), "renewable parameters\n")
cat("\nTarget generation shares:\n")
for(tech in names(TARGET_SHARES)) {
  cat("  ", tech, ":", TARGET_SHARES[[tech]] * 100, "%\n")
}
cat("\n")

## ITERATIVE CALIBRATION LOOP
##############################

# Base CMF file template (we'll use the test_baseline.cmf structure)
# Create a base CMF without shocks
base_cmf_template <- c(
  "! This CMF file is used for iterative calibration !",
  "auxiliary files = gtapv7-ep;",
  "check-on-read elements = warn;",
  "cpu=yes ;",
  "log file = yes;",
  "start with MMNZ = 200000000;",
  "",
  "! Input files:",
  "File GTAPSETS = sets.har;",
  "File GTAPDATA = basedata.har;",
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
  "steps = 4 6 8 ;",
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
  "Verbal Description = Iterative renewable calibration ;"
)

# Create output directories
dir.create('../iterative_calibration', recursive = TRUE, showWarnings = FALSE)
dir.create('../iterative_calibration/solfiles', recursive = TRUE, showWarnings = FALSE)
dir.create('../results', recursive = TRUE, showWarnings = FALSE)

# Initialize shock values for each renewable technology
shock_values <- list(
  NuclearBL = 0,
  HydroBL = 0,    # These two shocked together
  HydroP = 0,     # These two shocked together
  WindBL = 0,
  SolarP = 0,
  OtherBL = 0
)

# Initialize
iteration <- 1
converged <- FALSE
convergence_log <- data.table()

cat("========================================\n")
cat("ITERATIVE RENEWABLE CALIBRATION\n")
cat("========================================\n\n")

while(!converged && iteration <= MAX_ITERATIONS) {

  cat("Iteration", iteration, "\n")
  cat("  Current shocks:\n")
  for(tech in names(shock_values)) {
    if(shock_values[[tech]] > 0) {
      cat("    ", tech, ":", shock_values[[tech]], "\n")
    }
  }
  if(all(unlist(shock_values) == 0)) {
    cat("    (all shocks = 0, running baseline)\n")
  }

  ## Generate CMF file with current shock level
  sim_id <- paste0("iter_", sprintf("%03d", iteration))

  # Check if all shocks are zero (baseline case)
  all_shocks_zero <- all(unlist(shock_values) == 0)

  if(all_shocks_zero) {
    cat("  All shocks are zero - extracting baseline data directly from basedata.har\n")

    # No simulation needed, just extract baseline MAKES directly
    # We'll set a flag to handle this differently in extraction

  } else {
    # Generate renewable shocks (only include non-zero shocks)
    renewable_shocks <- character(0)
    for(tech in names(shock_values)) {
      if(shock_values[[tech]] > 0) {
        # Generate aoall shock for this technology
        shock_param <- paste0('aoall("', tech, '",REG)')
        shock_string <- generate_shock_string(shock_param, shock_values[[tech]])
        renewable_shocks <- c(renewable_shocks, shock_string)
      }
    }

    # Create CMF file
    cmf_file <- paste0('../iterative_calibration/', sim_id, '.cmf')
    writeLines(c(base_cmf_template, "", renewable_shocks), cmf_file)

    ## Run simulation
    cat("  Running simulation...\n")

    # Run GTAP with CMF file (output files will be created in ../iterative_calibration/)
    run_cmd <- paste0('GTAPV7-EP.exe -cmf ', cmf_file)
    system(run_cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)

    ## Backup the GTAPDATA.UPD for this iteration
    if(file.exists("GTAPDATA.UPD")) {
      file.copy("GTAPDATA.UPD", paste0('../iterative_calibration/', sim_id, '_GTAPDATA.UPD'), overwrite = TRUE)
      cat("  Backed up GTAPDATA.UPD to ", sim_id, "_GTAPDATA.UPD\n", sep="")
    }
  }

  cat("  Calculating generation shares...\n")

  # Step 1: Extract baseline volumes from gsdfvole.har on first iteration only
  if(iteration == 1) {
    cat("  Extracting baseline volume data from gsdfvole.har...\n")
    # Make sure directory exists
    dir.create('../iterative_calibration', recursive = TRUE, showWarnings = FALSE)

    # Extract consumption headers from gsdfvole.har
    # EDF: Electricity demand by fuel type (ERG*ACTS*REG)
    # EMF: Electricity manufacturing by fuel type (ERG*ACTS*REG)
    # EDP: Electricity demand by peaking fuel type (ERG*REG)
    # EMP: Electricity manufacturing by peaking fuel type (ERG*REG)
    system(paste("har2csv", "gsdfvole.har", "../iterative_calibration/baseline_edf.csv", "EDF"),
           ignore.stdout = TRUE)
    system(paste("har2csv", "gsdfvole.har", "../iterative_calibration/baseline_emf.csv", "EMF"),
           ignore.stdout = TRUE)
    system(paste("har2csv", "gsdfvole.har", "../iterative_calibration/baseline_edp.csv", "EDP"),
           ignore.stdout = TRUE)
    system(paste("har2csv", "gsdfvole.har", "../iterative_calibration/baseline_emp.csv", "EMP"),
           ignore.stdout = TRUE)

    # Check if extraction worked
    if(!file.exists("../iterative_calibration/baseline_edf.csv") ||
       !file.exists("../iterative_calibration/baseline_emf.csv") ||
       !file.exists("../iterative_calibration/baseline_edp.csv") ||
       !file.exists("../iterative_calibration/baseline_emp.csv")) {
      cat("  ERROR: Failed to extract baseline volume data from gsdfvole.har\n")
      cat("  Current working directory:", getwd(), "\n")
      stop("Cannot proceed without baseline data")
    }
  }

  # Step 2: Read baseline volumes and sum by ERG (fuel/technology type)
  if(!file.exists("../iterative_calibration/baseline_edf.csv")) {
    cat("  ERROR: baseline volume files not found!\n")
    cat("  Current working directory:", getwd(), "\n")
    stop("Cannot proceed without baseline data")
  }

  # Read all four consumption headers
  baseline_edf <- fread("../iterative_calibration/baseline_edf.csv")
  baseline_emf <- fread("../iterative_calibration/baseline_emf.csv")
  baseline_edp <- fread("../iterative_calibration/baseline_edp.csv")
  baseline_emp <- fread("../iterative_calibration/baseline_emp.csv")

  # Convert Value columns to numeric (har2csv may output as character)
  baseline_edf[, Value := as.numeric(Value)]
  baseline_emf[, Value := as.numeric(Value)]
  baseline_edp[, Value := as.numeric(Value)]
  baseline_emp[, Value := as.numeric(Value)]

  # EDF and EMF have columns: ERG, ACTS, REG, Value
  # EDP and EMP have columns: ERG, REG, Value
  # Sum all consumption by ERG and REG (keeping regional dimension)
  baseline_edf_sum <- baseline_edf[, .(consumption = sum(Value)), by = .(ERG, REG)]
  baseline_emf_sum <- baseline_emf[, .(consumption = sum(Value)), by = .(ERG, REG)]
  baseline_edp_sum <- baseline_edp[, .(consumption = sum(Value)), by = .(ERG, REG)]
  baseline_emp_sum <- baseline_emp[, .(consumption = sum(Value)), by = .(ERG, REG)]

  # Combine all consumption sources by ERG and REG
  baseline_volumes <- rbindlist(list(baseline_edf_sum, baseline_emf_sum, baseline_edp_sum, baseline_emp_sum))
  baseline_by_erg_reg <- baseline_volumes[, .(baseline_output = sum(consumption)), by = .(ERG, REG)]

  # Step 3: Handle baseline case (no shocks) vs shocked case differently
  if(all_shocks_zero) {
    cat("  Using baseline data directly (no shocks applied)\n")

    # For baseline, final output = baseline output at ERG-REG level
    output_by_erg_reg <- baseline_by_erg_reg[, .(
      ERG = ERG,
      REG = REG,
      baseline_output = baseline_output,
      final_output = baseline_output,  # Same as baseline
      pct_change = 0
    )]

  } else {
    # Extract updated volumes from GTAPDATA.UPD file
    cat("  Extracting updated volumes from GTAPDATA.UPD...\n")

    upd_file <- paste0('../iterative_calibration/', sim_id, '_GTAPDATA.UPD')

    if(file.exists(upd_file)) {
      # Extract consumption headers from updated data (same process as baseline)
      # We'll extract to temporary files with iteration-specific names
      # Note: Header names in .UPD files are EFD/EFM (not EDF/EMF)
      updated_efd_csv <- paste0("../iterative_calibration/", sim_id, "_efd.csv")
      updated_efm_csv <- paste0("../iterative_calibration/", sim_id, "_efm.csv")
      updated_edp_csv <- paste0("../iterative_calibration/", sim_id, "_edp.csv")
      updated_emp_csv <- paste0("../iterative_calibration/", sim_id, "_emp.csv")

      system(paste("har2csv", upd_file, updated_efd_csv, "EFD"), ignore.stdout = FALSE)
      system(paste("har2csv", upd_file, updated_efm_csv, "EFM"), ignore.stdout = FALSE)
      system(paste("har2csv", upd_file, updated_edp_csv, "EDP"), ignore.stdout = FALSE)
      system(paste("har2csv", upd_file, updated_emp_csv, "EMP"), ignore.stdout = FALSE)

      # Read updated consumption data
      updated_efd <- fread(updated_efd_csv)
      updated_efm <- fread(updated_efm_csv)
      updated_edp <- fread(updated_edp_csv)
      updated_emp <- fread(updated_emp_csv)

      # Rename EGYVOL column to ERG to match baseline files
      setnames(updated_efd, "EGYVOL", "ERG")
      setnames(updated_efm, "EGYVOL", "ERG")
      setnames(updated_edp, "EGYVOL", "ERG")
      setnames(updated_emp, "EGYVOL", "ERG")

      # Handle empty files (only header row) by creating proper column types from baseline
      if(nrow(updated_efd) == 0) {
        updated_efd <- baseline_edf[0, ]  # Empty table with correct structure
        updated_efd[, Value := 0]
      }
      if(nrow(updated_efm) == 0) {
        updated_efm <- baseline_emf[0, ]  # Empty table with correct structure
        updated_efm[, Value := 0]
      }
      if(nrow(updated_edp) == 0) {
        updated_edp <- baseline_edp[0, ]  # Empty table with correct structure
        updated_edp[, Value := 0]
      }
      if(nrow(updated_emp) == 0) {
        updated_emp <- baseline_emp[0, ]  # Empty table with correct structure
        updated_emp[, Value := 0]
      }

      # Convert Value columns to numeric
      updated_efd[, Value := as.numeric(Value)]
      updated_efm[, Value := as.numeric(Value)]
      updated_edp[, Value := as.numeric(Value)]
      updated_emp[, Value := as.numeric(Value)]

      # For each header, merge with baseline and replace zeros with baseline values
      # EFD header (ERG, ACTS, REG)
      updated_efd_merged <- merge(baseline_edf, updated_efd,
                                   by = c("ERG", "ACTS", "REG"),
                                   suffixes = c("_baseline", "_updated"),
                                   all.x = TRUE)
      updated_efd_merged[is.na(Value_updated), Value_updated := 0]
      updated_efd_merged[, Value := ifelse(Value_updated == 0, Value_baseline, Value_updated)]

      # EFM header (ERG, ACTS, REG)
      updated_efm_merged <- merge(baseline_emf, updated_efm,
                                   by = c("ERG", "ACTS", "REG"),
                                   suffixes = c("_baseline", "_updated"),
                                   all.x = TRUE)
      updated_efm_merged[is.na(Value_updated), Value_updated := 0]
      updated_efm_merged[, Value := ifelse(Value_updated == 0, Value_baseline, Value_updated)]

      # EDP header (ERG, REG)
      updated_edp_merged <- merge(baseline_edp, updated_edp,
                                   by = c("ERG", "REG"),
                                   suffixes = c("_baseline", "_updated"),
                                   all.x = TRUE)
      updated_edp_merged[is.na(Value_updated), Value_updated := 0]
      updated_edp_merged[, Value := ifelse(Value_updated == 0, Value_baseline, Value_updated)]

      # EMP header (ERG, REG)
      updated_emp_merged <- merge(baseline_emp, updated_emp,
                                   by = c("ERG", "REG"),
                                   suffixes = c("_baseline", "_updated"),
                                   all.x = TRUE)
      updated_emp_merged[is.na(Value_updated), Value_updated := 0]
      updated_emp_merged[, Value := ifelse(Value_updated == 0, Value_baseline, Value_updated)]

      # Sum by ERG and REG (using corrected values)
      updated_efd_sum <- updated_efd_merged[, .(consumption = sum(Value)), by = .(ERG, REG)]
      updated_efm_sum <- updated_efm_merged[, .(consumption = sum(Value)), by = .(ERG, REG)]
      updated_edp_sum <- updated_edp_merged[, .(consumption = sum(Value)), by = .(ERG, REG)]
      updated_emp_sum <- updated_emp_merged[, .(consumption = sum(Value)), by = .(ERG, REG)]

      # Combine all updated consumption sources
      updated_volumes <- rbindlist(list(updated_efd_sum, updated_efm_sum, updated_edp_sum, updated_emp_sum))
      output_by_erg_reg <- updated_volumes[, .(final_output = sum(consumption)), by = .(ERG, REG)]

      # Merge with baseline to add baseline_output column for reporting
      output_by_erg_reg <- merge(baseline_by_erg_reg, output_by_erg_reg, by = c("ERG", "REG"), all.x = TRUE)

      # Fill missing final_output with baseline (no change if missing)
      output_by_erg_reg[is.na(final_output), final_output := baseline_output]

      # Calculate percentage change for reporting
      output_by_erg_reg[, pct_change := ifelse(baseline_output > 0,
                                                ((final_output / baseline_output) - 1) * 100,
                                                0)]

    } else {
      cat("  WARNING: GTAPDATA.UPD file not found:", upd_file, "\n")
      stop("Cannot proceed without GTAPDATA.UPD file")
    }
  }

  # Now aggregate across regions to get totals by ERG
  output_data <- output_by_erg_reg[, .(
    baseline_output = sum(baseline_output, na.rm = TRUE),
    final_output = sum(final_output, na.rm = TRUE)
  ), by = .(ERG)]

  # Calculate the implied percentage change for reporting
  output_data[, pct_change := ifelse(baseline_output > 0,
                                      ((final_output / baseline_output) - 1) * 100,
                                      0)]

  # Now output_data contains final_output for all sectors
  if(!exists("output_data") || nrow(output_data) == 0) {
    stop("Failed to extract output data")
  }

  # Calculate generation shares for each technology
  # All generation technologies (ERG dimension, not ACTS)
  all_sectors <- c("CoalBL", "GasBL", "OilBL", "GasP", "OilP",
                   "NuclearBL", "HydroBL", "WindBL", "HydroP", "SolarP", "OtherBL")

  total_generation <- output_data[ERG %in% all_sectors, sum(final_output, na.rm = TRUE)]

  if(total_generation <= 0) {
    cat("  WARNING: Total generation is zero or negative!\n")
    stop("Cannot proceed with zero total generation")
  }

  # Calculate shares for each technology
  current_shares <- list()
  cat("  Technology outputs and shares:\n")
  for(tech in all_sectors) {
    tech_output <- output_data[ERG == tech, sum(final_output, na.rm = TRUE)]
    tech_share <- tech_output / total_generation
    current_shares[[tech]] <- tech_share
    cat("    ", tech, ":", round(tech_output, 0), "TWh (", round(tech_share * 100, 2), "%)\n")
  }

  # Calculate combined hydro share (HydroBL + HydroP)
  current_shares$Hydro <- current_shares$HydroBL + current_shares$HydroP

  cat("  Combined Hydro (BL+P):", round(current_shares$Hydro * 100, 2), "%\n")
  cat("  Total generation:", round(total_generation, 0), "TWh\n")

  # Calculate proportional gaps for renewable technologies
  cat("\n  Proportional gaps (current vs target):\n")
  gaps <- list()
  for(tech in names(TARGET_SHARES)) {
    target <- TARGET_SHARES[[tech]]
    current <- current_shares[[tech]]
    gap <- (current - target) / target  # Negative means underperforming
    gaps[[tech]] <- gap
    cat("    ", tech, ": current =", round(current * 100, 2), "%, target =",
        round(target * 100, 2), "%, gap =", round(gap * 100, 1), "%\n")
  }

  # Log this iteration
  log_entry <- data.table(iteration = iteration)
  for(tech in names(shock_values)) {
    log_entry[[paste0("shock_", tech)]] <- shock_values[[tech]]
  }
  for(tech in names(TARGET_SHARES)) {
    log_entry[[paste0("share_", tech)]] <- current_shares[[tech]]
    log_entry[[paste0("gap_", tech)]] <- gaps[[tech]]
  }
  convergence_log <- rbind(convergence_log, log_entry, fill = TRUE)

  # Check convergence: all shares must be at or above target value
  # Technologies can exceed their target, but must meet minimum target
  all_sufficient <- TRUE
  for(tech in names(TARGET_SHARES)) {
    target <- TARGET_SHARES[[tech]]
    current <- current_shares[[tech]]
    # Check if current >= target (must meet or exceed target)
    if(current < target) {
      all_sufficient <- FALSE
      break
    }
  }

  if(all_sufficient) {
    cat("\n  *** CONVERGED! ***\n")
    cat("  All technologies at or above target value\n")

    # Preserve the final GTAPDATA.UPD as the calibrated baseline for future experiments
    if(file.exists(paste0('../iterative_calibration/', sim_id, '_GTAPDATA.UPD'))) {
      file.copy(paste0('../iterative_calibration/', sim_id, '_GTAPDATA.UPD'),
                "../iterative_calibration/GTAPDATA_2024_calibrated.UPD", overwrite = TRUE)
      cat("  Saved calibrated baseline to: ../iterative_calibration/GTAPDATA_2024_calibrated.UPD\n")
    }

    converged <- TRUE
  } else {
    # Find technology with most negative gap (furthest below target)
    most_underperforming_tech <- names(gaps)[which.min(unlist(gaps))]
    cat("\n  Most underperforming technology:", most_underperforming_tech,
        "(gap =", round(gaps[[most_underperforming_tech]] * 100, 1), "%)\n")

    # Calculate dynamic shock increment based on gap
    # Formula: new_shock = (old_shock+100)*(target/current)-100, rounded down to nearest 10
    target_share <- TARGET_SHARES[[most_underperforming_tech]]
    current_share <- current_shares[[most_underperforming_tech]]

    # Get current shock value for the underperforming tech
    if(most_underperforming_tech == "Hydro") {
      old_shock <- shock_values$HydroBL
    } else {
      old_shock <- shock_values[[most_underperforming_tech]]
    }

    # Calculate new shock based on ratio of target to current
    if(current_share > 0) {
      new_shock <- (old_shock + 100) * (target_share / current_share) - 100
      # Round down to nearest 10
      new_shock <- floor(new_shock / 10) * 10
      # Calculate increment
      shock_increment <- new_shock - old_shock
      # Ensure minimum increment of 10
      if(shock_increment < 10) {
        shock_increment <- 10
        new_shock <- old_shock + 10
      }
    } else {
      # If current share is zero, use a large increment
      shock_increment <- 100
      new_shock <- old_shock + 100
    }

    cat("  Dynamic shock calculation: old_shock =", old_shock,
        ", target/current =", round(target_share/current_share, 2),
        ", new_shock =", new_shock, "(increment =", shock_increment, ")\n")

    # Apply shock increment
    # Special handling for Hydro: shock both HydroBL and HydroP together
    if(most_underperforming_tech == "Hydro") {
      shock_values$HydroBL <- new_shock
      shock_values$HydroP <- new_shock
      cat("  Setting HydroBL and HydroP shocks to", shock_values$HydroBL, "\n")
    } else {
      shock_values[[most_underperforming_tech]] <- new_shock
      cat("  Setting", most_underperforming_tech, "shock to",
          shock_values[[most_underperforming_tech]], "\n")
    }

    iteration <- iteration + 1
  }

  cat("\n")
}

## FINAL RESULTS
################

if(!converged) {
  cat("\nWARNING: Maximum iterations reached without convergence\n")
  cat("Final gaps from targets:\n")
  for(tech in names(TARGET_SHARES)) {
    final_gap <- convergence_log[nrow(convergence_log)][[paste0("gap_", tech)]]
    cat("  ", tech, ":", round(final_gap * 100, 1), "%\n")
  }

  # Even if not fully converged, save the best attempt as calibrated baseline
  last_sim_id <- paste0("iter_", sprintf("%03d", iteration - 1))
  if(file.exists(paste0('../iterative_calibration/', last_sim_id, '_GTAPDATA.UPD'))) {
    file.copy(paste0('../iterative_calibration/', last_sim_id, '_GTAPDATA.UPD'),
              "../iterative_calibration/GTAPDATA_2024_calibrated.UPD", overwrite = TRUE)
    cat("Saved final iteration baseline to: ../iterative_calibration/GTAPDATA_2024_calibrated.UPD\n")
  }
}

# Save convergence log
fwrite(convergence_log, '../results/iterative_calibration_log.csv')

cat("\n========================================\n")
cat("CALIBRATION SUMMARY\n")
cat("========================================\n\n")
cat("Iterations run:", nrow(convergence_log), "\n")
cat("\nFinal shock values:\n")
for(tech in names(shock_values)) {
  cat("  ", tech, ":", shock_values[[tech]], "\n")
}
cat("\nFinal generation shares vs targets:\n")
for(tech in names(TARGET_SHARES)) {
  final_share <- convergence_log[nrow(convergence_log)][[paste0("share_", tech)]]
  target_share <- TARGET_SHARES[[tech]]
  cat("  ", tech, ": ", round(final_share * 100, 2), "% (target: ",
      round(target_share * 100, 2), "%)\n", sep = "")
}
cat("\nConvergence log saved to: ../results/iterative_calibration_log.csv\n")

## CREATE BASEDATA_2024.HAR FROM CALIBRATION RESULTS
####################################################

cat("\n========================================\n")
cat("CREATING BASEDATA_2024.HAR\n")
cat("========================================\n\n")

# Determine the final iteration number
final_iteration <- nrow(convergence_log)
final_sim_id <- paste0("iter_", sprintf("%03d", final_iteration))

cat("Final iteration:", final_iteration, "\n")
cat("Final sim_id:", final_sim_id, "\n\n")

## STEP 1: RENAME HEADERS IN UPD FILE
######################################

cat("Step 1: Renaming headers EFD->EDF and EFM->EMF in GTAPDATA.UPD\n")
upd_file <- paste0("../iterative_calibration/", final_sim_id, "_GTAPDATA.UPD")
renamed_upd_file <- paste0("../iterative_calibration/", final_sim_id, "_GTAPDATA_renamed.UPD")

if(!file.exists(upd_file)) {
  cat("  ERROR: GTAPDATA.UPD file not found:", upd_file, "\n")
  stop("Cannot proceed without GTAPDATA.UPD file")
}

# Create .sti file to rename headers in the .UPD file
sti_rename_file <- "rename_upd_headers.sti"

# modhar commands to rename EFD->EDF and EFM->EMF
sti_rename_content <- c(
  "",                    # Initial blank line
  "y",                   # Yes to overwrite if exists
  upd_file,              # Source file (.UPD)
  renamed_upd_file,      # Destination file
  "ch",                  # Change header name command
  "EFD",                 # Old header name
  "EDF",                 # New header name
  "ch",                  # Change header name command
  "EFM",                 # Old header name
  "EMF",                 # New header name
  "ex",                  # Exit
  "a",                   # Apply changes
  "Geldner",             # Attribution
  "**end",               # End marker
  "y"                    # Confirm
)

writeLines(sti_rename_content, sti_rename_file)
cat("  Created", sti_rename_file, "\n")

# Run modhar to rename headers
cat("  Running modhar to rename headers in .UPD file\n")
modhar_rename_result <- system(paste0("modhar -sti ", sti_rename_file), ignore.stdout = FALSE)

if(modhar_rename_result != 0) {
  cat("  WARNING: modhar rename returned exit code", modhar_rename_result, "\n")
  stop("Failed to rename headers in UPD file")
}

cat("  Successfully created renamed UPD file:", renamed_upd_file, "\n\n")

## STEP 2: READ LIST OF HEADERS FROM CSV FILE
###############################################

cat("Step 2: Reading list of headers from upd_header_names.csv\n")

# Read the CSV file with header names
upd_headers_csv <- "../upd_header_names.csv"

if(!file.exists(upd_headers_csv)) {
  stop("ERROR: upd_header_names.csv not found. This file must be manually created.")
}

upd_headers_data <- fread(upd_headers_csv, header = FALSE)

# Extract header names from second column (V2)
headers_in_upd <- upd_headers_data$V2

cat("  Found", length(headers_in_upd), "headers in UPD file\n")
if(length(headers_in_upd) > 0) {
  cat("  Header names:", paste(head(headers_in_upd, 10), collapse=", "),
      ifelse(length(headers_in_upd) > 10, "...", ""), "\n")
}
cat("\n")

## STEP 3: EXTRACT EACH HEADER TO CSV TO CHECK IF EMPTY
########################################################

cat("Step 3: Checking which headers are empty\n")

empty_headers <- character()
non_empty_headers <- character()
upd_row_counts <- list()

# Create directory for temporary CSV files
dir.create("../iterative_calibration/header_check", recursive = TRUE, showWarnings = FALSE)

for(header in headers_in_upd) {
  csv_file <- paste0("../iterative_calibration/header_check/", header, ".csv")

  # Extract header to CSV
  extract_result <- system(
    paste("har2csv", renamed_upd_file, csv_file, header),
    ignore.stdout = TRUE
  )

  if(extract_result == 0 && file.exists(csv_file)) {
    # Read CSV and check if it has data (more than just header row)
    csv_data <- fread(csv_file, showProgress = FALSE)

    if(nrow(csv_data) == 0) {
      empty_headers <- c(empty_headers, header)
      cat("  ", header, ": EMPTY\n")
    } else {
      non_empty_headers <- c(non_empty_headers, header)
      upd_row_counts[[header]] <- nrow(csv_data)
      cat("  ", header, ": non-empty (", nrow(csv_data), " rows)\n")
    }
  } else {
    cat("  WARNING: Failed to extract header", header, "\n")
  }
}

cat("\nSummary:\n")
cat("  Empty headers:", length(empty_headers), "\n")
cat("  Non-empty headers:", length(non_empty_headers), "\n")

if(length(non_empty_headers) == 0) {
  stop("ERROR: No non-empty headers found in UPD file!")
}

# Save header lists for reference
writeLines(empty_headers, "../iterative_calibration/empty_headers.txt")
writeLines(non_empty_headers, "../iterative_calibration/non_empty_headers.txt")

cat("  Saved header lists to ../iterative_calibration/\n\n")

## STEP 3B: VALIDATE ROW COUNTS AGAINST BASEDATA.HAR
#####################################################

cat("Step 3b: Validating row counts against basedata.har\n")

# Headers to skip validation (preserved headers that won't be replaced)
preserve_headers <- c("DREL", "DVER", "DPSM")

# Filter non-empty headers to get those that will be replaced
headers_to_validate <- setdiff(non_empty_headers, preserve_headers)

cat("  Checking row counts for", length(headers_to_validate), "headers\n")

# Create directory for basedata header extracts
dir.create("../iterative_calibration/basedata_check", recursive = TRUE, showWarnings = FALSE)

row_count_mismatches <- character()

for(header in headers_to_validate) {
  basedata_csv_file <- paste0("../iterative_calibration/basedata_check/", header, ".csv")

  # Extract header from basedata.har
  extract_result <- system(
    paste("har2csv", "basedata.har", basedata_csv_file, header),
    ignore.stdout = TRUE
  )

  if(extract_result == 0 && file.exists(basedata_csv_file)) {
    # Read CSV and get row count
    basedata_csv_data <- fread(basedata_csv_file, showProgress = FALSE)
    basedata_row_count <- nrow(basedata_csv_data)
    upd_row_count <- upd_row_counts[[header]]

    if(basedata_row_count != upd_row_count) {
      row_count_mismatches <- c(row_count_mismatches, header)
      cat("  ERROR:", header, "- basedata.har has", basedata_row_count,
          "rows, UPD has", upd_row_count, "rows\n")
    } else {
      cat("  ", header, ": OK (", basedata_row_count, " rows)\n")
    }
  } else {
    cat("  WARNING: Failed to extract header", header, "from basedata.har\n")
  }
}

# Stop if there are any mismatches
if(length(row_count_mismatches) > 0) {
  cat("\n")
  cat("ERROR: Row count mismatches detected!\n")
  cat("The following headers have different row counts between basedata.har and UPD file:\n")
  for(header in row_count_mismatches) {
    cat("  -", header, "\n")
  }
  cat("\nThis indicates a structural inconsistency that must be resolved before proceeding.\n")
  stop("Row count validation failed")
}

cat("  All row counts match!\n\n")

## STEP 4: CREATE BASEDATA_2024.HAR USING MW COMMAND
#####################################################

cat("Step 4: Creating basedata_2024.har by replacing headers from UPD\n")

# Headers to preserve in basedata.har (should NOT be replaced from UPD)
preserve_headers <- c("DREL", "DVER", "DPSM")

# Filter non-empty headers to get those that should be replaced
headers_to_replace <- setdiff(non_empty_headers, preserve_headers)

cat("  Replacing", length(headers_to_replace), "headers from UPD file\n")
cat("  Preserving", length(preserve_headers), "headers from basedata.har:", paste(preserve_headers, collapse=", "), "\n")

sti_create_2024_file <- "create_basedata_2024.sti"

# Build modhar commands using mw (modify/write) to replace headers
# Start with basedata.har as the old file, write to basedata_2024.har
sti_create_content <- c(
  "",                         # Initial blank line
  "y",                        # Yes, starting with an old file
  "basedata.har",             # Old file (source)
  "basedata_2024.har"         # New file (destination)
)

# For each header to replace, use mw command
for(header in headers_to_replace) {
  sti_create_content <- c(
    sti_create_content,
    "mw",                     # Modify/write command
    header,                   # Header name to replace
    "m",                      # Modify the data
    "r",                      # Replace
    "w",                      # Whole matrix
    "g",                      # General array replacement (not same value for all)
    "h",                      # Replace with values from another HAR file
    renamed_upd_file,         # Source HAR file (the UPD file)
    header,                   # Corresponding header name in source file
    "w",                      # Write
    "n"                       # No more operations on this header
  )
}

# Complete the STI file
sti_create_content <- c(
  sti_create_content,
  "ex",                       # Exit
  "a",                        # Apply changes
  "Geldner",                  # Attribution
  "**end",                    # End marker
  "y"                         # Confirm
)

writeLines(sti_create_content, sti_create_2024_file)

# Run modhar to create basedata_2024.har
cat("  Running modhar to create basedata_2024.har\n")
create_result <- system(paste0("modhar -sti ", sti_create_2024_file), ignore.stdout = FALSE)

if(create_result == 0 && file.exists("basedata_2024.har")) {
  cat("\n*** SUCCESS! ***\n")
  cat("Created basedata_2024.har successfully\n\n")
} else {
  stop("ERROR: Failed to create basedata_2024.har")
}

## FINAL SUMMARY
################

cat("\n========================================\n")
cat("OUTPUT FILES\n")
cat("========================================\n\n")
cat("1. Convergence log: ../results/iterative_calibration_log.csv\n")
cat("2. CMF files: ../iterative_calibration/iter_*.cmf\n")
cat("3. Solution files: ../iterative_calibration/iter_*.sl4\n")
cat("4. Baseline volume data: ../iterative_calibration/baseline_e*.csv\n")
cat("5. Updated data files: ../iterative_calibration/iter_*_GTAPDATA.UPD\n")
cat("6. CALIBRATED 2024 BASELINE: ../iterative_calibration/GTAPDATA_2024_calibrated.UPD\n")
cat("7. Renamed UPD file:", renamed_upd_file, "\n")
cat("8. Empty headers list: ../iterative_calibration/empty_headers.txt\n")
cat("9. Non-empty headers list: ../iterative_calibration/non_empty_headers.txt\n")
cat("10. FINAL BASEDATA_2024.HAR: basedata_2024.har\n\n")

cat("Headers processed:\n")
cat("  Empty headers (not included):", length(empty_headers), "\n")
cat("  Preserved headers (from basedata.har):", length(preserve_headers), "-", paste(preserve_headers, collapse=", "), "\n")
cat("  Replaced headers (from UPD):", length(headers_to_replace), "\n")
cat("  Other headers (unchanged from basedata.har): all remaining\n\n")

