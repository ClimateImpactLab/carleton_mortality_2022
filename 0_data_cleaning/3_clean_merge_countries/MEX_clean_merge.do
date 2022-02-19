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
* 						PART 0. Initializing		 					    *
*****************************************************************************

/* global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do" */

local MEX_raw "$cntry_dir/MEX"
local outdir "$data_dir/2_cleaned"

local appendix 0

*****************************************************************************
* 			Part A. Mexico ADM2 mortality data								*
*****************************************************************************

* 1. import death count data 
use "`MEX_raw'/Mortality/Death_ADM2_Mexico.dta", clear

* 2. collapse to 3 age groups
* drop unspecified age 
drop if age == 30
* reshape to wide
reshape wide num_of_death, i(adm1_id adm2_id year) j(age)
* collaspe to 3 age groups
egen deaths_agegrp1 = rowtotal(num_of_death1 num_of_death2 num_of_death3 num_of_death4 num_of_death5)
egen deaths_agegrp2 = rowtotal(num_of_death6 num_of_death7 num_of_death8 num_of_death9 ///
							  num_of_death10 num_of_death11 num_of_death12 num_of_death13 ///
							  num_of_death14 num_of_death15 num_of_death16 num_of_death17)
egen deaths_agegrp3 = rowtotal(num_of_death18 num_of_death19 num_of_death20 num_of_death21 ///
							  num_of_death22 num_of_death23 num_of_death24 num_of_death25 ///
							  num_of_death26 num_of_death27 num_of_death28 num_of_death29)
gen deaths_tot      = num_of_death99

keep adm1_id adm2_id year deaths*

* 3. import population data and collaspe to 3 age groups
preserve
	local MEX_raw "$cntry_dir/MEX"
	* import population data and collaspe to age-groups
	use "`MEX_raw'/Population/Pop_ADM2_Mexico.dta", clear
	keep GEOID adm2_label year age pop_replicated pop_new 
	reshape wide pop_replicated pop_new, i(GEOID adm2_label year) j(age)
	foreach version in "replicated" "new" {
		gen pop_`version'_agegrp1 = pop_`version'1
		gen pop_`version'_agegrp2 = pop_`version'2  + pop_`version'3  + pop_`version'4  + pop_`version'5 + ///
									pop_`version'6  + pop_`version'7  + pop_`version'8  + pop_`version'9 + ///
									pop_`version'10 + pop_`version'11 + pop_`version'12 + pop_`version'13
		gen pop_`version'_agegrp3 = pop_`version'14 + pop_`version'15 + pop_`version'16 + pop_`version'17 
		gen pop_`version'_tot	  = pop_`version'99
	}
	*
	keep GEOID adm2_label year pop*agegrp* pop*tot
	
	* reshape to long
	rename pop_replicated_tot pop_replicated_agegrp0
	rename pop_new_tot pop_new_agegrp0
	reshape long pop_replicated_agegrp pop_new_agegrp, i(adm2_label GEOID year) j(agegroup)
	rename *_agegrp *
	
	label define agegrp_lbl 001 `"0-4"', replace
	label define agegrp_lbl 002 `"5-64"', add
	label define agegrp_lbl 003 `"65+"', add
	label define agegrp_lbl 000 `"total"', add
	label values agegroup agegrp_lbl
	
	* save
	tempfile pop
	save `pop', replace
	
restore

* 4. merge death count data with population data

* 4.1 reshape to long and make it ready to merge
rename deaths_tot deaths_agegrp0
reshape long deaths_agegrp, i(adm1_id adm2_id year) j(agegroup)

	label define agegrp_lbl 001 `"0-4"', replace
	label define agegrp_lbl 002 `"5-64"', add
	label define agegrp_lbl 003 `"65+"', add
	label define agegrp_lbl 000 `"total"', add
	label values agegroup agegrp_lbl

rename *_agegrp *
drop if adm2_id == 999

* 4.1 merge in the merge keys
merge m:1 adm1_id adm2_id using "`MEX_raw'/MergeKey/MexicoMergeKey.dta"
drop _merge
merge m:1 GEOID year agegroup using `pop'
drop if _merge == 2
drop _merge

* collapse to 2331 adm2 units from 2457 adm2 units
drop adm2_id adm2_name LABEL
collapse (sum) deaths, by(agegroup year adm1_id adm1_name adm2_label GEOID pop_new pop_replicated)


* 5. generate mortality
foreach version in "replicated" "new" {
	gen deathrate_`version' = (deaths / pop_`version') * 100000
}
*

* 6. clean and save
* 6.1 clean IDs
gen adm2_id = GEOID - 484 * 1000000 - adm1_id * 1000
order adm1_id adm2_id GEOID adm1_name adm2_label year agegroup
sort GEOID year agegroup

label var adm1_id "1st subnational geographic level [consistent boundaries over time]"
label var adm2_id "2nd subnational geographic level [consistent boundaries over time]"
label var GEOID   "adm2 id from the shapefile and the population data"
label var adm1_name "1st subnational geographic level [consistent boundaries over time]"
label var adm1_name "1st subnational geographic level [consistent boundaries over time]"
label var agegroup "age group"

rename pop_new population

*************************************************************************
* 				PART B. Merge Income Data 						*			
*************************************************************************

* 1. merge in income data based on ADM1_name 
merge m:1 adm1_id year using "`MEX_raw'/Income/Income_ADM1_Mexico.dta"
drop if _merge == 2
drop _merge
drop ADM1_name

*************************************************************************
* 				PART C. Merge Climate Data & save output				*			
*************************************************************************

* 1. merge climate data
tostring GEOID, replace

merge m:1 GEOID year using "`MEX_raw'/Climate/climate_MEX_1966_2010_adm2.dta"
drop if _merge == 2
drop _merge

tostring adm1_id, replace
merge m:1 adm1_id year using "`MEX_raw'/Climate/climate_MEX_1966_2010_adm1.dta", keep(1 3) nogen
 
* 2. prep for append to other countries
gen adm0 = "Mexico"
gen iso = "MEX"

rename adm1_name adm1
rename adm2_label adm2 

drop adm2_id
rename GEOID adm2_id


* 2. save
rename deathrate_new deathrate
save "`outdir'/MEX_cleaned_merged.dta", replace


if `appendix' {


	*****************************************************************************
	* 			Appendix														*
	*			generate the intermediate income, mergekey, mortality data		*
	*****************************************************************************


	*****************************************************************************
	* 			Appendix A. merge key											*
	*****************************************************************************



	* 1. import the crosswalk file of death counts keys, and population keys (=shapefile (climate) keys)
	import excel using "`MEX_raw'/MergeKey/CombineAllSources.xlsx", sheet("combined") clear first
	drop if CVE_ENT > 32

		* rename variables
		rename CVE_ENT adm1_id
		rename CVE_MUN adm2_id
		rename NOMBRE adm2_name
		label var adm1_id "adm1 id from death counts data"
		label var adm2_id "adm2 id from death counts data"
		label var adm2_name "adm2 name from death counts data"
		label var LABEL "adm2 name from the shapefile and the population data"
		label var GEOID "adm2 id from the shapefile and the population data"
		
		keep adm1_id adm2_id adm2_name LABEL GEOID
		
		
	* 2. get the cross walk for adm1 id and la porta adm1 name

		* generate adm1 name variable
		gen adm1_name = ""
		forvalues i = 1(1)32 {
			preserve
				keep if adm2_id == 0 & adm1_id == `i'
				local name = adm2_name
			restore
			replace adm1_name = "`name'" if adm1_id == `i'
		}
		*
		order adm1_name, b(adm2_name)
		
		* double check
		count if adm1_name != adm2_name & adm2_id == 0
		
		* drop obs
		drop if adm2_id == 0
		drop if adm2_id >= 900

	* 3. save
	save "`MEX_raw'/MergeKey/MexicoMergeKey.dta", replace


	*****************************************************************************
	* 			Appendix B. import and clean Mexico ADM1 income data 			*
	*****************************************************************************

	* 1. import income data and keep mexico data
	use "$data_dir/1_raw/Income/pwt_income_adm1.dta", clear

			* rename variables to match mortality data
			rename region ADM1_name
			rename *gdppc_adm0_PWT* *gdppc_adm0*
			rename *gdppc_adm1_rescaled* *gdppc_adm1*

			* only keep rescaled & interpolated income data
			keep if countrycode == "MEX"
			keep ADM1_name year *gdppc_adm*

	* 2. generate adm1 id
	gen adm1_id = .
	order adm1_id, b(ADM1_name)
	replace adm1_id =	1	 if ADM1_name == "Aguascalientes"
	replace adm1_id =	2	 if ADM1_name == "Baja California Norte"
	replace adm1_id =	3	 if ADM1_name == "Baja California Sur"
	replace adm1_id =	4	 if ADM1_name == "Campeche"
	replace adm1_id =	7	 if ADM1_name == "Chiapas"
	replace adm1_id =	8	 if ADM1_name == "Chihuahua"
	replace adm1_id =	5	 if ADM1_name == "Coahuila"
	replace adm1_id =	6	 if ADM1_name == "Colima"
	replace adm1_id =	9	 if ADM1_name == "Distrito Federal"
	replace adm1_id =	10	 if ADM1_name == "Durango"
	replace adm1_id =	11	 if ADM1_name == "Guanajuato"
	replace adm1_id =	12	 if ADM1_name == "Guerrero"
	replace adm1_id =	13	 if ADM1_name == "Hidalgo"
	replace adm1_id =	14	 if ADM1_name == "Jalisco"
	replace adm1_id =	15	 if ADM1_name == "Mexico"
	replace adm1_id =	16	 if ADM1_name == "Michoacan"
	replace adm1_id =	17	 if ADM1_name == "Morelos"
	replace adm1_id =	18	 if ADM1_name == "Nayarit"
	replace adm1_id =	19	 if ADM1_name == "Nuevo Leon"
	replace adm1_id =	20	 if ADM1_name == "Oaxaca"
	replace adm1_id =	21	 if ADM1_name == "Puebla"
	replace adm1_id =	22	 if ADM1_name == "Queretaro"
	replace adm1_id =	23	 if ADM1_name == "Quintana Roo"
	replace adm1_id =	24	 if ADM1_name == "San Luis Potosi"
	replace adm1_id =	25	 if ADM1_name == "Sinaloa"
	replace adm1_id =	26	 if ADM1_name == "Sonora"
	replace adm1_id =	27	 if ADM1_name == "Tabasco"
	replace adm1_id =	28	 if ADM1_name == "Tamaulipas"
	replace adm1_id =	29	 if ADM1_name == "Tlaxcala"
	replace adm1_id =	30	 if ADM1_name == "Veracruz"
	replace adm1_id =	31	 if ADM1_name == "Yucatan"
	replace adm1_id =	32	 if ADM1_name == "Zacatecas"

	* 3. save
	save "`MEX_raw'/Income/Income_ADM1_Mexico.dta", replace

			
	*****************************************************************************
	* 			Appendix C. import and clean Mexico population data				*
	*****************************************************************************

	* 1. import raw population data 
	import delimited using "`MEX_raw'/Population/Raw/IPUMS_2018updated/data_4795_IPUMS_MX_HSLAD_1990_2015.csv", clear

	keep geo2_mx_label geo2_mx ///
			totpop_geo2_mx_mx*a ///
			pop80_geo2_mx_mx*a pop7579_geo2_mx_mx*a pop7074_geo2_mx_mx*a pop6569_geo2_mx_mx*a ///
			pop6064_geo2_mx_mx*a pop5559_geo2_mx_mx*a pop5054_geo2_mx_mx*a pop4549_geo2_mx_mx*a ///
			pop4044_geo2_mx_mx*a pop3539_geo2_mx_mx*a pop3034_geo2_mx_mx*a pop2529_geo2_mx_mx*a ///
			pop2024_geo2_mx_mx*a pop1519_geo2_mx_mx*a pop1014_geo2_mx_mx*a pop0509_geo2_mx_mx*a ///
			pop0004_geo2_mx_mx*a

	* 2. reshape to long (and generate year variable)
	rename *_mx*a *_*
	reshape long totpop_geo2_mx_ ///
			pop80_geo2_mx_ pop7579_geo2_mx_ pop7074_geo2_mx_ pop6569_geo2_mx_ ///
			pop6064_geo2_mx_ pop5559_geo2_mx_ pop5054_geo2_mx_ pop4549_geo2_mx_ ///
			pop4044_geo2_mx_ pop3539_geo2_mx_ pop3034_geo2_mx_ pop2529_geo2_mx_ ///
			pop2024_geo2_mx_ pop1519_geo2_mx_ pop1014_geo2_mx_ pop0509_geo2_mx_ ///
			pop0004_geo2_mx_ ///
			, i(geo2_mx_label geo2_mx) j(year)

	rename pop*_geo2_mx_ pop*
	rename totpop_geo2_mx_ pop_tot

	* 3. check the data
	* check whether age specific pop add up to total pop
	egen pop_addup = rowtotal(pop80 pop7579 pop7074 pop6569 pop6064 pop5559 pop5054 ///
								pop4549 pop4044 pop3539 pop3034 pop2529 pop2024 ///
								pop1519 pop1014 pop0509 pop0004)
	count if pop_tot != pop_addup & pop_tot != .
	* 0
	drop pop_addup


	* 4. reshape to adm2-age from adm2-year
	* 4.1 label the age groups
	rename pop0004 pop1
	rename pop0509 pop2
	rename pop1014 pop3
	rename pop1519 pop4
	rename pop2024 pop5
	rename pop2529 pop6
	rename pop3034 pop7
	rename pop3539 pop8
	rename pop4044 pop9
	rename pop4549 pop10
	rename pop5054 pop11
	rename pop5559 pop12
	rename pop6064 pop13
	rename pop6569 pop14
	rename pop7074 pop15
	rename pop7579 pop16
	rename pop80   pop17
	rename pop_tot pop99

	* 4.2 reshape to wide (and cancel the variable year)
	rename pop* pop*_ 
	reshape wide pop*_ , i(geo2_mx_label geo2_mx) j(year)

	* 4.3 reshape to long (and generate variable age)
	forvalues y = 1990(5)2015 {
		rename pop*_`y' pop`y'_* 
	}
	*
	reshape long pop1990_ pop1995_ pop2000_ pop2005_ pop2010_ pop2015_ , i(geo2_mx_label geo2_mx) j(age)
	rename pop*_ pop*


	* 5. interpolate to fill the 1990-2012 panel

	* 5.1 Linearly interpolate intervening years. (five years)
	forvalue y_start = 1990(5)2010 {
		local y_end   = `y_start' + 5
		forvalues i = 1(1)4 {
			local year = `y_start' + `i'
			gen pop`year' = .
			replace pop`year' = `i' * (pop`y_end' - pop`y_start') / 5 + pop`y_start'	
		}
		*
	}
	*

	* 5.2 Linearly interpolate intervening years (ten years, for 1995 missing municipalities).
		local y_start = 1990
		local y_end   = 2000
		forvalues i = 1(1)9 {
			local year = `y_start' + `i'
			gen pop_10y_`year' = .
			replace pop_10y_`year' = `i' * (pop`y_end' - pop`y_start') / 10 + pop`y_start'	
		}
		*

	* 5.3 extrapolate 2011 and 2012 without using 2015 data
	* (to replicate the Seo's results generated at when 2015 data was not available)
		gen pop_ext_2011 = 6 * (pop2010 - pop2005)/5 + pop2005 
		gen pop_ext_2012 = 7 * (pop2010 - pop2005)/5 + pop2005 
		gen pop_ext_2013 = 8 * (pop2010 - pop2005)/5 + pop2005 
		gen pop_ext_2014 = 9 * (pop2010 - pop2005)/5 + pop2005 
		gen pop_ext_2015 = 10 * (pop2010 - pop2005)/5 + pop2005 
		
		forvalues i = 1(1)5 {
			replace pop_ext_201`i' = 0 if pop_ext_201`i' < 0
		}
		*
		
	* 6. clean and organize the dataset

	* 6.1 reshape to long (and generate variable year)
	reshape long pop pop_10y_ pop_ext_ , i(geo2_mx_label geo2_mx age) j(year)
	rename pop_10y_ pop_int_10y
	rename pop_ext_ pop_ext

	* 6.2 re-check whether tot = sum of each age groups after interpolation
	* might not because we did some corrections for pop <0 after the linear interpolation
	reshape wide pop pop_ext pop_int_10y, i(geo2_mx_label geo2_mx year) j(age)

	foreach var in "pop" "pop_ext" "pop_int_10y" {
		egen `var'_addup = rowtotal(`var'1  `var'2  `var'3  `var'4  `var'5  `var'6  ///
									`var'7  `var'8  `var'9  `var'10 `var'11 `var'12 ///
									`var'13 `var'14 `var'15 `var'16 `var'17 ) ///
									, missing
		count if `var'99 != `var'_addup & `var'99 != . & `var'_addup != . 
	}
	*
	foreach var in "pop" "pop_ext" "pop_int_10y" {
		replace `var'99 = `var'_addup if `var'99 != `var'_addup
		drop `var'_addup
	}
	*
	reshape long pop pop_ext pop_int_10y, i(geo2_mx_label geo2_mx year) j(age)


	* 7. rename / label / rescale
	* 7.1 ID:
	format geo2_mx %9.0f
	rename geo2_mx GEOID 
	label var GEOID "2nd subnational geographic level [consistent boundaries over time]"

	rename geo2_mx_label adm2_label
	label var adm2_label "2nd subnational geographic unit name [consistent boundaries over time]"

	* 7.2 age
		label define age_lbl 001 `"0-4"', replace
		label define age_lbl 002 `"5-9"', add
		label define age_lbl 003 `"10-14"', add
		label define age_lbl 004 `"15-19"', add
		label define age_lbl 005 `"20-24"', add
		label define age_lbl 006 `"25-29"', add
		label define age_lbl 007 `"30-34"', add
		label define age_lbl 008 `"35-39"', add
		label define age_lbl 009 `"40-44"', add
		label define age_lbl 010 `"45-49"', add
		label define age_lbl 011 `"50-54"', add
		label define age_lbl 012 `"55-59"', add
		label define age_lbl 013 `"60-64"', add
		label define age_lbl 014 `"65-69"', add
		label define age_lbl 015 `"70-74"', add
		label define age_lbl 016 `"75-79"', add
		label define age_lbl 017 `"80+"', add
		label define age_lbl 099 `"total"', add
		label values age age_lbl

	* 7.3 population
	* (1) replicate Theo's version
	* for 1995 missed adm2s, use 10 year interpolation
	* for years after 2010, use 2005-2010 to extrapolate 
	gen pop_replicated = pop
	replace pop_replicated = pop_int_10y if pop_replicated == .
	replace pop_replicated = pop_ext if year >= 2011

	* (2) generate a new version
	* for all adm2s from 1990-2000, use 10 year interpolation
	* use 2010-2015 to interpolate year 2011-2014
	gen pop_new = pop
	replace pop_new = pop_int_10y if year > 1990 & year < 2000

	label var pop_replicated 	"replicated population (Theo's version)"
	label var pop_new 			"new population"
	label var pop				"interpolated population [5 year]"
	label var pop_int_10y		"interpolated population [10 year, 1990-2010 only]"
	label var pop_ext			"extrapolated population [2011-2012 only]"

	* 8. export several graphs to prove: 
	* (1) 1995 data is not reliable
	* (2) the adm0 level population might be wrong in magnitude
	* (3) the interpolated and extrapolated 2011-2014 pop are similar

	* 8.1 to prove that 1995 data is not reliable
	preserve 

		keep if year == 1990 | year == 1995 | year == 2000 | year == 2005 | year == 2010 | year == 2015
		
		* (1) drop the adm2s of which 1995 data are missing
		
		bysort GEOID: egen drop = count(pop)
		drop if drop != 108
		drop drop 
		sort GEOID year
		egen adm2_id = group(GEOID)

		* (2) rescale
		replace pop 			= pop / 1000000
		replace pop_int_10y		= pop_int_10y / 1000000
		replace pop_ext 		= pop_ext / 1000000
		replace pop_replicated	= pop_replicated / 1000000
		replace pop_new			= pop_new / 1000000
		
		* (3) draw pop trends for these 628 adm2s: all adm2s
		local command "graph twoway "
		
		sum adm2_id, meanonly
		forvalues i = 1(1)`r(max)' {
			local add " (connected pop year if age == 99 & adm2_id == `i' , sort lwidth(vthin) lcolor(gold) mcolor(gold) ms(T) msize(small)) "
			local command " `command' `add' "
		}
		*
		local add " , legend(off) graphregion(color(gs16)) "
		local command " `command' `add' "
		disp("`command'")
		`command'
		graph export "`MEX_raw'/Population/PopGrowthTrend_adm2_all.png", as(png) replace
		

		* (4) draw pop trends for these 628 adm2s: exclude 3 huge adm2s.
		* (4.1)
		local command "graph twoway "
		
		sum adm2_id, meanonly
		forvalues i = 1(1)`r(max)' {
			sum pop if adm2_id == `i', meanonly
			if `r(max)' < 2 {
			local add " (connected pop year if age == 99 & adm2_id == `i' , sort lwidth(vthin) lcolor(gold) mcolor(gold) ms(T) msize(small)) "
			local command " `command' `add' "
			}
		}
		*
		local add " , legend(off) graphregion(color(gs16)) "
		local command " `command' `add' "
		disp("`command'")
		`command'
		graph export "`MEX_raw'/Population/PopGrowthTrend_adm2.png", as(png) replace
		
		* (4.2) 
		local command "graph twoway "
		
		sum adm2_id, meanonly
		forvalues i = 1(1)`r(max)' {
			sum pop if adm2_id == `i', meanonly
			if `r(max)' < 0.5 {
			local add " (connected pop year if age == 99 & adm2_id == `i' , sort lwidth(vthin) lcolor(gold) mcolor(gold) ms(T) msize(small)) "
			local command " `command' `add' "
			}
		}
		*
		local add " , legend(off) graphregion(color(gs16)) "
		local command " `command' `add' "
		disp("`command'")
		`command'
		graph export "`MEX_raw'/Population/PopGrowthTrend_adm2_small.png", as(png) replace
		
		* (4.3)
		graph twoway (scatter pop pop_int_10y if pop < 1 & age == 99, mcolor(orange) ms(Oh) msize(small)) ///
					(line pop_int_10y pop_int_10y if pop < 1 & age == 99 , sort lwidth(medthin) lcolor(gs6) lp(dash) ) ///
					, legend(off) ///
					xlabel(, labs(small) grid glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ylabel( , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtitle("interpolated 1995 population [10 year interval]" , size(medsmall)) ///
					ytitle("1995 population 1991 [from IPUMS]" , size(medsmall)) ///
					graphregion(color(gs16)) 
		graph export "`MEX_raw'/Population/Pop_adm2_compareinterpolation.png", as(png) replace
	restore

	* 8.2 to prove that the Adm2 level population might be wrong in magnitude in 1995
	preserve
		
		keep if year == 1990 | year == 1995 | year == 2000 | year == 2005 | year == 2010 | year == 2015
		keep if age == 99

		keep pop year
		collapse (sum) pop, by(year)
		
		gen pop_WB = .
		replace pop_WB = 85357 if year == 1990
		replace pop_WB = 94045 if year == 1995
		replace pop_WB = 101719 if year == 2000
		replace pop_WB = 108472  if year == 2005
		replace pop_WB = 117318 if year == 2010
		replace pop_WB = 125890 if year == 2015
		replace pop_WB = pop_WB * 1000
		
		replace pop = pop/1000000
		replace pop_WB = pop_WB/1000000
		label var pop "IPUMS"
		label var pop_WB "World Bank"
		
		graph twoway (connected pop year, mcolor(orange) ms(T) msize(small) lw(thin) lc(orange)) ///
						(connected pop_WB year, mcolor(maroon) ms(T) msize(small) lw(thin) lc(range) yaxis(2)) ///
					,  ///
					legend( size(small) margin(vvsmall)) ///
					xlabel(, labs(small) grid glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ylabel(80(10)130 , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytick( 80(10)130 , grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtitle("Year" , size(medsmall)) ///
					ytitle("IPUMS Population (million)" , size(small) margin(medium)) ///
					ytitle("WB Population (million)" , size(small) margin(medium) axis(2)) ///
					ylabel(80(10)130 , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12) axis(2)) ///
					ytick( 80(10)130 , grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12) axis(2)) ///
					note("[1]. IPUMS 1995 value is added up from only 628 out of 2331 adm2s." ,size(small)) ///
					caption("[2]. both increase around 50%." ,size(small)) ///
					graphregion(color(gs16)) 
		graph export "`MEX_raw'/Population/Pop_adm0_compareIPUMSandWB.png", as(png) replace

	restore

	* 8.3 to prove that the interpolated and extrapolated 2011-2014 pop are similar
	preserve

		keep if year > 2010 
		keep if age == 99
		keep adm2_label GEOID year pop_ext pop
		replace pop = pop/1000000
		replace pop_ext = pop_ext/1000000
		
		local MEX_raw "$cntry_dir/MEX"
		
		graph twoway (scatter pop_ext pop if year != 2015, mcolor(orange) ms(Oh) msize(small)) ///
					(line pop pop if year != 2015 , sort lwidth(medthin) lcolor(gs6) lp(dash) ) ///
					, legend(off) ///
					xlabel(, labs(small) grid glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ylabel( , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytitle("extrapolated 2011-2014 pop [use 2005 and 2010 data]" , size(medsmall)) ///
					xtitle("interpolated 2011-2014 pop [use 2010 and 2015 data]" , size(medsmall)) ///
					graphregion(color(gs16)) 
		graph export "`MEX_raw'/Population/Pop_adm2_compare2011-2014.png", as(png) replace
		
		graph twoway (scatter pop_ext pop if pop < 1 & year != 2015, mcolor(orange) ms(Oh) msize(small)) ///
					(line pop pop if pop < 1 & year != 2015 , sort lwidth(medthin) lcolor(gs6) lp(dash) ) ///
					, legend(off) ///
					xlabel(, labs(small) grid glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ylabel( , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytitle("extrapolated 2011-2014 pop [use 2005 and 2010 data]" , size(medsmall)) ///
					xtitle("interpolated 2011-2014 pop [use 2010 and 2015 data]" , size(medsmall)) ///
					graphregion(color(gs16)) 
		graph export "`MEX_raw'/Population/Pop_adm2_compare2011-2014_2.png", as(png) replace
		
		
		graph twoway (scatter pop_ext pop if  year == 2015, mcolor(orange) ms(Oh) msize(small)) ///
					(line pop pop if  year == 2015 , sort lwidth(medthin) lcolor(gs6) lp(dash) ) ///
					, legend(off) ///
					xlabel(, labs(small) grid glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ylabel( , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtitle("IPUMS 2015 population" , size(medsmall)) ///
					ytitle("extrapolated 2015 population [use 2005 and 2010 data]" , size(medsmall)) ///
					graphregion(color(gs16)) 
		graph export "`MEX_raw'/Population/Pop_adm2_compare2015.png", as(png) replace
		
		graph twoway (scatter pop_ext pop if pop < 1 & year == 2015, mcolor(orange) ms(Oh) msize(small)) ///
					(line pop pop if pop < 1 & year == 2015 , sort lwidth(medthin) lcolor(gs6) lp(dash) ) ///
					, legend(off) ///
					xlabel(, labs(small) grid glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ylabel( , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtitle("IPUMS 2015 population" , size(medsmall)) ///
					ytitle("extrapolated 2015 population [use 2005 and 2010 data]" , size(medsmall)) ///
					graphregion(color(gs16)) 
		graph export "`MEX_raw'/Population/Pop_adm2_compare2015_2.png", as(png) replace
	restore

	* 9. save
	save "`MEX_raw'/Population/Pop_ADM2_Mexico.dta", replace


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
	gen adm1_id = .
	gen adm2_id = .
	save `death_eachyear', replace 

	* for each year, store values in the initialized file:
	forvalues year = 1990(1)2013 {

		* 1.1. import mortality data
		import delimited using "`MEX_raw'/Mortality/Raw/`year'_DEFUN.csv", clear

		* 1.2. keep useful variables
		keep ent_resid mun_resid edad_agru
		gen num_of_obs = 1
		rename ent_resid adm1_id
		rename mun_resid adm2_id
		rename edad_agru age

		* 1.3. collapse to adm2 level
		collapse (sum) num_of_obs, by(adm1_id adm2_id age)
		gen year = `year'
		
		* 1.4. save and append
		append using `death_eachyear'
		save `death_eachyear', replace
	}
	*


	* 2. fill the panel
	* 2.1 reshape to wide
	reshape wide num_of_obs, i(adm1_id adm2_id year) j(age)

	* 2.2 add the adm2-years that do not have any death
	* (1) get a continuous adm2 id
	egen adm2_id_cont = group(adm1_id adm2_id)

	* (2) add the first year and the last year for all adm2s
	sum adm2_id_cont, meanonly
	forvalues i = 1(1)`r(max)' {
		* add the first year
		quietly sum if adm2_id_cont == `i' & year == 1990
		if `r(N)' == 0 {
			* display the current adm2
			disp("Current Adm2: `i'")
			quietly sum adm1_id if adm2_id_cont == `i'
			local adm1_id = `r(mean)'
			quietly sum adm2_id if adm2_id_cont == `i'
			local adm2_id = `r(mean)'
			disp("Adm1 `adm1_id', Adm2 `adm2_id'")
			disp("add in year 1990")
			* add obs
			local new = _N + 1
			quietly set obs `new'
			quietly replace adm2_id_cont = `i' if adm2_id_cont == .
			quietly replace adm1_id = `adm1_id' if adm1_id == .
			quietly replace adm2_id = `adm2_id' if adm2_id == .
			quietly replace year = 1990 if year == .
		}
		*
		
		* add the last year
		quietly sum if adm2_id_cont == `i' & year == 2013
		if `r(N)' == 0 {
			* display the current adm2
			disp("Current Adm2: `i'")
			quietly sum adm1_id if adm2_id_cont == `i'
			local adm1_id = `r(mean)'
			quietly sum adm2_id if adm2_id_cont == `i'
			local adm2_id = `r(mean)'
			disp("Adm1 `adm1_id', Adm2 `adm2_id'")
			disp("add in year 1990")
			* add obs
			local new = _N + 1
			quietly set obs `new'
			quietly replace adm2_id_cont = `i' if adm2_id_cont == .
			quietly replace adm1_id = `adm1_id' if adm1_id == .
			quietly replace adm2_id = `adm2_id' if adm2_id == .
			quietly replace year = 2013 if year == .
		}
	}
	*

	* (3) fill the panel
	tsset adm2_id_cont year
	tsfill 


	* 2.3 add the missing ids
	sum adm2_id_cont, meanonly
	forvalues i = 1(1)`r(max)' {
		quietly sum adm1_id if adm2_id_cont == `i'
		local adm1_id = `r(mean)'
		quietly sum adm2_id if adm2_id_cont == `i'
		local adm2_id = `r(mean)'
		disp("Current Adm2: `i'. Adm1 `adm1_id', Adm2 `adm2_id'")
		replace adm1_id = `adm1_id' if adm2_id_cont == `i'
		replace adm2_id = `adm2_id' if adm2_id_cont == `i'
	}
	*

	* 2.4 change missing values to 0
	forvalues i = 1(1)30 {
		replace num_of_obs`i' = 0 if num_of_obs`i' == .
	}
	*
	drop adm2_id_cont


	* 3. reshape to long, generate variable age, and label it
	* 3.1 generate tot number of death
	gen num_of_obs99 = num_of_obs1
	forvalues i = 2(1)30{
		replace num_of_obs99 = num_of_obs99 + num_of_obs`i'
	}
	*

	* 3.2 reshape
	reshape long num_of_obs , i(year adm2_id adm1_id) j(age)
	rename num_of_obs num_of_death

	sort adm1_id adm2_id year

	* 3.3 label
		label define age_lbl 001 `"0"', replace
		label define age_lbl 002 `"1"', add
		label define age_lbl 003 `"2"', add
		label define age_lbl 004 `"3"', add
		label define age_lbl 005 `"4"', add
		label define age_lbl 006 `"5-9"', add
		label define age_lbl 007 `"10-14"', add
		label define age_lbl 008 `"15-19"', add
		label define age_lbl 009 `"20-24"', add
		label define age_lbl 010 `"25-29"', add
		label define age_lbl 011 `"30-34"', add
		label define age_lbl 012 `"35-39"', add
		label define age_lbl 013 `"40-44"', add
		label define age_lbl 014 `"45-49"', add
		label define age_lbl 015 `"50-54"', add
		label define age_lbl 016 `"55-59"', add
		label define age_lbl 017 `"60-64"', add
		label define age_lbl 018 `"65-69"', add
		label define age_lbl 019 `"70-74"', add
		label define age_lbl 020 `"75-79"', add
		label define age_lbl 021 `"80-84"', add
		label define age_lbl 022 `"85-89"', add
		label define age_lbl 023 `"90-94"', add
		label define age_lbl 024 `"95-99"', add
		label define age_lbl 025 `"100-104"', add
		label define age_lbl 026 `"105-109"', add
		label define age_lbl 027 `"110-114"', add
		label define age_lbl 028 `"115-119"', add
		label define age_lbl 029 `"120+"', add
		label define age_lbl 030 `"Unspecified"', add
		label define age_lbl 099 `"total"', add
		label values age age_lbl

	* 4. save
	save "`MEX_raw'/Mortality/Death_ADM2_Mexico.dta", replace

}
