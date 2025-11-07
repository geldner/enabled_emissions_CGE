## RUN SCENARIO EXPERIMENTS
## This script runs the factorial scenario experiment scripts sequentially

cat("========================================\n")
cat("RUNNING SCENARIO EXPERIMENTS\n")
cat("========================================\n\n")

# Start timer
start_time <- Sys.time()

# Experiment 1: Generation-only (fossil generation technology only)
cat("========================================\n")
cat("EXPERIMENT 1: Generation-Only\n")
cat("========================================\n")
source('C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/experiment_set_generation_only.R')

# Experiment 2: Generation and commodity shocks
cat("\n========================================\n")
cat("EXPERIMENT 2: Generation and Commodity\n")
cat("========================================\n")
source('C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/experiment_set_gen_and_commodity.R')

# Experiment 3: Commodity-only
cat("\n========================================\n")
cat("EXPERIMENT 3: Commodity-Only\n")
cat("========================================\n")
source('C:/Users/natha/Documents/Two Brothers/enabled emissions/enabled_emissions_cge/experiment_set_refactored_commodity_only.R')

cat("\n========================================\n")
cat("ALL SCENARIO EXPERIMENTS COMPLETED!\n")
cat("========================================\n")

# Calculate and report total runtime
end_time <- Sys.time()
total_runtime <- end_time - start_time

cat("\nTotal runtime for all scenario experiments:\n")
print(total_runtime)

# Also print in more readable format
total_seconds <- as.numeric(total_runtime, units = "secs")
hours <- floor(total_seconds / 3600)
minutes <- floor((total_seconds %% 3600) / 60)
seconds <- round(total_seconds %% 60, 1)

cat(sprintf("  %d hours, %d minutes, %.1f seconds\n", hours, minutes, seconds))
