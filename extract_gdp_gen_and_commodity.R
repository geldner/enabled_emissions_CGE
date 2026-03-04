## EXTRACT q_gdp FROM GEN AND COMMODITY EXPERIMENT SOLUTION FILES
## This script reads q_gdp (header 0184) from the already-extracted .sol files
## produced by experiment_set_gen_and_commodity.R and saves results to CSV
## in the same table structure as the carbon emissions output.

.libPaths(c(.libPaths(), "C:/Users/natha/Documents/R/win-library/4.1"))

library(data.table)

setwd("C:/Users/natha/Documents/Two Brothers/enabled emissions/gtap_p_20by5/gtpv7AI")

## UTILITY FUNCTION
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

## RECONSTRUCT PARAMETER GRID (must match experiment_set_gen_and_commodity.R)
renewable_levels <- c("none", "low", "medium", "high")
fossil_levels <- c("none", "low", "medium", "high")
fuel_neutral_levels <- c("none", "low", "baseline", "high")

param_grid <- expand.grid(
  renewable_level = renewable_levels,
  fossil_level = fossil_levels,
  fuel_neutral_level = fuel_neutral_levels,
  stringsAsFactors = FALSE
)

param_grid$sim_id <- paste0("sim_", sprintf("%02d", 1:nrow(param_grid)))
param_grid$is_no_shocks <- (param_grid$renewable_level == "none" &
                             param_grid$fossil_level == "none" &
                             param_grid$fuel_neutral_level == "none")

sims_to_run <- which(!param_grid$is_no_shocks)

## READ q_gdp FROM EACH SIMULATION
cat("Extracting q_gdp (header 0184) from solution files...\n")

results_list <- list()

for (i in 1:nrow(param_grid)) {
  sim_id <- param_grid$sim_id[i]

  # Handle no-shocks case specially - create synthetic zero-change results
  if (param_grid$is_no_shocks[i]) {
    cat("Creating synthetic zero-change results for", sim_id, "(none/none/none)\n")

    # Get structure from any other simulation (use sim_02 as template)
    template_sim <- param_grid$sim_id[2]
    readsol(
      paste0("../cmf_gen_and_commodity/solfiles/"),
      paste0(template_sim, ".sol"),
      paste0("../cmf_gen_and_commodity/solfiles/", template_sim, "_qgdp.csv"),
      "0184"
    )
    template_results <- fread(paste0("../cmf_gen_and_commodity/solfiles/", template_sim, "_qgdp.csv"))

    these_results <- copy(template_results)
    value_cols <- names(these_results)[sapply(these_results, is.numeric)]
    these_results[, (value_cols) := 0]

    these_results$sim_id <- sim_id
    these_results$renewable_level <- param_grid$renewable_level[i]
    these_results$fossil_level <- param_grid$fossil_level[i]
    these_results$fuel_neutral_level <- param_grid$fuel_neutral_level[i]

    results_list[[i]] <- these_results
    next
  }

  # Read q_gdp from solution file
  readsol(
    paste0("../cmf_gen_and_commodity/solfiles/"),
    paste0(sim_id, ".sol"),
    paste0("../cmf_gen_and_commodity/solfiles/", sim_id, "_qgdp.csv"),
    "0184"
  )

  these_results <- fread(paste0("../cmf_gen_and_commodity/solfiles/", sim_id, "_qgdp.csv"))
  these_results$sim_id <- sim_id
  these_results$renewable_level <- param_grid$renewable_level[i]
  these_results$fossil_level <- param_grid$fossil_level[i]
  these_results$fuel_neutral_level <- param_grid$fuel_neutral_level[i]

  results_list[[i]] <- these_results

  if (i %% 10 == 0) {
    cat("Processed", i, "of", nrow(param_grid), "result files\n")
  }
}

## COMBINE AND SAVE
res_table <- rbindlist(results_list)

dir.create('../results', recursive = TRUE, showWarnings = FALSE)
fwrite(res_table, '../results/experiment_gen_and_commodity_gdp_results.csv')

cat("\nDone. Saved", nrow(res_table), "rows to ../results/experiment_gen_and_commodity_gdp_results.csv\n")
