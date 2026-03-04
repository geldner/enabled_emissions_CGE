# Extract Baseline CO2 Emissions from 2024 Calibrated GTAPDATA
# This creates a reference file for converting percentage changes to nominal values

# Add user library path
.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

# Extract CO2T (baseline CO2 emissions by region) from calibrated GTAPDATA
# CO2T is in megatons of CO2

setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_20by5/gtpv7AI/")

# Extract CO2Q array from GTAPDATA
system("har2csv basedata_ctax_69.har ../../baseline_co2_ctax_69.csv CO2Q", ignore.stdout = FALSE)

# Read and format the baseline CO2 data
baseline_co2 <- fread("../../baseline_co2_ctax_69.csv")


cat("Baseline CO2 emissions extracted successfully!\n")
cat("File saved to: baseline_co2.csv\n")
cat("Total baseline emissions:", sum(baseline_co2$Value, na.rm = TRUE), "megatons CO2\n")

# Display summary
print(baseline_co2)
