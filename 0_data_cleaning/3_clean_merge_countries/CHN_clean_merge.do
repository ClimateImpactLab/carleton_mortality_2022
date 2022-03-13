/*=======================================================================

Purpose: 
	1) Imports and cleans mortality data
	2) Merges income data
	3) Merges climate data
	4) Appendix: 
	   Detailed information on cleaning mortality data, area data, income data, 
	   and merged key.
		4.1) Appendix A: merged key
		4.2) Appendix B: income data
		4.3) Appendix C: area

Note: This file is not run in the clean.do public release version due to 
the mortality data not being publically available

==========================================================================*/

*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************

if "$REPO" == "" {
	global REPO: env REPO
	global DB: env DB 
	global OUTPUT: env OUTPUT 

	do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

local CHN_raw "$cntry_dir/CHN"
local outdir "$data_dir/2_cleaned"

local appendix 0

*****************************************************************************
* 			Part A. China ADM2 mortality data								*
*****************************************************************************
* 1. import data 
use "`CHN_raw'/Mortality/LifeTable_AllAges_04_12.dta", clear
append using "`CHN_raw'/Mortality/LifeTable_AllAges_91_00.dta"

* 2. clean
keep if sex == 0
keep year death1 population age_group overall_sequ
gen agegroup = 1 if age_group <= 5
replace agegroup = 2 if age_group <= 65 & age_group > 5
replace agegroup = 3 if age_group > 65
drop age_group
rename death1 deaths
collapse (sum) population deaths, by(year overall_sequ agegroup)


* 3. merge-in all age death
preserve
	collapse (sum) population deaths, by(year overall_sequ)
	gen agegroup = 0 
	tempfile allage
	save `allage'
restore

append using `allage'

* 4. label agegrp
	label define agegrp_lbl 001 `"0-4"', replace
	label define agegrp_lbl 002 `"5-64"', add
	label define agegrp_lbl 003 `"65+"', add
	label define agegrp_lbl 000 `"total"', add
	label values agegroup agegrp_lbl

* 5. clean and save
gen deathrate = (deaths / population) * 100000

*************************************************************************
* 				PART B. Merge Income Data 						*			
*************************************************************************

* 1. merge in mergekey
merge m:1 overall_sequ using "`CHN_raw'/MergeKey/ChinaMergeKey.dta"
drop _merge

* 2. merge in income data based on ADM1_name 
merge m:1 ADM1_name year using "`CHN_raw'/Income/Income_ADM1_China.dta"
drop if _merge == 2
drop _merge

*************************************************************************
* 				PART C. Merge Climate Data & save output				*			
*************************************************************************

* 1. merge climate data
tostring cntygb, gen(CNTYGB)

merge m:1 CNTYGB year using "`CHN_raw'/Climate/climate_CHN_1966_2010_adm2.dta"

drop if _merge == 2
drop _merge

gen PROVGB = substr(CNTYGB,1,2)
merge m:1 PROVGB year using "`CHN_raw'/Climate/climate_CHN_1966_2010_adm1.dta", keep(1 3) nogen

* 2. clean-up
rename cntygb adm2_id
rename ADM1_code adm1_id
rename ADM1_name adm1 
rename ADM2_name adm2

drop CNTYGB overall_sequ CITYGB PROVGB
sort adm1_id adm2_id year agegroup
order adm1_id adm2_id adm1 adm2 year agegroup 
tostring adm1_id, replace
tostring adm2_id, replace 

gen adm0 = "China"
gen iso = "CHN"

* 3. save
save "`outdir'/CHN_cleaned_merged.dta", replace

if `appendix' {

	*****************************************************************************
	* 			Appendix														*
	*			generate the intermediate income, mergekey, area data			*
	*****************************************************************************


	*****************************************************************************
	* 			Appendix A. import and clean China ADM2 merge key 				*
	*****************************************************************************

	* 1. Key overall_sequ and Key cntygb
	* 1.1 import the data from QGIS
	import delimited "`CHN_raw'/MergeKey/Raw/dsp_chn2000_linkfile.csv", encoding(ISO-8859-1)clear

	* 1.2 keep the key variables
	rename overall_se overall_sequ 
	keep overall_sequ cntygb
	sort overall_sequ

	* 1.3 one missing key variable
	replace cntygb = 440508 if overall_sequ == 190 // see snapshot - the dsp fell just outside county so didn't pick it up but use that climate data

	* 1.4 one duplicated cntygb ID:
	* data point 100 and data point 189 are both in county cntygb 431281. 
	* data point 189 are from raw mortality data 91-00; data point 100 are from raw mortality data 04-12

	* 2. Key cntygb and Key adm2 name
	* 2.1 merge in adm2 names
	merge m:1 cntygb using "`CHN_raw'/MergeKey/Raw/adm2name-CNTYGBcode.dta"
	* m:1 instead of 1:1 because the duplicated cntygb ID problem descript above
	drop if _merge == 2
	drop _merge 

	* 2.2 clean the ADM2 name variable
	split EPROV_ECNTY, p(-)
	rename EPROV_ECNTY1 ADM1_name
	rename EPROV_ECNTY2 ADM2_name
	rename EPROV_ECNTY ADM1_ADM2_name

	* 2.3 duplicated EPROV_ECNTY name
	* There is 2 county named "Jiangsu-Gulou" because we do not record city name
	* 320106 Gulou county, Nanjing City, Jiangsu Province
	* 320302 Golou county, Xuzhou City, Jiangsu Province  

	* 2.4 generate province code
	gen ADM1_code = floor(cntygb/10000)

	* 2.5 Shaanxi Prov
	replace ADM1_name = "Shaanxi" if ADM1_code == 61
	replace ADM1_name = "Tibet" if ADM1_name == "Xicang"

	* 3. save
	save "`CHN_raw'/MergeKey/ChinaMergeKey.dta", replace


	*****************************************************************************
	* 			Appendix B. import and clean China ADM1 income data 			*
	*****************************************************************************

	* 1. import income data and keep China data
	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear

			* rename variables to match mortality data
			rename region ADM1_name
			rename *gdppc_adm0_PWT* *gdppc_adm0*
			rename *gdppc_adm1_rescaled* *gdppc_adm1*

			* only keep rescaled & interpolated income data
			keep if countrycode == "CHN"
			keep ADM1_name year *gdppc_adm*

	* 2. expand the observations that combine 2 or more provinces
	* and make sure the ADM1 name is the same with the mergekey file

	* 2.1 Gansu w/ Inner Mongolia & Ningxia
	expand 2 if ADM1_name == "Gansu w/ Inner Mongolia & Ningxia", gen(new)
	replace ADM1_name = "Gansu" if ADM1_name == "Gansu w/ Inner Mongolia & Ningxia" & new == 1
	drop new

	expand 2 if ADM1_name == "Gansu w/ Inner Mongolia & Ningxia", gen(new)
	replace ADM1_name = "Ningxia" if ADM1_name == "Gansu w/ Inner Mongolia & Ningxia" & new == 1
	drop new

	replace ADM1_name = "Neimenggu" if ADM1_name == "Gansu w/ Inner Mongolia & Ningxia" 

	* 2.2 Guangdong w/ Hainan
	expand 2 if ADM1_name == "Guangdong w/ Hainan", gen(new)
	replace ADM1_name = "Guangdong" if ADM1_name == "Guangdong w/ Hainan" & new == 1
	drop new

	replace ADM1_name = "Hainan" if ADM1_name == "Guangdong w/ Hainan" 


	* 2.2 Sichuan w/ Chongqing
	expand 2 if ADM1_name == "Sichuan w/ Chongqing", gen(new)
	replace ADM1_name = "Sichuan" if ADM1_name == "Sichuan w/ Chongqing" & new == 1
	drop new

	replace ADM1_name = "Chongqing" if ADM1_name == "Sichuan w/ Chongqing" 


	* 3. save
	save "`CHN_raw'/Income/Income_ADM1_China.dta", replace



	*****************************************************************************
	* 			Appendix C. China ADM2 area data								*
	*****************************************************************************
	local CHN_raw "$cntry_dir/CHN"

	* 1. import data 
	import delimited "`CHN_raw'/Area/RawFromQGIS/area.csv", encoding(ISO-8859-1)clear

	replace area_m = 0 if area_m == .
	collapse (sum) area_m, by (cntygb)
	* There might be duplicated cntygb ID

	gen areakm = area_m/1000000
	keep cntygb areakm area_m
	save "`CHN_raw'/Area/Area_ADM2_China.dta", replace

}
