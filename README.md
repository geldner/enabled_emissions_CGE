This repository contains all scripts and model files to reproduce the work of \[TODO: insert full reference upon acceptance]. This workflow is compatible with Windows operating systems only, as unfortunately the GEMPACK computable equilibrium modeling software which handles the simulations only supports Windows. We have not tested compatibility with Wine or similar compatibility layer software.



This workflow utilizes R for driving simulations and Python to generate figures.



To reproduce all analysis and figures, you first must replace absolute paths across the R scripts in the parent level directory and install the free (limited license) version of GEMPACK https://www.copsmodels.com/gpeidl.htm (the GTAP-P-5x20 model aggregation can also run on RUNGTAP, but our experimental workflow uses R to programmatically generate model input files and drive model runs via GEMPACK CLI utilities)



Then run iterative\_renewable\_calibration.R to generate our recalibrated baseline reflecting 2024 generation figures (newer generation figures can be used - simply replace baseline\_data.csv with a new download from Our World in Data). 



Then run run\_10x10.R to generate all 10x10 figure results - if you only wish to generate a subset of the 12 10x10 experiments (which include figure 1 and 11 supplementary figures), you can adjust the setup in the main execution setup starting at line 454.



Then run run\_scenarios.R to reproduce Figure 2 results and those of and similar supplementary figures.



Then generate a python environment from ./gtap\_p\_20by5/environment.yml (we used Conda) and with that environment run ./gtap\_p\_20by5/run\_all\_plots.py in order to produce the plots from the results (saved as .csv files in ./gtap\_p\_20by5/results).



We encourage readers to consider alternative shock structures or the outcomes of changes to baseline data.

