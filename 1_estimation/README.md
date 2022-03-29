## Run Instructions

These scripts use the historical mortality and climate dataset compiled in the `0_data_cleaning` to: (i) estimate regression analyses recovering empirical mortality-temperature relationships; (ii) produce plots describing these regression results; (iii) conduct a set of cross-validation exercises to investigate the out-of-sample performance of the main estimated regression model. 

### 1. Set directory paths.
As outlined in `0_data_cleaning`, codes in this directory rely on the `REPO`, `DB`, and `OUTPUT` variables to be defined in your `~/.bash_profile`. Other directories, such as those that store `.ster` and log files, are set in the `0_data_cleaning/1_utils_set_paths.do` file, which is run at the top of every script. The user is not required to change anything in this file, but can override path locations if desired. See the header documentation in that script and the README in `0_data_cleaning` for more information.

### 2. Construct final dataset.
All code in this folder depends on the final mortality dataset (`data/0_data_cleaning/3_final/global_mortality_panel.dta`), which can be compiled using code in the `0_data_cleaning` subfolder of this repository or downloaded from the data repository. Note that mortality and population data from the United States and China are not publicly available. As such, they are not included in the public data repository and cannot be used to replicate exact versions of the pre-projection tables and figures from the analysis contained in `1_estimation` without the use of hardcoding certain values in the script. 

However, regression output run on the full dataset are stored as `.ster` files in `DB/1_estimation/1_ster`. These regression results feed into the Monte Carlo generation described in `2_projection`, so beyond this section results generated using this public repo will match those in Carleton et al. (2022).

If however, you do decide to run the regression generation scripts, they will be saved with the suffix `_public` so that they can be differentiated from the full sample regression `ster` files. 

### 3. Toggle desired outputs and run master file, `estimate.do`.
`estimate.do` is the master script for this step of the analysis, relying upon code within the subfolders of `1_estimation` to produce tables and figures related to the estimation of the temperature-mortality relationship. Following Carleton et al. (2022), the master script does the following:

1. Estimates age-specific temperature-mortality relationships accounting for spatial heterogeneity in average income and climate.

The user may also estimate the alternative regression models discussed in Appendix D including:

2. The age-combined mortality-temperature relationship using pooled subnational data across all age groups (Appendix D.2)
3. A series of robustness models that appear in the Carleton et al. (2022) Appendix:
    * Models using heating degree days and cooling degree days as alternative measure of weather exposure (Appendix D.4)
    * Models under alternative functional forms (e.g., binned, cubic/linear splines) and climate data sources (BEST/UDEL) (Appendix D.2)
    * Models accounting for additional sources of heterogeneity, including institutions, educational attainment, health services, and labor force informality (Appendix D.6)
    * A model omitting precipitation controls (Appendix D.5)

Additionally, the user may generate:

4. Summary statistics on historical mortality and climate and that produce Table I 
5. Cross-validation exercises that appear in Appendix D 

See the header of `estimate.do` for further instructions on running some or all portions of the `1_estimation` process.

## Folder Structure

`estimate.do` - Master script for running estimation code, including regressions and the corresponding tables and figures.

`1_utils`- Contains scripts which prepare the final dataset for various regressions.

`2_summary_statistics`- Generates summary statistics on historical mortality and climate (Table I). 

`3_regressions` - Contains sub-directories for all regression models estimated in the analysis. Details on the regressions in Carleton et al. (2022) are provided in the sub-directory's README.

`4_crossval` - Contains the scripts that perform the regression cross-validation exercises that are described in Appendix D. 
