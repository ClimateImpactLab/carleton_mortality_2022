/*

Creator: Jingyuan Wang, jingyuanwang@uchicago.edu

Date last modified: 7/6/19
Last modified by: Dylan Hogan, dylanhogan@gmail.com

Purpose: Generates Table I in Carleton et al, 2022 - summary statistics table,
historical mortality & climate data.

Updates as of last modified:
- population weight average covariate values (income, long-run temperature, 
  days above 28C) based upon 2010 population for all countries except 
  India, which uses 1995 values due to its panel length. 

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.

Outputs
-------

- Outputs latex to console.

*/

*****************************************************************************
* 							PART 0. Initializing		 					*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

*****************************************************************************
* 						PART 1. Generate variables for stats			    *
*****************************************************************************

use "$DB/0_data_cleaning/3_final/global_mortality_panel"

quietly {

	* 0. generate deathrate
	keep if year <= 2010
	* create winsorized deathrate with-in country-agegroup
	bysort iso agegroup: egen deathrate_p99 = pctile(deathrate), p(99)
	gen deathrate_w99 = deathrate
	replace deathrate_w99 = deathrate_p99 if deathrate > deathrate_p99 & !mi(deathrate)
	drop deathrate_p99

	* 0. keep the sample
	gen sample = 0
	replace sample = 1 if year < = 2010
	replace sample = 0 if mi(deathrate_w99)
	replace sample = 0 if mi(tavg_poly_1_GMFD)
	replace sample = 0 if mi(prcp_poly_1_GMFD)
	replace sample = 0 if mi(loggdppc_adm1_avg)
	replace sample = 0 if mi(lr_tavg_GMFD_adm1_avg)

	keep if sample == 1

	* 1. generate global population share 
	* generate global pop share in 2010
	gen pop_global_2010 = 6.933 * 1000000000

	* generate population for each country
	gen pop_adm0_2010 = .
	replace pop_adm0_2010 =  196796 if iso == "BRA"
	replace pop_adm0_2010 =   16993 if iso == "CHL"
	replace pop_adm0_2010 = 1337705 if iso == "CHN"
	replace pop_adm0_2010 =   65028 if iso == "FRA"
	replace pop_adm0_2010 = 1230981 if iso == "IND"
	replace pop_adm0_2010 =  128070 if iso == "JPN"
	replace pop_adm0_2010 =  117319 if iso == "MEX"
	replace pop_adm0_2010 =  309348 if iso == "USA"
	replace pop_adm0_2010 =  439393 if iso != "BRA" & iso != "CHL" & iso != "CHN" & iso != "FRA" ///
									 & iso != "IND" & iso != "JPN" & iso != "MEX" & iso != "USA"
	* 439393 = EU pop 504421 - FRA pop
	replace pop_adm0_2010 = pop_adm0_2010 * 1000

	* generate pop share for each country
	gen popshare_global = pop_adm0_2010 /  pop_global_2010
	order popshare_global pop_adm0_2010 pop_global_2010, a(population)


	* 2. generate number of days > 28 degree C [GMFD]
	gen NumOfDays_above28 = 0
	forvalues i = 28(1)34 {
		local j = `i' + 1
		replace NumOfDays_above28 = NumOfDays_above28 + tavg_bins_`i'C_`j'C_GMFD
	}
	replace NumOfDays_above28 = NumOfDays_above28 + tavg_bins_35C_Inf_GMFD
	* 

	gen ww = population if year == 2010 & iso != "IND"
	replace ww = population if year == 1995 & iso == "IND"
	bysort iso adm1_id adm2_id agegroup: egen weight = max(ww)				

}

*****************************************************************************
* 				PART 2. Summarize variables and print to console		    *
*****************************************************************************

* statistics on the countries one by one
foreach iso in "BRA" "CHL" "CHN" "EU" "FRA" "JPN" "MEX" "USA" "IND" "Global" {

quietly {
	* 1. keep the country
	gen keepthiscountry = 0
	if "`iso'" == "EU" {
		replace keepthiscountry	= 1 ///
				 if iso != "BRA" & iso != "CHL" & iso != "CHN" & iso != "FRA" ///
				  & iso != "IND" & iso != "JPN" & iso != "MEX" & iso != "USA"
	}
	if "`iso'" == "Global" {
		replace keepthiscountry = 1
	}
	else {
		replace keepthiscountry	= 1 ///
			     if iso == "`iso'"
	}
	*
	
	preserve
		keep if keepthiscountry == 1
		
	* 2. summarize the variables and store in macro
	if "`iso'" != "IND" & "`iso'" != "Global" {
		sum year if agegroup != 0
		local N 					= `r(N)'
		* year
		local year_start 			= `r(min)'
		local year_end	 			= `r(max)'
	}
	else if "`iso'" == "Global" {
		sum year if agegroup != 0
		local N_1 					= `r(N)'
		sum year if agegroup == 0 & iso == "IND"
		local N_2 					= `r(N)'
		local N = `N_1' + `N_2'
		local year_start  " "
		local year_end 	  " "
	}
	else {
		sum year if agegroup == 0
		local N 					= `r(N)'
		* year
		local year_start 			= `r(min)'
		local year_end	 			= `r(max)'
	}

	* resolution
	quietly tab adm2_id
	if `r(N)' == 0 {
		local spatial_resolution "ADM1"
	}
	if `r(N)' != 0 {
		local spatial_resolution "ADM2"
	}
	if "`iso'" == "EU" {
		local spatial_resolution "NUTS2"
	}
	if "`iso'" == "Global" {
		local spatial_resolution " "
	}
	* age group
	quietly tab agegroup
	if `r(r)' == 4 {
		local AgeCat "0-4, 5-64, 65+"
	}
	if `r(r)' == 3 {
		local AgeCat "0-65, 65+"
	}
	if "`iso'" == "IND" {
		local AgeCat "ALL"
	}
	if "`iso'" == "FRA" {
		local AgeCat "0-19, 20-64, 65+"
	}
	if "`iso'" == "Global" {
		local AgeCat " "
	}
	* statistics
	sum deathrate_w99 if agegroup == 0
	local deathrate_allage 	= round(`r(mean)', 1)

	if "`iso'" != "IND" {
		sum deathrate_w99  if agegroup == 3
		local deathrate_65plus 	= round(`r(mean)', 1)
	}
	else {
		local deathrate_65plus 	= .
	}
	
	sum popshare_global
	local popshare 	= round(`r(mean)', .001)

	sum gdppc_adm1_avg [aw = weight] if agegroup == 0
	local income = round(`r(mean)', 1)
	sum lr_tavg_GMFD_adm1_avg [aw = weight] if agegroup == 0
	local tmean = round(`r(mean)', .1)
	sum NumOfDays_above28 [aw = weight] if agegroup == 0
	local daysabove28 = round(`r(mean)', .1)

	if "`iso'" == "Global" {
		keep popshare_global iso
		replace iso = "EU" if iso != "BRA" & iso != "CHL" & iso != "CHN" & iso != "FRA" ///
				  & iso != "IND" & iso != "JPN" & iso != "MEX" & iso != "USA"
		duplicates drop
		drop iso
		collapse (sum) popshare_global
		local popshare = popshare_global
		local popshare = round(`popshare', .001)
	}
	*
	restore
	drop keepthiscountry
}

	* 3. display to tables
	if "`iso'" == "BRA" {
		disp("")
		disp("=======================================================================================")
		disp("Country & N & Years & All-age & Over 65 & pop.share & GDP p.c. & Tmean & Num of Days>28C \\")
		disp("---------------------------------------------------------------------------------------")
	}
	disp("`iso' & `N' & `spatial_resolution' & `year_start'-`year_end' & `AgeCat' & `deathrate_allage' & `deathrate_65plus' & `popshare' & `income' & `tmean' & `daysabove28' \\ ")

}
*
