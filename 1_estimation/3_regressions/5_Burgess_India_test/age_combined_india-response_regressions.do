/*=======================================================================

Purpose: running alternative specifications of our mortality-temperature regression model 
for the Indian data : a polynomial interaction model with both income and climate heterogeneity,
a polynomial interaction model with income heterogeneity only, 
and a polynomial interaction model with climate heterogeneity only.

NOTE: The binned regressions are not used in the paper, but are left in the script as additional disgnostics should users try to replicate

Here, we use data from Burgess et al. (2017) and replicate a version of their main specification that is directly comparable
to the main estimating equation in Carleton et al. (2022). 
To ensure comparability, our implementation of Burgess et al. differs from theirs in several aspects:

1. they have shorter temperature bins, and their starting bin is much more in the warmer side than ours before
2. they control for dummies indicating whether an obs falls in either of the precipitation tercile in-sample
3. they control for ‘climatic-region’ (four such regions in india) linear and quadratic year trends.
4. they use log of deathrates, we use windsorized deathrates.
5. data used is geographically not the same (they now use the combined boundaries, and we still use the 1961 boundaries), and, perhaps for this reason, their final number of obs is 20% smaller.

We attempted to estimate a regression model that is as close as possible to that one. We could solve differences 1-4 only. 

The model we estimated solves differences 1-3. The difference 4 couldn't be solved because it changes the way we interpret our own model, and the difference 5 couldn't be solved 
because we don't have their data. 

Solving for 1-3 and running both a binned regression (like in their paper) and a polynomial regression (like in our paper) lead to the following results : 
* the binned model from Burgess et al. response looks a lot like the one in their paper.
* the polynomial model from Burgess et al. response is qualitatively similar to our age-share averaged main model evaluated at India’s covariates values.

The reason of this improvements was mostly the climatic region time trends, while the precipitation controls didn't matter that much. 

Note that to solve difference 3, we had to find the climatic region data. We received part of the author's data that contains this information. Since these climatic regions are very large, we pulled that information 
from their data and merged it in our data (1961 boundaries) using the states as a key.

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

local ster "$ster_dir/diagnostic_specs"


*****************************************************************************
* 						PART 1. User parameters 	 				     	*
*****************************************************************************



local poly_4 0 // run the polynomial specification?
local bin_32C 0 // run binned regression : last bin starts at 32C ?
local bin_35C 0 // run binned regression : last bin starts at 35C ?
local bin_33_34_35C 0 // run binned regression : last bin starts at 35C AND the two previous bins are only 1C wide ?
local burgess_style 1 // run burgess style regressions? 

*****************************************************************************
* 						PART 2. Preparing data and running regression 

* Note : preparing data is usually done in prep_data.do but that one drops IND, 
* so we're redoing it here, keeping only IND.
*****************************************************************************

use "$DB/0_data_cleaning/3_final/global_mortality_panel", clear

preserve 

if (!`burgess_style'){

	drop if year > 2010

	* create winsorized deathrate with-in country-agegroup
	bysort iso agegroup: egen deathrate_p99 = pctile(deathrate), p(99)
	gen deathrate_w99 = deathrate
	replace deathrate_w99 = deathrate_p99 if deathrate > deathrate_p99 & !mi(deathrate)
	drop deathrate_p99

	* set up sample 
	gen sample = 0
	replace sample = 1 if iso=="IND"
	replace sample = 0 if mi(deathrate_w99)
	replace sample = 0 if mi(tavg_poly_1_GMFD)
	replace sample = 0 if mi(prcp_poly_1_GMFD)
	replace sample = 0 if mi(loggdppc_adm1_avg)
	replace sample = 0 if mi(lr_tavg_GMFD_adm1_avg)

	keep if sample == 1

	* clean up ids
	egen adm0_code 			= group(iso)
	egen adm1_code 			= group(iso adm1_id)
	replace adm2_id 		= adm1_id if iso == "JPN"
	egen adm2_code 			= group(iso adm1_id adm2_id)

	egen adm0_agegrp_code 	= group(iso agegroup)
	egen adm1_agegrp_code	= group(iso adm1_id agegroup)


	* set weighting schemes
	bysort year: egen tot_pop = total(population)
	gen weight = population / tot_pop

	* gen bin vars
	//generate bin vars
	foreach temp in "GMFD" {
		order tavg_bins_*_`temp'
		egen tavg_bins_nInfC_n13C_`temp' = rowtotal(tavg_bins_nInf_n40C_`temp'-tavg_bins_n14C_n13C_`temp')
		egen tavg_bins_n13C_n8C_`temp' = rowtotal(tavg_bins_n13C_n12C_`temp'-tavg_bins_n9C_n8C_`temp')
		egen tavg_bins_n8C_n3C_`temp' = rowtotal(tavg_bins_n8C_n7C_`temp'-tavg_bins_n4C_n3C_`temp')
		egen tavg_bins_n3C_2C_`temp' = rowtotal(tavg_bins_n3C_n2C_`temp'-tavg_bins_1C_2C_`temp')
		egen tavg_bins_2C_7C_`temp' = rowtotal(tavg_bins_2C_3C_`temp'-tavg_bins_6C_7C_`temp')
		egen tavg_bins_7C_12C_`temp' = rowtotal(tavg_bins_7C_8C_`temp'-tavg_bins_11C_12C_`temp')
		egen tavg_bins_12C_17C_`temp' = rowtotal(tavg_bins_12C_13C_`temp'-tavg_bins_16C_17C_`temp')
		egen tavg_bins_17C_22C_`temp' = rowtotal(tavg_bins_17C_18C_`temp'-tavg_bins_21C_22C_`temp')
		egen tavg_bins_22C_27C_`temp' = rowtotal(tavg_bins_22C_23C_`temp'-tavg_bins_26C_27C_`temp')
		egen tavg_bins_27C_32C_`temp' = rowtotal(tavg_bins_27C_28C_`temp'-tavg_bins_31C_32C_`temp')
		egen tavg_bins_32C_35C_`temp' = rowtotal(tavg_bins_32C_33C_`temp'-tavg_bins_34C_35C_`temp')
		gen tavg_bins_35C_InfC_`temp' = tavg_bins_35C_Inf_`temp'
		egen tavg_bins_32C_InfC_`temp' = rowtotal(tavg_bins_32C_33C_`temp'-tavg_bins_35C_Inf_`temp')
	}


	* running regression

	if (`poly_4'){
		**poly 4
		reghdfe deathrate_w99 c.tavg_poly_1_GMFD c.tavg_poly_2_GMFD c.tavg_poly_3_GMFD c.tavg_poly_4_GMFD ///
				[aw = weight]  ///
				, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
						i.adm2_code i.year ) ///
				cluster(adm1_code)
		estimates save "`ster'/IND_no_interaction", replace
	}

	if (`bin_32C'){
		bin 32C
		reghdfe deathrate_w99 tavg_bins_nInfC_n13C_GMFD tavg_bins_n13C_n8C_GMFD tavg_bins_n8C_n3C_GMFD ///
			tavg_bins_n3C_2C_GMFD tavg_bins_2C_7C_GMFD tavg_bins_7C_12C_GMFD tavg_bins_12C_17C_GMFD ///
			tavg_bins_22C_27C_GMFD tavg_bins_27C_32C_GMFD tavg_bins_32C_InfC_GMFD ///
			[aw = weight]  ///
			, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
						i.adm2_code i.year ) ///
			cluster(adm1_code)
		estimates save "`ster'/IND_no_interaction_bin_32C", replace
	}

	if (`bin_35C'){
		**bin 35C
		reghdfe deathrate_w99 tavg_bins_nInfC_n13C_GMFD tavg_bins_n13C_n8C_GMFD tavg_bins_n8C_n3C_GMFD ///
			tavg_bins_n3C_2C_GMFD tavg_bins_2C_7C_GMFD tavg_bins_7C_12C_GMFD tavg_bins_12C_17C_GMFD ///
			tavg_bins_22C_27C_GMFD tavg_bins_27C_32C_GMFD tavg_bins_32C_35C_GMFD tavg_bins_35C_InfC_GMFD ///
			[aw = weight]  ///
			, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
						i.adm2_code i.year ) ///
			cluster(adm1_code)
		estimates save "`ster'/IND_no_interaction_bin_35C", replace
	}


	if (`bin_33_34_35C'){
		**bin 33-34-35C
		reghdfe deathrate_w99 tavg_bins_nInfC_n13C_GMFD tavg_bins_n13C_n8C_GMFD tavg_bins_n8C_n3C_GMFD ///
			tavg_bins_n3C_2C_GMFD tavg_bins_2C_7C_GMFD tavg_bins_7C_12C_GMFD tavg_bins_12C_17C_GMFD ///
			tavg_bins_22C_27C_GMFD tavg_bins_27C_32C_GMFD tavg_bins_32C_33C_GMFD tavg_bins_33C_34C_GMFD tavg_bins_34C_35C_GMFD tavg_bins_35C_Inf_GMFD ///
			[aw = weight]  ///
			, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
						i.adm2_code i.year ) ///
			cluster(adm1_code)
		estimates save "`ster'/IND_no_interaction_bin_33_34_35C", replace
	}

}


if (`burgess_style'){


	*changes : 

	*bins
	*weights is total population
	*time trends 
	*not yet(log of deathrates)
	*precip specification 
	*not yet(dataset)


	restore

	preserve 

	* re-preparing the data to match...

	drop if year > 2010


	* 1. dependent variable = log of deathrate. no windsorizing. 
	*gen log_deathrate = log(deathrate)

	* create winsorized deathrate with-in country-agegroup
	bysort iso agegroup: egen deathrate_p99 = pctile(deathrate), p(99)
	gen deathrate_w99 = deathrate
	replace deathrate_w99 = deathrate_p99 if deathrate > deathrate_p99 & !mi(deathrate)
	drop deathrate_p99

	* 2. set up sample 
	gen sample = 0
	replace sample = 1 if iso=="IND"
	replace sample = 0 if mi(deathrate_w99)
	replace sample = 0 if mi(tavg_poly_1_GMFD)
	replace sample = 0 if mi(prcp_poly_1_GMFD)
	replace sample = 0 if mi(loggdppc_adm1_avg)
	replace sample = 0 if mi(lr_tavg_GMFD_adm1_avg)

	keep if sample == 1

	* 3. clean up ids
	egen adm0_code 			= group(iso)
	egen adm1_code 			= group(iso adm1_id)
	replace adm2_id 		= adm1_id if iso == "JPN"
	egen adm2_code 			= group(iso adm1_id adm2_id)

	egen adm0_agegrp_code 	= group(iso agegroup)
	egen adm1_agegrp_code	= group(iso adm1_id agegroup)

	* 3. weights = absolute population this time 
	gen weight = population


	* 4. temperature part of the equation
	* binned temperature. here bins have a shorter total range and are shorter, to match Burgess.
	*generate bin vars
	foreach temp in "GMFD" {
		order tavg_bins_*_`temp'
		*]-inf,18[
		egen tavg_bins_nInfC_18C_`temp' = rowtotal(tavg_bins_nInf_n40C_`temp'-tavg_bins_17C_18C_`temp')
		*[18,21[
		egen tavg_bins_18C_21C_`temp' = rowtotal(tavg_bins_18C_19C_`temp'-tavg_bins_20C_21C_`temp')
		*[21,24[
		egen tavg_bins_21C_24C_`temp' = rowtotal(tavg_bins_21C_22C_`temp'-tavg_bins_23C_24C_`temp')
		*[24,27[
		egen tavg_bins_24C_27C_`temp' = rowtotal(tavg_bins_24C_25C_`temp'-tavg_bins_26C_27C_`temp')
		*[27,30[
		egen tavg_bins_27C_30C_`temp' = rowtotal(tavg_bins_27C_28C_`temp'-tavg_bins_29C_30C_`temp')
		*[30,33[
		egen tavg_bins_30C_33C_`temp' = rowtotal(tavg_bins_30C_31C_`temp'-tavg_bins_32C_33C_`temp')
		*[33,35[
		egen tavg_bins_33C_35C_`temp' = rowtotal(tavg_bins_33C_34C_`temp'-tavg_bins_34C_35C_`temp')
		*[35,Inf[
		egen tavg_bins_35C_InfC_`temp' = rowtotal(tavg_bins_35C_Inf_`temp')
	}

	*store names in local, omitting the 18-21 bin for the regression
	local temperature
	foreach thisbin in nInfC_18C 21C_24C 24C_27C 27C_30C 30C_33C 33C_35C 35C_InfC{
		local temperature `temperature' tavg_bins_`thisbin'_GMFD
	}

	* 5 region specific time trends (for later)

	* states in our data and missing in the source data : 
	* andaman and nicobar islands : gets andhra pradesh
	* manipur : gets assam
	* naga hills tuensang area : gets assam
	* note that there are a few states that are missing from the master data, but that is fine.
	gen state=adm1
	merge m:m state using "$cntry_dir/IND/Mortality/climate_regions_combined.dta"
	replace region=3 if state=="andaman and nicobar islands"
	replace region=1 if state=="manipur" | state=="naga hills-tuensang area"
	drop _merge
	local time_trends
	gen t_poly_1 = year-1957
	gen t_poly_2 = t_poly_1*t_poly_1
	local time_trends i.region##c.t_poly_1 i.region##c.t_poly_2

	* 6 precip specification 
	*generate terciles like in burgess
 	xtile prcp_poly_1_GMFD_tercile = prcp_poly_1_GMFD, n(3)
 	forval t=1/3{
	 	gen prcp_poly_1_GMFD_tercile_`t' = cond(prcp_poly_1_GMFD_tercile==`t', 1, 0)
 	}
 	*store variable names in local
 	local precipitation prcp_poly_1_GMFD_tercile_1 prcp_poly_1_GMFD_tercile_2 prcp_poly_1_GMFD_tercile_3
	local myequation "deathrate_w99 `temperature' `precipitation' `time_trends'"
	reghdfe `myequation' [aw = weight], absorb(i.adm2_code i.year) cluster(adm1_code)

	estimates save "`ster'/IND_burgess_style_1961", replace

	local temperature tavg_poly_1_GMFD tavg_poly_2_GMFD tavg_poly_3_GMFD tavg_poly_4_GMFD
	local myequation "deathrate_w99 `temperature' `precipitation' `time_trends'"

	**poly 4
	reghdfe `myequation' [aw = weight], absorb(i.adm2_code i.year) cluster(adm1_code)

	estimates save "`ster'/IND_burgess_style_1961_poly_4", replace

}
