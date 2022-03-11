/*

Purpose: Generate alternative age specific regression sters displayed
in Fig D4. The alternative functional forms being estimated are:

1) Fourth order polynomial (main)
2) Binned - annual values are calculated as the number of days that have an 
   average temperature that falls within a fixed set of 5 degree bins
3) Restricted cubic spline specification
4) Linear spline specification

Each of these are estimated both using GMFD temperatures (main) as well as 
Berkeley Earth Surface Temperature (BEST), and monthly precipitation from 
University of Delaware 

*/


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

do "0_data_cleaning/1_utils/set_paths.do"

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

*****************************************************************************
* 						PART 1. OLS Regressions                 		    *
*****************************************************************************

* 1. set weighting schemes
bysort year: egen tot_pop = total(population)
gen weight = population / tot_pop

* 2. set BEST precip 
gen prcp_poly_1_BEST = prcp_poly_1_UDEL
gen prcp_poly_2_BEST = prcp_poly_2_UDEL

* 3. gen bin vars
//generate bin vars
foreach temp in "BEST" "GMFD" {
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
	egen tavg_bins_32C_InfC_`temp' = rowtotal(tavg_bins_32C_33C_`temp'-tavg_bins_35C_Inf_`temp')
}

* 3. run regressions
foreach temp in "GMFD" "BEST" {

	//Poly 4
	reghdfe deathrate_w99 c.tavg_poly_1_`temp'#i.agegroup c.tavg_poly_2_`temp'#i.agegroup c.tavg_poly_3_`temp'#i.agegroup c.tavg_poly_4_`temp'#i.agegroup ///
		[aw = weight]  ///
		, absorb(adm0_code##c.prcp_poly_1_`temp' adm0_code##c.prcp_poly_2_`temp' ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
	estimates save "`ster'/pooled_age_spec_no_interaction_poly4_`temp'", replace

	//Cubic Spline
	reghdfe deathrate_w99 c.tavg_rcspline_term0_`temp'#i.agegroup c.tavg_rcspline_term1_`temp'#i.agegroup c.tavg_rcspline_term2_`temp'#i.agegroup ///
		c.tavg_rcspline_term3_`temp'#i.agegroup c.tavg_rcspline_term4_`temp'#i.agegroup c.tavg_rcspline_term5_`temp'#i.agegroup c.tavg_rcspline_term6_`temp'#i.agegroup ///
		[aw = weight]  ///
		, absorb(adm0_code##c.prcp_poly_1_`temp' adm0_code##c.prcp_poly_2_`temp' ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
	estimates save "`ster'/pooled_age_spec_no_interaction_cspline_`temp'", replace

	//Linear Spline
	reghdfe deathrate_w99 c.tavg_cdd_25C_`temp'#i.agegroup c.tavg_hdd_0C_`temp'#i.agegroup ///
		[aw = weight]  ///
		, absorb(adm0_code##c.prcp_poly_1_`temp' adm0_code##c.prcp_poly_2_`temp' ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
	estimates save "`ster'/pooled_age_spec_no_interaction_lspline_`temp'", replace

	//Bins
	reghdfe deathrate_w99 c.tavg_bins_nInfC_n13C_`temp'#i.agegroup c.tavg_bins_n13C_n8C_`temp'#i.agegroup c.tavg_bins_n8C_n3C_`temp'#i.agegroup ///
		c.tavg_bins_n3C_2C_`temp'#i.agegroup c.tavg_bins_2C_7C_`temp'#i.agegroup c.tavg_bins_7C_12C_`temp'#i.agegroup c.tavg_bins_12C_17C_`temp'#i.agegroup ///
		c.tavg_bins_22C_27C_`temp'#i.agegroup c.tavg_bins_27C_32C_`temp'#i.agegroup c.tavg_bins_32C_InfC_`temp'#i.agegroup ///
		[aw = weight]  ///
		, absorb(adm0_code##c.prcp_poly_1_`temp' adm0_code##c.prcp_poly_2_`temp' ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
	estimates save "`ster'/pooled_age_spec_no_interaction_bins_`temp'", replace
}
