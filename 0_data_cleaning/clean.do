/*

Purpose: Master Do file for 0_data_cleaning.

This script manages the initial cleaning and merging of mortality, climate and
income data for Carleton et al. 2019.

This script assumes that the raw climate, mortality, and income data are
downloaded from the online data repository and that directories are properly set
in `1_utils/set_paths.do`

The data cleaning process proceeds as follows:

1. Generate ADM2 level climate data and ADM1 level income data.
	- Income data are downscaled from national Penn Worlds Tables using
	subnational GDP from Eurostat and Gennaioli et al. (2014).
	- Climate data (avg. temperature and precip) used in the main analysis are
	population weighted aggregations of GMFD gridded climate data.

2. Calculate 30-year bartlett kernel average measures of climate and 13-year
bartlett kernel average measures of income, which are interacted with climate
variables in estimation.

3. Clean and merge mortality and population data from country-specific
soureces and construct death rate variables.

4. Merge/append cleaned country data into final dataset.

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
local clean_climate 0
local clean_income 0
local generate_iso 0
local append_iso 0
local final_merge 0

*************************************************************************
* 					PART B. Process Covariate Data 						*			
*************************************************************************

// Clean climate data and generate long-run climate covariates.
if `clean_climate' {
	do "$code_dir/0_data_cleaning/2_clean_covariates/1_process_monthly_climate_data.do"
}

// Downscale income data and generate long-run income covariates.
if `clean_income' {
	do "$code_dir/0_data_cleaning/2_clean_covariates/2_process_income_data.do"
}


*************************************************************************
* 			PART C. generate & append final country datasets			*			
*************************************************************************

// Clean intermediate country-level datasets.
if `generate_iso' {
	foreach iso in $ISO {
		do "$code_dir/0_data_cleaning/3_clean_merge_countries/`iso'_clean_merge.do"
	}
}

// Append intermediate country-level datasets.
if `append_iso' {
	foreach iso in $ISO {
		append using "$data_dir/2_cleaned/`iso'_cleaned_merged.dta"
	}
}

*************************************************************************
* 			PART D. Final cleaning and covariate consruction			*			
*************************************************************************

// Construct final variables, add labels, and save final dataset.
if `final_merge' {

	* drop country-specific ID variables
	replace adm0 = country if iso == "IND"
	drop adm2_source_id ADM1_ADM2_name adm1_id_string adm2_id_string ///
		NAME_1 NAME_2 pop_replicated deathrate_replicated country

	* drop EU France data
	drop if substr(adm2_id, 1, 2) == "FR" 

	* use country average income if missing adm1 income 
	replace gdppc_adm1 = gdppc_adm0 if mi(gdppc_adm1) 
	replace gdppc_adm1_13br = gdppc_adm0_13br if mi(gdppc_adm1_13br)
	replace loggdppc_adm1 = loggdppc_adm0 if mi(loggdppc_adm1) 
	replace loggdppc_adm1_13br = loggdppc_adm0_13br if mi(loggdppc_adm1_13br)


	* generate sample average Tbar, log gdppc, and CDD/HDD at the adm1 level 
	* 	(one year one vote given unbalanced panel within adm1 unit)
	preserve 
		bysort iso adm1_id year: keep if _n == 1
		collapse (mean) gdppc_adm1_avg=gdppc_adm1 loggdppc_adm1_avg = loggdppc_adm1 ///
			lr_tavg_BEST_adm1_avg=tavg_BEST_adm1 lr_tavg_GMFD_adm1_avg=tavg_GMFD_adm1 ///
			lr_cdd_20C_BEST_adm1_avg=tmax_cdd_20C_BEST_adm1 lr_cdd_20C_GMFD_adm1_avg=tmax_cdd_20C_GMFD_adm1 ///
			lr_hdd_20C_BEST_adm1_avg=tmax_hdd_20C_BEST_adm1 lr_hdd_20C_GMFD_adm1_avg=tmax_hdd_20C_GMFD_adm1, by(iso adm1_id) fast 
		tempfile avgincomes
		save `avgincomes', replace
	restore 

	* merge in sample average incomes
	merge m:1 iso adm1_id using "`avgincomes'", assert(3) nogen 

	* rename linear spline (tavg) CDD / HDD variables to avoid confusion with hot-side-hot & cold-side-cold terms
	rename (*polyAbove25_1* *polyBelow0_1*) (*cdd_25C* *hdd_0C*)

	* data set formating
	order adm0 iso adm1 adm1_id adm2 adm2_id year agegroup deaths population deathrate ///
		gdppc_adm0 gdppc_adm0_13br loggdppc_adm0 loggdppc_adm0_13br ///
		gdppc_adm1 gdppc_adm1_13br gdppc_adm1_avg loggdppc_adm1 loggdppc_adm1_13br loggdppc_adm1_avg ///
		tavg_GMFD_adm1 tavg_BEST_adm1 lr_tavg_GMFD_adm1_30br lr_tavg_BEST_adm1_30br lr_tavg_GMFD_adm1_avg ///
		lr_tavg_BEST_adm1_avg tmax_cdd_20C_GMFD_adm1 tmax_cdd_20C_BEST_adm1 tmax_hdd_20C_GMFD_adm1 tmax_hdd_20C_BEST_adm1 ///
		lr_cdd_20C_GMFD_adm1_avg lr_cdd_20C_BEST_adm1_avg lr_hdd_20C_GMFD_adm1_avg lr_hdd_20C_BEST_adm1_avg

	* set variable lables
	lab var adm0 "country string"
	lab var iso "Alpha-3 country code"
	lab var adm1 "country specific administrative level 1 string"
	lab var adm1_id "administrative level 1 code"
	lab var adm2 "administrative level 2 string"
	lab var adm2_id "country specific administrative level 2 code"
	lab var year "year"
	lab var agegroup "observation agegroup"
	lab var deaths "total deaths"
	lab var deathrate "deathrate per 100,000 people"
	lab var population "total population"
	lab var gdppc_adm0 "adm0 income - Penn World Tables"
	lab var gdppc_adm0_13br "adm0 income - Penn World Tables (13yr triangular moving average)"
	lab var loggdppc_adm0 "log adm0 income - Penn World Tables"
	lab var loggdppc_adm0_13br "log adm0 income - Penn World Tables (13yr triangular moving average)"
	lab var gdppc_adm1 "adm1 income downscaled - Penn World Tables"
	lab var gdppc_adm1_13br "adm1 income downscaled - Penn World Tables (13yr triangular moving average)"
	lab var gdppc_adm1_avg "adm1 income downscaled - Penn World Tables (sample average)"
	lab var loggdppc_adm1 "log adm1 income downscaled - Penn World Tables"
	lab var loggdppc_adm1_13br "log adm1 income downscaled - Penn World Tables (13yr triangular moving average)"
	lab var loggdppc_adm1_avg "log adm1 income downscaled - Penn World Tables (sample average)"
	lab var tavg_GMFD_adm1 "adm1 annual average temperature - GMFD"
	lab var tavg_BEST_adm1 "adm1 annual average temperature - BEST"
	lab var lr_tavg_GMFD_adm1_30br "adm1 annual average temperature - GMFD (30yr triangular moving average)"
	lab var lr_tavg_BEST_adm1_30br "adm1 annual average temperature - BEST (30yr triangular moving average)"
	lab var lr_tavg_GMFD_adm1_avg "adm1 annual average temperature - GMFD (sample average)"
	lab var lr_tavg_BEST_adm1_avg "adm1 annual average temperature - BEST (sample average)"
	lab var tmax_cdd_20C_GMFD_adm1 "adm1 annual CDDs - GMFD"
	lab var tmax_cdd_20C_BEST_adm1 "adm1 annual CDDs - BEST"
	lab var tmax_hdd_20C_GMFD_adm1 "adm1 annual HDDs - GMFD"
	lab var tmax_hdd_20C_BEST_adm1 "adm1 annual HDDs - BEST"
	lab var lr_cdd_20C_GMFD_adm1_avg "adm1 annual CDDs - GMFD (sample average)"
	lab var lr_cdd_20C_BEST_adm1_avg "adm1 annual CDDs - BEST (sample average)"
	lab var lr_hdd_20C_GMFD_adm1_avg "adm1 annual HDDs - GMFD (sample average)"
	lab var lr_hdd_20C_BEST_adm1_avg "adm1 annual HDDs - BEST (sample average)"
	lab var tavg_cdd_25C_GMFD "CDDs calculated using tavg linear spline at 25C - GMFD"
	lab var tavg_cdd_25C_BEST "CDDs calculated using tavg linear spline at 25C - BEST"
	lab var tavg_hdd_0C_GMFD "HDDs calculated using tavg linear spline at 0C - GMFD"
	lab var tavg_hdd_0C_BEST "HDDs calculated using tavg linear spline at 0C - BEST"
		
	lab def agegroup 0 "total" 1 "0-4" 2 "5-64" 3 "65+"
	lab val agegroup agegroup

	* save
	compress
	save "$data_dir/3_final/global_mortality_panel_public.dta", replace
}
