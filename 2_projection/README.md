## User suitability 

**Please note - the code in `2_projection/` does not need to be run in order for a user to work with codes later in the process.
We have included the outputs of this projection step as csv files in the data repository associated with this repo, so that the user does not need to re-generate them.**
- Running a full set of Monte Carlo projections over all climate models, socioeconomic models (i.e., IIASA and OECD "IAMs"), all SSPs, all age groups, and resampling from statistical uncertainty is highly computationally intensive. This can only be done on a computing cluster or using cloud computing resources.
- We therefore describe all steps of this process and include all scripts here, but ensure the user can replicate later stages in the paper pipeline without running this step, as it requires substantial computing resources and time.
- Additionally, the full set of raw Monte Carlo projection output files that are generated from the full set of simulations, which are used to generate the future projection results in the paper, are large, requiring ~30TB of storage. Rather than including these large output files in our data release, we provide what we refer to as "extracted files", which contain impact region-level GCM-weighted mean and quantile impact values across the Monte Carlo simulation runs. All of the charts and tables that appear in the paper can be created using these "extracted" files. 

## Run instructions

### 1. Set directory paths and R environment.
Please ensure that your `~/.bash_profile` defines the `REPO`, `DB`, and `OUTPUT` environment variables as instructed in the main README file. 

`2_projection/1_utils/load_utils.R` loads the R packages necessary to produce the charts contained in the paper, and depends on the package management tool `pacman`, which automatically installs and loads these packages. For a complete list of required packages, see `2_projection/1_utils/packages.txt`.

### 2. (Optional) View the README in `2_run_projections/` to see how projections and the extracted files are generated
`2_run_projections/` provides details on how projections are run using the regression output CSVV file generated in the `1_estimation/` step and code from the Climate Impact Lab projection system which exists in the [`impact_calculations`](https://github.com/ClimateImpactLab/impact-calculations), [`impact-commons`](https://github.com/ClimateImpactLab/impact-common), and [`prospectus-tools`](https://github.com/jrising/prospectus-tools) public repositories. The step-by-step process of generating projections, aggregating by regions, and extracting means and quantiles across Monte Carlo simulation distributions is detailed here. 

### 3. Generate figures using `3_generate_figures/generate_projection_figures.R`.
`generate_projection_figures.R` is the master script for generating figures from Monte Carlo simulation output, using the functions within `1_utils` to load the appropriate data and produce the visualizations. This script is organized into six sections:

1.  Data Coverage (Figures II, B1)
2.  Mortality sensitivity to temperature, maps and response function plots (Figures III, D5 & E2)
3.  End-of-century mortality risk of climate change maps and density plots (Figures IV, F1 & F6)
4.  Time series of projected mortality risk of climate change at global scale (Figures V, F2, F3, F4, F5, F7, F9, F10 & F11)
5.  2100 impacts of climate change by decile of today's income and climate (Figure VI)
6.  The impact of climate change on mortality at end-of-century, compared to contemporary leading causes of death (Figures IX, F8)

Toggles can be switched on or off allowing the user to selectively generate these charts. See the header of `generate_projection_figures.R` for further instructions on replicating figures.

The code to produce Appendix Figure B2 which plots the 2080-2099 mean global surface temperature anomally of future climate projections from the surrogate model/mixed ensemble (SMME) can be found in [this separate repository](https://github.com/ClimateImpactLab/SMME-schematic-plot).


### 4. Produce the mortality impact values that populate Table 2, as well as in-text summary statistics using `4_in-text_stats/paper_intextstats.R`.
`paper_intextstats.R` is the master script for summarizing projection output throughout the main text of Carleton et al. (2022). This script is also organized into six sections:

1.  Global mortality impacts
2.  Country and multi-national region level impacts
3.  Impact region level impacts
4.  Marginal effect of a hot day (35C) for each age group
5.  Monetized mortality damages as percent of GDP
6.  CPU-hours required for Monte Carlo simulation

See the header of `paper_intextstats.R` for further instructions on replicating in-text summary statistics.

## Folder Structure

`1_utils`- Contains functions for initializing the R environment and generating the figures and in-text summary stats in Carleton et al. (2022). See the `README` in this folder for details on the functions written for this stage of the analysis.

`2_run_projections` - Configuration files and helpful bash scripts for generating, aggregating, and extracting projected mortality impacts based upon the model inputs generated in `1_estimation`. See the [`impact-calculations`](https://github.com/ClimateImpactLab/impact-calculations) repository for detailed documentation and run instructions for the Climate Impact Lab projection system.

`3_generate_figures` - Contains documented master script for generating post-projection figures in Carleton et al. (2022).

`4_in-text_stats` - Contains master script for generating in-text statistics based upon projection and valuation results.
