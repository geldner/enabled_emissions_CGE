## INDIVIDUAL SHOCK DECOMPOSITION — MEDIUM/MEDIUM/MEDIUM CASE
## This script takes each individual shock from the medium/medium/medium
## (baseline treatment) scenario and runs it in a separate simulation.
## For each shock, it records the resulting changes in CO2 emissions and GDP,
## allowing us to attribute marginal effects to individual technology shocks.
##
## CO2 emissions: header 0038 (gco2t)
## GDP:           header 0184 (q_gdp)

.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_20by5/gtpv7AI")

## UTILITY FUNCTIONS
####################

extractvar <- function(solution.dir, solution.name, solution.out) {
  system(
    paste("sltoht",
          paste(solution.dir, solution.name, sep = ""),
          solution.out),
    ignore.stdout = TRUE
  )
}

readsol <- function(solution.dir, solution.out, csv.out, header) {
  har2csv.status <- system(
    paste("har2csv",
          paste(solution.dir, solution.out, sep = ""),
          csv.out, header, sep = " "),
    ignore.stdout = TRUE
  )
  if (har2csv.status == 0) {
    y <- read.csv(csv.out)
  } else {
    y <- NA
  }
}

generate_shock_string <- function(param, val) {
  paste0("Shock ", param, " = uniform ", val, ";")
}

## READ EXPERIMENTAL DESIGN
############################

exp_design_file <- "C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_exp_design.csv"
exp_design <- fread(exp_design_file)

# Fix escape character issues with quotes in parameter names
exp_design$param <- gsub('""', '"', exp_design$param, fixed = TRUE)

cat("Loaded", nrow(exp_design), "parameters from experimental design\n")

## BUILD LIST OF INDIVIDUAL SHOCKS AT MEDIUM (BASELINE TREATMENT) LEVEL
########################################################################

# For each parameter, generate the shock string at the baseline treatment value
shock_list <- data.table(
  shock_id    = paste0("ishock_", sprintf("%02d", 1:nrow(exp_design))),
  param       = exp_design$param,
  description = exp_design$description,
  value       = exp_design$`baseline treatment`,
  renewable   = exp_design$renewable,
  fuel_neutral = exp_design$fuel_neutral,
  fossil_commodity = exp_design$fossil_commodity
)

shock_list$shock_string <- mapply(generate_shock_string, shock_list$param, shock_list$value)

# Classify each shock into its axis
shock_list$axis <- ifelse(shock_list$renewable, "renewable",
                   ifelse(shock_list$fuel_neutral, "fuel_neutral", "fossil"))

cat("\nIndividual shocks to run:\n")
cat("  Renewable:    ", sum(shock_list$axis == "renewable"), "\n")
cat("  Fossil:       ", sum(shock_list$axis == "fossil"), "\n")
cat("  Fuel-neutral: ", sum(shock_list$axis == "fuel_neutral"), "\n")
cat("  Total:        ", nrow(shock_list), "\n\n")

## BASE CMF TEMPLATE (same as experiment_set_gen_and_commodity.R)
#################################################################

base_cmf_template <- c(
  "! Individual shock decomposition CMF — medium case !",
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
  "Verbal Description = Individual shock decomposition ;"
)

## GENERATE CMF FILES — ONE PER SHOCK
######################################

cmf_dir <- "../cmf_individual_shocks"
dir.create(cmf_dir, recursive = TRUE, showWarnings = FALSE)

# Clean up old output files
cat("Cleaning up old output files...\n")
old_files <- list.files(cmf_dir, pattern = "\\.(sl4|har|sol|csv)$",
                        full.names = TRUE, recursive = TRUE)
if (length(old_files) > 0) {
  file.remove(old_files)
  cat("Removed", length(old_files), "old files\n")
}

dir.create(paste0(cmf_dir, "/solfiles"), recursive = TRUE, showWarnings = FALSE)

cat("Generating CMF files for", nrow(shock_list), "individual shocks...\n")

for (i in 1:nrow(shock_list)) {
  cmf_file <- paste0(cmf_dir, "/", shock_list$shock_id[i], ".cmf")
  writeLines(c(base_cmf_template, "", shock_list$shock_string[i]), cmf_file)
}

cat("All CMF files generated.\n\n")

## RUN SIMULATIONS
##################

cat("Starting individual shock simulations...\n\n")

for (i in 1:nrow(shock_list)) {
  sid <- shock_list$shock_id[i]

  cat("Running", i, "of", nrow(shock_list), ":", shock_list$description[i], "\n")
  cat("  Shock:", shock_list$shock_string[i], "\n")

  exp <- paste0("GTAPV7-EP.exe -cmf ", cmf_dir, "/", sid, ".cmf")
  system(exp, ignore.stdout = TRUE)

  # Clean up GTAPDATA.UPD to avoid contaminating next simulation
  if (file.exists("GTAPDATA.UPD")) {
    file.remove("GTAPDATA.UPD")
  }

  cat("  Done.\n")
}

cat("\nAll simulations completed.\n\n")

## EXTRACT SOLUTION FILES
##########################

cat("Extracting solution files...\n")

for (i in 1:nrow(shock_list)) {
  sid <- shock_list$shock_id[i]

  extractvar(
    solution.dir = cmf_dir,
    solution.name = paste0("/", sid, ".sl4"),
    solution.out = paste0(cmf_dir, "/solfiles/", sid, ".sol")
  )
}

cat("Extraction complete.\n\n")

## READ CO2 AND GDP RESULTS, MERGE INTO SINGLE TABLE
######################################################

cat("Reading CO2 emissions (header 0038) and GDP (header 0184) from each simulation...\n")

results_list <- list()

for (i in 1:nrow(shock_list)) {
  sid <- shock_list$shock_id[i]

  # --- CO2 emissions (gco2t, header 0038) ---
  co2_csv <- paste0(cmf_dir, "/solfiles/", sid, "_gco2t.csv")
  readsol(
    paste0(cmf_dir, "/solfiles/"),
    paste0(sid, ".sol"),
    co2_csv,
    "0038"
  )

  # --- GDP (q_gdp, header 0184) ---
  gdp_csv <- paste0(cmf_dir, "/solfiles/", sid, "_qgdp.csv")
  readsol(
    paste0(cmf_dir, "/solfiles/"),
    paste0(sid, ".sol"),
    gdp_csv,
    "0184"
  )

  if (file.exists(co2_csv) && file.exists(gdp_csv)) {
    co2_dt <- fread(co2_csv)
    gdp_dt <- fread(gdp_csv)

    results_list[[i]] <- data.table(
      region          = co2_dt$REG,
      co2             = co2_dt$Value,
      gdp             = gdp_dt$Value,
      param           = shock_list$param[i],
      shock_magnitude = shock_list$value[i]
    )
  } else {
    cat("  WARNING: results missing for", sid, "\n")
  }

  if (i %% 10 == 0) {
    cat("  Processed", i, "of", nrow(shock_list), "\n")
  }
}

## COMBINE AND SAVE
####################

res_table <- rbindlist(results_list)

dir.create("../results", recursive = TRUE, showWarnings = FALSE)
fwrite(res_table, "../results/individual_shocks_medium.csv")

cat("\n=== RESULTS SAVED ===\n")
cat(nrow(res_table), "rows ->", "../results/individual_shocks_medium.csv\n")
cat("Columns:", paste(names(res_table), collapse = ", "), "\n")
