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

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

// Toggles:

// Regressions
local age_spec_interacted 0
local age_combined 0
local age_spec 0
local alt_specs 0

// Main Text Tables
local text_tables 0

// Main Text Plots
local text_plots 0

// Appendix Tables
local apx_reg_tables 0

// Appendix Figures
local apx_reg_plots 0 

// Institutional Covariates (regs + table + fig)
local institutions 0

// India Test
local india 0

// Cross Validation
local crossval 0

*************************************************************************
* 							PART B. Regressions     					*			
*************************************************************************

if `age_combined' {
	* 1. pooled sample regressions 
	preserve
		do "$code_dir/1_estimation/3_regressions/1_age_combined/age_combined_regressions.do"
	restore
}


if `age_spec' {
	* 2. age-specific regressions
	preserve
		do "$code_dir/1_estimation/3_regressions/2_age_spec/age_spec_regressions.do"
	restore
}


if `age_spec_interacted' {
	* 3. age-specific regression with interaction
	preserve
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/age_spec_interacted_regressions.do"
	restore
}


if `alt_specs' {
	* 4. alternative specification regressions that appear in the appendix
	preserve
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/1_regressions/age_combined_alternative_model_climate_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/1_regressions/age_spec_interacted_alternative_model_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/1_regressions/age_spec_uninteracted_alternative_model_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/1_regressions/age_spec_interacted_noprecip_regression.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/1_regressions/HDDCDD_regressions.do"
	restore
}


if `institutions' {
	* 5. age-spec interactions with institutional covariate regressions that appear in the appendix
	preserve
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/institutional_covariates/1_regressions/edu_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/institutional_covariates/1_regressions/health_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/institutional_covariates/1_regressions/inequality_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/institutional_covariates/1_regressions/informality_regressions.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/institutional_covariates/1_regressions/institutions_regressions.do"
	restore
}
		
*************************************************************************
* 						PART D. Analysis Figures     					*			
*************************************************************************

if `text_tables' {
	* Table 1 in Text, Summary stats
	preserve
		do "$code_dir/1_estimation/2_summary_statistics/Table_I_summary_stats.do"
	restore
}


if `text_plots' {
	* Figure 1 in Main Text, Figures D1/D2 in Appendix
	preserve
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/Figure_I_array_plots.do"
	restore
}


if `apx_reg_tables' {
	* Appendix regression tables
	preserve
		do "$code_dir/1_estimation/3_regressions/3_age_spec_interacted/Table_D1_age_spec_interacted_marginaleffects.do"
		do "$code_dir/1_estimation/3_regressions/2_age_spec/Table_D2_age_spec_displayresults.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/2_analysis/Table_D3_HDDCDD_marginalfx.do"
	restore
}


if `apx_reg_plots' {
	* Appendix regression tables
	preserve
		do "$code_dir/1_estimation/3_regressions/2_age_spec/Figure_D3_age_spec_plots.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/2_analysis/Figure_D4_alt_func_forms.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/2_analysis/Figure_D6_HDDCDD_mean_scatter.do"
		do "$code_dir/1_estimation/3_regressions/4_alternative_models/2_analysis/Figure_D7_response_compare_noprecip.do"
	restore
}


if `institutions' {
	* Tables and Charts for Institutional Covariate Models
	preserve
		foreach cov in "edu" "health" "inequality" "informality" "institutions" {
			global mod `cov'
			do "$code_dir/1_estimation/3_regressions/4_alternative_models/institutional_covariates/2_analysis/Table_D4_rmse_test.do"
			do "$code_dir/1_estimation/3_regressions/4_alternative_models/institutional_covariates/2_analysis/Figure_D8_response_compare.do"
		}
	restore
}


if `india' {
	* India regression and plot
	preserve
		do "$code_dir/1_estimation/3_regressions/5_Burgess_India_test/age_combined_india-response_regressions.do"
		do "$code_dir/1_estimation/3_regressions/5_Burgess_India_test/age_spec_interacted_india_compare_responses.do"
		do "$code_dir/1_estimation/3_regressions/5_Burgess_India_test/Figure_D11_India_response_compare.do"
	restore 
}


if `crossval' {
	* Crossvalidation exercises, Appendix Table D5 & Figures D9, D10
	preserve
		do "$code_dir/1_estimation/4_crossval/adminxval/Table_D5_admincrossval.do"
		do "$code_dir/1_estimation/4_crossval/covar_xval/residualize_regs_space.do"
		do "$code_dir/1_estimation/4_crossval/covar_xval/Table_D5_crossval_rmse.do"
		do "$code_dir/1_estimation/4_crossval/covar_xval/Figure_D9_outofsample_responsefunc_space.do"
		do "$code_dir/1_estimation/4_crossval/time_xval/residualize_regs_time.do"
		do "$code_dir/1_estimation/4_crossval/time_xval/Table_D5_crossval_time_rmse.do"
		do "$code_dir/1_estimation/4_crossval/time_xval/Figure_D9_outofsample_responsefunc_time.do"
}


