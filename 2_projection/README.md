## Run instructions

### 1. Set directory paths and R environment.
Code in `2_projection` operates using `cilpath` for R.  The folders necessary for running the code are the following:

- Repository path (` REPO` ) - specifies the directory on the user's machine which contains this repository, e.g., `/User/MGreenstone/repositories`
- Data path ( `DB`) - specifies the location of the data folder downloaded from the online data repository. See "Downloading the data" in the master README for further instructions. 
- Output path (`OUTPUT`) - specifies the folder in which output from the analysis should be saved. This includes all tables and figures in the main text and appendix of Carleton et al. (2019). 

If `cilpath` is not installed, users can manually specify these base directories within `2_projection/1_utils/load_utils.R`. Note that codes must be run from the root directory of this repository, e.g., `/User/MGreenstone/repositories/mortality`, if paths are manually specified in `load_utils.R`.

`2_projection/1_utils/load_utils.R` also depends on package management tool `pacman`, which automatically installs and loads the packages required to run the code. For a complete list of required packages, see `2_projection/1_utils/packages.txt`.

### 2. Run projections or download Monte Carlo simulation output.
The README in `2_run_projections` provides details on how projections were run using the Climate Impact Lab projection system. As discussed in the previous section, data from the USA and China are not publicly available and therefore not part of our data release. To replicate the figures and tables that rely upon the final Monte Carlo simulations, users can download the required projection output from the online data repository. See [Downloading the Data](https://gitlab.com/ClimateImpactLab/Impacts/mortality/-/tree/dylan#downloading-the-data) for instructions on accessing these data.


### 3. Generate figures using `3_generate_figures/generate_projection_figures.R`.
`generate_projection_figures.R` is the master script for generating figures from Monte Carlo simulation output, using the functions within `1_utils` to load the appropriate data and produce the visualizations. This script is organized into six sections:

1.  Data Coverage (Figures 1 and 3)
2.  Temperature sensitivity of mortality maps and response function plots (Figures 5 and 6)
3.  End of century mortality risk of climate change maps and density plots (Figure 7)
4.  Time series of projected mortality risk of climate change (Figure 8)
5.  The impact of climate change in 2100 compared to contemporary leading causes of death (Figure 11)
6.  Appendix F figures.

See the header of `generate_projection_figures.R` for further instructions on replicating figures.


### 3. Produce in-text summary statistics using `4_in-text_stats/paper_intextstats.R`.
`paper_intextstats.R` is the master script for summarizing projection output in the main text of Carleton et al. (2019). This script is also organized into six sections:

1.  Global mortality impacts
2.  Impact-region level impacts
3.  Marginal effect of a hot day (35C) for each age group
4.  Share of death equivalents attributable to adaptation costs by 2015 income deciles
5.  Monetized mortality damages as percent of GDP
6.  CPU-hours required for Monte Carlo simulation

See the header of `paper_intextstats.R` for further instructions on replicating in-text summary statistics.


## Folder Structure

`1_utils`- Contains functions for initializing the R environment and generating the figures and in-text summary stats in Carleton et al. (2019). See the `README` in this folder for details on the functions written for this stage of the analysis.

`2_run_projections` - Configuration files and helpful bash scripts for generating, aggregating, and extracting projected mortality impacts based upon the model inputs generated in `1_estimation`. See the `impact-calculations` repository for detailed documentation and run instructions for the Climate Impact Lab projection system.

`3_generate_figures` - Contains documented master script for generating post-projection figures in Carleton et al. (2019).

`4_in-text_stats` - Contains master script for generating in-text statistics based upon projection and valuation results.