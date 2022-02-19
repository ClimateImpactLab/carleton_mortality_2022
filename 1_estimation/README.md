## Run Instructions

### 1. Set directory paths.
As outlined in `0_data_cleaning`, codes in this directory rely on `cilpath` for Stata, which will automatically set paths for the repository, data, and output. However, if `cilpath` is not installed, users can manually set these paths in `0_data_cleaning/1_utils/set_paths.do`. See the header documentation in that script and the README in `0_data_cleaning` for more information.

### 2. Construct final dataset.
All code in this folder depends on the final mortality dataset (`data/0_data_cleaning/3_final/global_mortality_panel.dta`), which can be compiled using code in the `0_data_cleaning` subfolder of this repository or downloaded from the data repository.

### 3. Run master do file, `estimate.do`.
`estimate.do` is the master script for this step of the analysis, relying upon code within the subfolders of `1_estimation` to produce tables and figures related to the estimation of the temperature-mortality relationship. Following Carleton et al. (2019), the master script does the folowing:

1. Constructs summary statistics on historical mortality and climate and generates Table 1.
2. Estimates the age-combined temperature-mortality response function using pooled subnational data.
3. Estimates unique temperature-mortality relationships for the three age groups, <5, 5-64, >64.
4. Estimates age-specific temperature-mortality relationships accounting for spatial heterogeneity in average income and climate.
5. Estimates a series of robustness models that appear in the Carleton et al. (2019) appendix:
    * Country-level regressions
	* Models using heating degree days and cooling degree days as alternative
	measure of weather exposure
	* Models under alternative functional forms (e.g., binned, cubic/linear
	splines) and climate data sources (BEST/UDEL)


See the header of `estimate.do`for further instructions on running some or all portions of the `1_estimation` process.



## Folder Structure

`estimate.do` - Master script for running estimation code, including regressions and the corresponding tables and figures.

`1_utils`- Contains script which prepares the final dataset for regressions.

`2_summary_statistics`- Generates summary statistics on historical mortality and climate (Table 1) for Carleton et al. (2019)

`3_regressions` - Contains sub-directories for all regression models estimated in the analysis. Details on the regressions in Carleton et al. (2019) are provided in this folder's README.

