/*=======================================================================

Creator: Jingyuan

Purpose: 
	1) Imports and cleans mortality data
	2) Merges income data
	3) Merges climate data
	4) Appendix: 
	   how I cleaned the mortality data, area data, income data, and merged key
		4.1) Appendix A: merged key
		4.2) Appendix B: income data
		4.3) Appendix C: population data
		4.4) Appendix D: mortality counts and rates

==========================================================================*/


*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************

/* global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do" */

local FRA_raw "$cntry_dir/FRA"
local outdir "$data_dir/2_cleaned"

local appendix 0

*****************************************************************************
* 			Part A. France ADM2 mortality data								*
*****************************************************************************


* 1. import death count data 
use "`FRA_raw'/Mortality/Death_ADM2_France.dta", clear

* 2. collapse to 3 age groups
* generate agegrp var
gen agegrp = .
replace agegrp = 2 if age <= 59
replace agegrp = 3 if age >= 60
replace agegrp = 0 if age == 999

* collaspe to 3 age groups
drop age
collapse (sum) num_of_death, by(agegrp adm2 year)

	label define agegrp_lbl 001 `"--"', replace
	label define agegrp_lbl 002 `"0-59"', add
	label define agegrp_lbl 003 `"60+"', add
	label define agegrp_lbl 000 `"total"', add
	label values agegrp agegrp_lbl

* 3. import population data and collaspe to 3 age groups
preserve
	
	* import population data and collaspe to age-groups
	use "`FRA_raw'/Population/Pop_ADM2_France.dta", clear
	gen agegrp = .
	replace agegrp = 2 if age <= 3
	replace agegrp = 3 if age >= 4
	replace agegrp = 0 if age == 0
	
	* collaspe to 3 age groups
	drop age
	collapse (sum) population, by(agegrp dept deptname year)
	
	label define agegrp_lbl 001 `"--"', replace
	label define agegrp_lbl 002 `"0-59"', add
	label define agegrp_lbl 003 `"60+"', add
	label define agegrp_lbl 000 `"total"', add
	label values agegrp agegrp_lbl

	* rename the key variable
	rename dept adm2
	
	* save
	tempfile pop
	save `pop', replace
	
restore

* 4. merge death count data with population data
merge 1:1 year adm2 agegrp using `pop'
drop _merge

* 5. merge-in merge key and double check
rename adm2 adm2_id

merge m:1 adm2_id using "`FRA_raw'/MergeKey/FranceMergeKey.dta"
order adm1_id adm1_name adm2_id adm2_name year agegrp num_of_death population
drop deptname
drop if _merge == 1
drop _merge

* 6. generate mortality
rename num_of_death deaths
gen deathrate = (deaths / population) * 100000 


* 7. clean 
label var adm1_id "1st subnational geographic level"
label var adm2_id "2nd subnational geographic level"
label var ID_1 	  "adm1 id from the shapefile and the population data"
label var ID_2 	  "adm2 id from the shapefile and the population data"
label var adm1_name "1st subnational geographic level"
label var adm2_name "2nd subnational geographic level"
label var NAME_1   	"adm1 id from the shapefile and the population data"
label var NAME_2    "adm2 id from the shapefile and the population data"
label var agegrp    "age group"

*************************************************************************
* 				PART B. Merge Income Data 						*			
*************************************************************************

* 1. merge in income data based on ADM1_name 
merge m:1 adm1_id year using "`FRA_raw'/Income/Income_ADM1_France.dta"
drop if _merge == 2
drop _merge
* ADM1 Corse does not have income data
drop ADM1_name


*************************************************************************
* 				PART C. Merge Climate Data & save output				*			
*************************************************************************

* 1. merge climate data
tostring ID_1, replace
tostring ID_2, replace
rename adm1_id adm1_id_string
rename adm2_id adm2_id_string

rename ID_1 adm1_id
rename ID_2 adm2_id

merge m:1 adm1_id adm2_id year using "`FRA_raw'/Climate/climate_FRA_1966_2010_adm2.dta" 
drop if _merge == 2
drop _merge

merge m:1 adm1_id year using "`FRA_raw'/Climate/climate_FRA_1966_2010_adm1.dta", keep(1 3) nogen

* 2. prep for append to other countries
gen adm0 = "France"
gen iso = "FRA"

rename adm1_name adm1
rename adm2_name adm2 
rename agegrp agegroup 

* 3. save
save "`outdir'/FRA_cleaned_merged.dta", replace

if `appendix' {

	*****************************************************************************
	* 			Appendix														*
	*			generate the intermediate income, mergekey, mortality data		*
	*****************************************************************************


	*****************************************************************************
	* 			Appendix A. merge key											*
	*****************************************************************************

	* 1. import the crosswalk file of death counts keys, and population keys (=shapefile (climate) keys)
	import excel using "`FRA_raw'/MergeKey/CombineAllSources.xlsx", sheet("combined") clear first


	* rename variables
	label var ID_1 "adm1 id from shapefile"
	label var ID_2 "adm2 id from shapefile"
	label var NAME_1 "adm1 name from shapefile"
	label var NAME_2 "adm2 name from shapefile"
	rename id_adm2 		adm2_id
	rename id_adm1		adm1_id
	rename adm1			adm1_name
	rename adm2 		adm2_name
	label var adm1_id "adm1 id from death counts data"
	label var adm2_id "adm2 id from death counts data"
	label var adm1_name "adm1 name from death counts data"
	label var adm2_name "adm2 name from death counts data"
		
	* 2. clean
	replace adm2_id = "01" if adm2_id == "1"
	replace adm2_id = "02" if adm2_id == "2"
	replace adm2_id = "03" if adm2_id == "3"
	replace adm2_id = "04" if adm2_id == "4"
	replace adm2_id = "05" if adm2_id == "5"
	replace adm2_id = "06" if adm2_id == "6"
	replace adm2_id = "07" if adm2_id == "7"
	replace adm2_id = "08" if adm2_id == "8"
	replace adm2_id = "09" if adm2_id == "9"

	* 3. save
	save "`FRA_raw'/MergeKey/FranceMergeKey.dta", replace

		

	*****************************************************************************
	* 			Appendix B. import and clean France ADM1 income data 			*
	*****************************************************************************
	 
	* 1. import income data and keep mexico data
	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear

	* rename variables to match mortality data
	rename region ADM1_name
	rename *gdppc_adm0_PWT* *gdppc_adm0*
	rename *gdppc_adm1_rescaled* *gdppc_adm1*

	* only keep rescaled & interpolated income data
	keep if countrycode == "FRA"
	keep ADM1_name year *gdppc_adm*

	* 2. generate adm1 id
	gen adm1_id = .
	order adm1_id, b(ADM1_name)
	replace adm1_id =	1	if ADM1_name == "Alsace"
	replace adm1_id =	2	if ADM1_name == "Aquitaine"
	replace adm1_id =	3	if ADM1_name == "Auvergne"
	replace adm1_id =	4	if ADM1_name == "Basse-Normandie"
	replace adm1_id =	5	if ADM1_name == "Bourgogne"
	replace adm1_id =	6	if ADM1_name == "Bretagne"
	replace adm1_id =	7	if ADM1_name == "Centre"
	replace adm1_id =	8	if ADM1_name == "Champagne-Ardenne"
	replace adm1_id =	10	if ADM1_name == "Franche-Comt"
	replace adm1_id =	11	if ADM1_name == "Haute-Normandie"
	replace adm1_id =	13	if ADM1_name == "Languedoc-Roussillon"
	replace adm1_id =	14	if ADM1_name == "Limousin"
	replace adm1_id =	15	if ADM1_name == "Lorraine"
	replace adm1_id =	16	if ADM1_name == "Midi-Pyrnes"
	replace adm1_id =	17	if ADM1_name == "Nord - Pas-de-Calais"
	replace adm1_id =	18	if ADM1_name == "Pays de la Loire"
	replace adm1_id =	19	if ADM1_name == "Picardie"
	replace adm1_id =	20	if ADM1_name == "Poitou-Charentes"
	replace adm1_id =	21	if ADM1_name == "Provence-Cte d'Azur-Corse"
	replace adm1_id =	22	if ADM1_name == "Rhne-Alpes"
	replace adm1_id =	12	if ADM1_name == "ële-de-France"
	drop if adm1_id == .
	* add one missing adm1
	preserve
		keep year gdppc_adm0 gdppc_adm0_13br loggdppc_adm0 loggdppc_adm0_13br
		duplicates drop
		tempfile addoneadm1
		save `addoneadm1', replace
	restore
	append using `addoneadm1'
	replace adm1_id = 9 if adm1_id == .
	replace ADM1_name = "Corse" if adm1_id == 9


	* 3. save
	save "`FRA_raw'/Income/Income_ADM1_France.dta", replace


	*****************************************************************************
	* 			Appendix C. import and clean France population data				*
	*****************************************************************************

	* 1. import raw population data 
	import delimited using "`FRA_raw'/Population/Raw/POP_1998-2012_MONTH.csv", clear

	keep year month dept deptname totage1 totage2 totage3 totage4 totage5
	drop if totage1 == .
	drop month

	* 2. reshape to long
	gen totage0 = totage1 + totage2 + totage3 + totage4 + totage5

	reshape long totage, i(year dept deptname) j(age)
	rename totage population

	label define agegrp_lbl 001 `"0-19"', replace
	label define agegrp_lbl 002 `"20-39"', add
	label define agegrp_lbl 003 `"40-59"', add
	label define agegrp_lbl 004 `"60-79"', add
	label define agegrp_lbl 005 `"80+"', add
	label define agegrp_lbl 000 `"total"', add
	label values age agegrp_lbl

	* 3. save
	save "`FRA_raw'/Population/Pop_ADM2_France.dta", replace


	*****************************************************************************
	* 			Appendix D. death counts										*
	*****************************************************************************

	* 1. import data for all the years

	* initialize a blank file
	tempfile death_eachyear
	clear
	set obs 0
	gen year = .
	gen num_of_obs = .
	gen age = .
	gen adm2 = ""
	save `death_eachyear', replace 

	* for each year, store values in the initialized file:
	forvalues year = 1998(1)2012 {

		* 1.1. import mortality data
		import delimited using "`FRA_raw'/Mortality/Raw/DEC`year'.csv", clear

		* 1.2. keep useful variables
		rename adecc4 year
		rename mdecc2 month
		rename anaisc4 year_birth
		rename depdomc2 adm2
		
		keep year month year_birth adm2
		label var year "year of death (1998-2012)"
		label var month "month of death"
		label var year_birth "year of birth"
		label var adm2 "department of residence"
		
		gen age = year - year_birth
		label var age "age of death"
		drop year_birth
		
		gen num_of_obs = 1
		
		* 1.3. collapse to adm2 level
		replace adm2 = "97" if substr(adm2,1,2) == "97" 
		replace adm2 = "98" if substr(adm2,1,2) == "98" 
		collapse (sum) num_of_obs, by(adm2 age year)
		
		* 1.4. save and append
		append using `death_eachyear'
		save `death_eachyear', replace

	}
	*


	* 2. fill the panel
	* 2.1 reshape to wide
	reshape wide num_of_obs, i(adm2 year) j(age)

	* 2.2 add the adm2-years that do not have any death
	* (1) get a continuous adm2 id
	egen adm2_id_cont = group(adm2)

	* (2) add the first year and the last year for all adm2s
	sum adm2_id_cont, meanonly
	forvalues i = 1(1)`r(max)' {
		* add the first year
		quietly sum if adm2_id_cont == `i' & year == 1998
		if `r(N)' == 0 {
			* display the current adm2
			tempvar order
			gene `order'=_n 
			summ `order' if adm2_id_cont == `i', meanonly
			local index = `r(min)'
			local adm2  = adm2[`index']
			drop `order'
			
			disp("Current Adm2: `i'; Adm2 ID: `adm2'")
			disp("add in year 1990")
			* add obs
			local new = _N + 1
			quietly set obs `new'
			quietly replace adm2_id_cont = `i' if adm2_id_cont == .
			quietly replace adm2 = "`adm2'" if adm2 == ""
			quietly replace year = 1990 if year == .
		}
		*
		
		* add the last year
		quietly sum if adm2_id_cont == `i' & year == 2012
		if `r(N)' == 0 {
			* display the current adm2
			tempvar order
			gene `order'=_n 
			summ `order' if adm2_id_cont == `i', meanonly
			local index = `r(min)'
			local adm2  = adm2[`index']
			drop `order'
			
			disp("Current Adm2: `i'; Adm2 ID: `adm2'")
			disp("add in year 1990")
			* add obs
			local new = _N + 1
			quietly set obs `new'
			quietly replace adm2_id_cont = `i' if adm2_id_cont == .
			quietly replace adm2 = "`adm2'" if adm2 == ""
			quietly replace year = 2012 if year == .
		}
	}
	*

	* (3) fill the panel
	tsset adm2_id_cont year
	tsfill 
	drop adm2_id_cont

	* 2.3 change missing values to 0, and collapse 100+ to one group
	forvalues i = 0(1)120 {
		replace num_of_obs`i' = 0 if num_of_obs`i' == .
	}
	replace num_of_obs125 = 0 if num_of_obs125 == .
	*
	forvalues i = 101(1)120{
		replace num_of_obs100 = num_of_obs100 + num_of_obs`i'
		drop num_of_obs`i'
	}
	replace num_of_obs100 = num_of_obs100 + num_of_obs125
	drop num_of_obs125
	*

	* 3. reshape to long, generate variable age, and label it
	* 3.1 generate tot number of death
	gen num_of_obs999 = num_of_obs1
	forvalues i = 2(1)100{
		replace num_of_obs999 = num_of_obs999 + num_of_obs`i'
	}
	*

	* 3.2 reshape
	reshape long num_of_obs , i(year adm2) j(age)
	rename num_of_obs num_of_death

		label define age_lbl 999 `"total"', replace
		label values age age_lbl
		
	sort adm2 year


	* 4. save
	save "`FRA_raw'/Mortality/Death_ADM2_France.dta", replace

}
