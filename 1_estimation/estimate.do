/*

Purpose: Master Do file for 1_estimation.

This script manages the estimation and plotting of all regression models in
Carleton et al. 2019.

This script assumes (1) the final dataset is constructed by
0_data_cleaning or downloaded from the online data repository and (2)
directories are properly set in `1_utils/set_paths.do`

The estimation process proceeds as follows:

1. Construct summary statistics on historical mortality and climate and
construct Table 1.
	- toggle: `summary_stats`

2. Estimate the age-combined temperature-mortality response function using
pooled subnational data.
	- toggle: `age_combined`

3. Estimate unique temperature-mortality relationships for the three age
groups, <5, 5-64, >64.
	- toggle: `age_spec`

4. Estimate age-specific temperature-mortality relationships accounting for
spatial heterogeneity in average income and climate.
	- toggle: `age_spec_interacted`

5. Estimate a series of robustness models that appear in the Carleton et al. 
(2019) appendix:
	- Country-level regressions
	- Models using heating degree days and cooling degree days as alternative
	measure of weather exposure
	- Models under alternative functional forms (e.g., binned, cubic/linear
	splines) and climate data sources (BEST/UDEL)
	- toggle: `appendix`

The toggles below control which portions of the cleaning process is run.

*/

*************************************************************************
* 							PART A. Initializing						*			
*************************************************************************

cap cilpath
if _rc!=0 & "$REPO" == "" {
	// If cilpath is not installed, please run codes from root of mortality 
	// repository and set your personal paths in `set_paths.do`
	do "0_data_cleaning/1_utils/set_paths.do" 
}
else {
	do "$REPO/mortality/0_data_cleaning/1_utils/set_paths.do"
}

// Toggles:
local summary_stats 0
local age_combined 0
local age_spec 0
local age_spec_interacted 0
local appendix 0

*************************************************************************
* 						PART B. Summary Statistics						*
*************************************************************************
if `summary_stats' {
	preserve
		do "$code_dir/1_estimation/2_summary_statistics/summary_stats.do"
	restore
}

*************************************************************************
* 							PART C. Regressions     					*			
*************************************************************************

if `age_combined' {
	* 1. pooled sample regressions 
	preserve
		do "$code_dir/1_estimation/3_regressions/1_age_combined/age_combined_regressions.do"
		do "$code_dir/1_estimation/3_regressions/1_age_combined/age_combined_displayresults.do"
	restore
}

if `age_spec' {
	* 2. age-specific regressions
	preserve
		do "$code_dir/1_estimation/3_regressions/2_age_spec/age_spec_regressions.do"
		do "$code_dir/1_estimation/3_regressions/2_age_spec/age_spec_displayresults.do"
	restore
}

if `age_spec_interacted' {
	* 3. age-specific regression with interaction
	preserve
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/age_spec_interacted_regressions.do"
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/age_spec_interacted_displayresults.do"
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/age_spec_interacted_array_plots_presentation.do"
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/array_output_in-text.do"
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/age_spec_interacted_genCSVV.do"
	restore
}


if `appendix' {

	* 4. Country-level
	preserve
		do "$code_dir/1_estimation/3_regressions/4_country-level/age_combined_country-level_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_country-level/age_spec_interacted_country-level_regressions.do"	
	restore

	* 5. Misc. model comparison regressions
	preserve
		do "$code_dir/1_estimation/3_regressions/5_compare_models/HDDCDD_regressions.do"
		do "$code_dir/1_estimation/3_regressions/5_compare_models/HDDCDD_displayresults.do"
		do "$code_dir/1_estimation/3_regressions/5_compare_models/age_combined_alternative_model_climate_regressions.do"
		do "$code_dir/1_estimation/3_regressions/5_compare_models/age_spec_interacted_alternative_model_regressions.do"	
	restore

	* 6. India response regressions
	preserve
		do "$code_dir/1_estimation/3_regressions/6_india_response/age_combined_india-response_regressions.do"
	restore

}


