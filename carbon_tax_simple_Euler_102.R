## SIMPLIFIED CARBON TAX SIMULATION
## This script applies a single carbon tax shock using basedata_ctax.har
## (which has small non-zero values replacing problematic zeros)
##
## The simulation swaps del_rctaxb for del_nctaxb (making nominal carbon tax
## the exogenous variable) and shocks del_nctaxb to implement a carbon tax.
##
## Carbon tax target value based on Social Cost of Carbon (SCC) from here https://www.rff.org/publications/explainers/social-cost-carbon-101/
## adjusted here https://www.bls.gov/data/inflation_calculator.htm from Jan 2022 (publication year from rff data) to Jan 2017 (base year of model):
## values:
## - $102/tCO2 in 2017 dollars (2.5% discount rate) but didn't get enough of a difference in energy mix
## - now $160 (2% discount rate)
## - 266, 1.5% discount rate
## - trying 102 (3% discount rate)

# Add user library path
.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

# Set working directory to GTAP model location
setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_20by5/gtpv7AI")

## CONFIGURATION
################

# Carbon tax to apply (full amount in one shock)
CTAX <- 102

# Input and output files
input_basedata <- "basedata.har"
output_basedata <- "basedata_ctax_102.har"

## CMF TEMPLATE
###############

base_cmf_template <- c(
  "! This CMF file applies full carbon tax in one simulation !",
  "auxiliary files = gtapv7-ep;",
  "check-on-read elements = warn;",
  "cpu=yes ;",
  "log file = yes;",
  "start with MMNZ = 200000000;",
  "",
  "! Input files:",
  "File GTAPSETS = sets.har;",
  paste0("File GTAPDATA = ", input_basedata, ";"),
  "File GTAPPARM = default.prm;",
  "! Output files:",
  "File GTAPSUM = <cmf>-SUM.har;",
  "File WELVIEW = <cmf>-WEL.har;",
  "File GTAPVOL = <cmf>-VOL.har;",
  "! Updated files:",
  "Updated File GTAPDATA = GTAPDATA.UPD;",
  "Solution file = <cmf>.sl4;",
  "",
  "! Solution method",
  "method = Euler ;",
  "steps = 300 600 900 ;",
  #"subintervals = 10;",
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
  "swap del_rctaxb = del_nctaxb;",
  "",
  "Verbal Description = Single-step carbon tax simulation ;"
)

## CREATE OUTPUT DIRECTORIES
############################

dir.create('../carbon_tax_simple', recursive = TRUE, showWarnings = FALSE)
dir.create('../results', recursive = TRUE, showWarnings = FALSE)

## READ UPD HEADER NAMES FOR BASELINE CONVERSION
################################################

upd_headers_csv <- "../../upd_header_names.csv"

if(!file.exists(upd_headers_csv)) {
  stop("ERROR: upd_header_names.csv not found. This file is required for baseline conversion.")
}

upd_headers_data <- fread(upd_headers_csv, header = FALSE)
headers_in_upd <- upd_headers_data$V2

## RUN SIMULATION
#################

cat("========================================\n")
cat("SIMPLIFIED CARBON TAX SIMULATION\n")
cat("========================================\n\n")

cat("Input baseline:", input_basedata, "\n")
cat("Carbon tax: $", CTAX, "/tCO2\n", sep="")
cat("Output baseline:", output_basedata, "\n\n")

# Verify input file exists
if(!file.exists(input_basedata)) {
  cat("ERROR: Input baseline file not found:", input_basedata, "\n")
  cat("Run gen_ctax_basedata.R first to create basedata_ctax.har\n")
  stop("Cannot proceed without input baseline file")
}

# Generate CMF file
sim_id <- paste0("ctax_", CTAX)
shock_string <- paste0("Shock del_nctaxb = uniform ", CTAX, " ;")

cmf_file <- paste0('../carbon_tax_simple/', sim_id, '.cmf')
writeLines(c(base_cmf_template, "", shock_string), cmf_file)

cat("Created CMF file:", cmf_file, "\n")

# Run GTAP simulation
cat("Running simulation...\n")
run_cmd <- paste0('GTAPV7-EP.exe -cmf ', cmf_file)
run_result <- system(run_cmd, ignore.stdout = FALSE, ignore.stderr = TRUE)

# Check for simulation success
sol_file <- paste0('../carbon_tax_simple/', sim_id, '.sl4')

if(run_result != 0 || !file.exists("GTAPDATA.UPD") || !file.exists(sol_file)) {
  cat("\n")
  cat("******************************************\n")
  cat("* SIMULATION FAILED                      *\n")
  cat("******************************************\n")
  cat("Exit code:", run_result, "\n")
  cat("GTAPDATA.UPD exists:", file.exists("GTAPDATA.UPD"), "\n")
  cat("Solution file exists:", file.exists(sol_file), "\n")
  stop("Simulation failed")
}

cat("Simulation completed successfully.\n\n")

# Backup the GTAPDATA.UPD
upd_backup <- paste0('../carbon_tax_simple/', sim_id, '_GTAPDATA.UPD')
file.copy("GTAPDATA.UPD", upd_backup, overwrite = TRUE)
cat("Backed up GTAPDATA.UPD to", upd_backup, "\n")

## CONVERT GTAPDATA.UPD TO NEW BASELINE
#######################################

cat("\nConverting GTAPDATA.UPD to new baseline...\n")

## Step 1: Rename headers in UPD file (EFD->EDF, EFM->EMF)
renamed_upd_file <- paste0('../carbon_tax_simple/', sim_id, '_GTAPDATA_renamed.UPD')

sti_rename_file <- "rename_upd_ctax.sti"
sti_rename_content <- c(
  "",
  "y",
  "GTAPDATA.UPD",
  renamed_upd_file,
  "ch",
  "EFD",
  "EDF",
  "ch",
  "EFM",
  "EMF",
  "ex",
  "a",
  "Geldner",
  "**end",
  "y"
)

writeLines(sti_rename_content, sti_rename_file)
modhar_rename_result <- system(paste0("modhar -sti ", sti_rename_file), ignore.stdout = TRUE)

if(modhar_rename_result != 0 || !file.exists(renamed_upd_file)) {
  cat("WARNING: modhar rename returned exit code", modhar_rename_result, "\n")
  stop("Failed to rename headers in UPD file")
}

cat("Renamed headers in UPD file\n")

## Step 2: Check which headers are non-empty in the renamed UPD file
dir.create("../carbon_tax_simple/header_check", recursive = TRUE, showWarnings = FALSE)

non_empty_headers <- character()

for(header in headers_in_upd) {
  csv_file <- paste0("../carbon_tax_simple/header_check/", header, ".csv")

  extract_result <- system(
    paste("har2csv", renamed_upd_file, csv_file, header),
    ignore.stdout = TRUE
  )

  if(extract_result == 0 && file.exists(csv_file)) {
    csv_data <- fread(csv_file, showProgress = FALSE)
    if(nrow(csv_data) > 0) {
      non_empty_headers <- c(non_empty_headers, header)
    }
  }
}

cat("Found", length(non_empty_headers), "non-empty headers in UPD file\n")

## Step 3: Create new basedata using modhar mw commands
preserve_headers <- c("DREL", "DVER", "DPSM")
headers_to_replace <- setdiff(non_empty_headers, preserve_headers)

sti_create_file <- "create_basedata_ctax_104.sti"

sti_create_content <- c(
  "",
  "y",
  input_basedata,
  output_basedata
)

for(header in headers_to_replace) {
  sti_create_content <- c(
    sti_create_content,
    "mw",
    header,
    "m",
    "r",
    "w",
    "g",
    "h",
    renamed_upd_file,
    header,
    "w",
    "n"
  )
}

sti_create_content <- c(
  sti_create_content,
  "ex",
  "a",
  "Geldner",
  "**end",
  "y"
)

writeLines(sti_create_content, sti_create_file)

cat("Creating new baseline:", output_basedata, "\n")
create_result <- system(paste0("modhar -sti ", sti_create_file), ignore.stdout = TRUE)

if(create_result != 0 || !file.exists(output_basedata)) {
  cat("ERROR: Failed to create new baseline\n")
  stop("Cannot create new baseline file")
}

cat("Successfully created", output_basedata, "\n")

# Clean up temporary files
file.remove(sti_rename_file)
file.remove(sti_create_file)
unlink("../carbon_tax_simple/header_check", recursive = TRUE)

## SUMMARY
##########

cat("\n========================================\n")
cat("COMPLETED\n")
cat("========================================\n\n")
cat("Input baseline:", input_basedata, "\n")
cat("Carbon tax applied: $", CTAX, "/tCO2\n", sep="")
cat("Output baseline:", output_basedata, "\n")
cat("\nOutput files:\n")
cat("  CMF file:", cmf_file, "\n")
cat("  Solution file:", sol_file, "\n")
cat("  UPD backup:", upd_backup, "\n")
cat("  New baseline:", output_basedata, "\n")
