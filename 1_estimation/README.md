## Run Instructions

### 1. Set directory paths.
As outlined in `0_data_cleaning`, codes in this directory rely on the `REPO`, `DB`, and `OUTPUT` variables to be defined in your `~/.bash_profile`. Other directories, such as those that store Stata ster and log files, are set in the `0_data_cleaning/1_utils_set_paths.do` file, which is run at the top of every script. The user is not required to change anything in this file, but can override path locations if desired. See the header documentation in that script and the README in `0_data_cleaning` for more information.

### 2. Construct final dataset.
All code in this folder depends on the final mortality dataset (`data/0_data_cleaning/3_final/global_mortality_panel.dta`), which can be compiled using code in the `0_data_cleaning` subfolder of this repository or downloaded from the data repository.

### 3. Toggle desired outputs and run master do file, `estimate.do`.
`estimate.do` is the master script for this step of the analysis, relying upon code within the subfolders of `1_estimation` to produce tables and figures related to the estimation of the temperature-mortality relationship. Following Carleton et al. (2022), the master script does the folowing:

1. Estimates age-specific temperature-mortality relationships accounting for spatial heterogeneity in average income and climate.

The user may also estimate the alternative regression models discussed in Appendix D including:

2. The age-combined temperature-mortality response function using pooled subnational data.
3. The age-specific temperature-mortality relationships for the three age groups, <5, 5-64, >64. 
4. Estimates a series of robustness models that appear in the Carleton et al. (2022) appendix:
    * Models using heating degree days and cooling degree days as alternative measure of weather exposure
    * Models under alternative functional forms (e.g., binned, cubic/linear splines) and climate data sources (BEST/UDEL)
    * Models accounting for heterogeneity in country level measures of institutions
    * A model omitting precipitation controls

Additionally, the user may generate:

5. Summary statistics on historical mortality and climate and that produce Table 1 in Carleton et al. (2022).
6. Cross validation exercises that appear in Appendix D in Carleton et al. (2022).

See the header of `estimate.do`for further instructions on running some or all portions of the `1_estimation` process.



## Folder Structure

`estimate.do` - Master script for running estimation code, including regressions and the corresponding tables and figures.

`1_utils`- Contains script which prepares the final dataset for regressions.

`2_summary_statistics`- Generates summary statistics on historical mortality and climate (Table I) for Carleton et al. (2022)

`3_regressions` - Contains sub-directories for all regression models estimated in the analysis. Details on the regressions in Carleton et al. (2022) are provided in this folder's README.

`4_crossval` - Contains the scripts that perform the regrssion crossvalidation exercises that are described in Appendix D in Carleton et al. (2022). 
