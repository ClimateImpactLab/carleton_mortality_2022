/*=======================================================================
Creator: Greg Dobbels, gdobbels@uchicago.edu

Purpose: 
	1) Imports and cleans Japan mortality data
	2) Merges income data
	3) Merges climate data

==========================================================================*/


*****************************************************************************
* 						PART A. Initializing		 					*
*****************************************************************************

/* global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do" */

local JPN_raw "$cntry_dir/JPN"
local outdir "$data_dir/2_cleaned"

*****************************************************************************
* 			PART A. import mortality & population data	 					*
*****************************************************************************

* import & append mortality & population data
import delimited "`JPN_raw'/Mortality/JMD_data.csv", clear

* drop gender specific stats
keep year age death pop* pref_name

* clean up 
rename death deaths
rename pop population
rename pref_name adm1

* use male population + female population as total population, since 
* 	original population does not match 
replace population = pop_female + pop_male

* calculate all ages and append 
preserve 
	gen agegroup = 0 
	collapse (sum) deaths population, by(adm* year agegroup)
	tempfile allage
	save `allage'
restore

* collapse to corresponding age groups
gen agegroup = 3
replace agegroup = 2 if age < 65
replace agegroup = 1 if age < 5
collapse (sum) deaths population, by(adm* year agegroup)

*append all age mortality 
append using `allage'

* create deathrate 
gen deathrate = (deaths / population) * 100000

*************************************************************************
* 				PART B. Import & Merge Income Data 						*			
*************************************************************************

preserve 

	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear 
		 
		* rename variables to match mortality data
		rename region adm1
		rename *gdppc_adm0_PWT* *gdppc_adm0*
		rename *gdppc_adm1_rescaled* *gdppc_adm1*

		* only keep rescaled & interpolated income data
		keep if countrycode == "JPN"
		keep adm1 year *gdppc_adm*

		* standardize english spelling
		replace adm1 = "Gunma" if adm1 == "Gumma"
		

	tempfile income
	save "`income'"	

restore

	* merge in income data
	merge m:1 adm1 year using "`income'", keep(1 3) assert(2 3) nogen 

*****************************************************************************
* 			PART C. import ID crosswalk	for climate data merge				*
*****************************************************************************
preserve 

	import delimited "`JPN_raw'/Shapefile/JPN_adm1.csv", case(preserve) stringcols(_all) clear

	* standardize names
	keep ID_0 ID_1 NAME_1
	rename NAME_1 adm1 
	rename ID_* adm*_id

	* update names to match mortality data
	replace adm1 = "Hyogo" if adm1 == "Hy?ìgo"
	replace adm1 = "Nagasaki" if adm1 == "Naoasaki" 

	tempfile shape_id_crosswalk
	save `shape_id_crosswalk'

restore 

* merge in crosswalk 
merge m:1 adm1 using "`shape_id_crosswalk'", assert(3) nogen 

*************************************************************************
* 				PART D. Merge Climate Data & save output				*			
*************************************************************************

*merge climate data
merge m:1 adm1_id year using "`JPN_raw'/Climate/climate_JPN_1966_2010_adm2.dta", keep(1 3) nogen
merge m:1 adm1_id year using "`JPN_raw'/Climate/climate_JPN_1966_2010_adm1.dta", keep(1 3) nogen

* clean up 
gen iso = "JPN"
gen adm0 = "Japan"
drop adm0_id 


save "`outdir'/JPN_cleaned_merged.dta", replace
