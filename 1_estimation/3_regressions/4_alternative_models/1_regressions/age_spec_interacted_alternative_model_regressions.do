/*=======================================================================
Creator: Jingyuan Wang, jingyuanwang@uchicago.edu
Date last modified: 
Last modified by: First Last, my@email.com
Purpose: 

==========================================================================*/

*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local ster "$ster_dir/diagnostic_specs"

do "0_data_cleaning/1_utils/set_paths.do"

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"


*****************************************************************************
* 						PART 2. OLS Regressions                 		    *
*****************************************************************************

* 1. gen bin vars
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
	egen tavg_bins_32C_InfC_`temp' = rowtotal(tavg_bins_32C_33C_`temp'-tavg_bins_35C_Inf_`temp')
}

* 2. run regressions
* cubic spline
reghdfe deathrate_w99 c.tavg_rcspline_term0_GMFD#i.agegroup c.tavg_rcspline_term1_GMFD#i.agegroup c.tavg_rcspline_term2_GMFD#i.agegroup ///
		c.tavg_rcspline_term3_GMFD#i.agegroup c.tavg_rcspline_term4_GMFD#i.agegroup c.tavg_rcspline_term5_GMFD#i.agegroup c.tavg_rcspline_term6_GMFD#i.agegroup ///
		c.tavg_rcspline_term0_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_rcspline_term1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_rcspline_term2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_rcspline_term3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_rcspline_term4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_rcspline_term5_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_rcspline_term6_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_rcspline_term0_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_rcspline_term1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_rcspline_term2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_rcspline_term3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_rcspline_term4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_rcspline_term5_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_rcspline_term6_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		, absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
				 i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_cspline.ster", replace

* linear spline
reghdfe deathrate_w99 c.tmax_cdd_0C_GMFD#i.agegroup c.tmax_hdd_25C_GMFD#i.agegroup ///
		c.tmax_cdd_0C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tmax_hdd_25C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tmax_cdd_0C_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tmax_hdd_25C_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		, absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
				 i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_lspline.ster", replace

* bins
reghdfe deathrate_w99 c.tavg_bins_nInfC_n13C_GMFD#i.agegroup c.tavg_bins_n13C_n8C_GMFD#i.agegroup c.tavg_bins_n8C_n3C_GMFD#i.agegroup ///
		c.tavg_bins_n3C_2C_GMFD#i.agegroup c.tavg_bins_2C_7C_GMFD#i.agegroup c.tavg_bins_7C_12C_GMFD#i.agegroup c.tavg_bins_12C_17C_GMFD#i.agegroup ///
		c.tavg_bins_22C_27C_GMFD#i.agegroup c.tavg_bins_27C_32C_GMFD#i.agegroup c.tavg_bins_32C_InfC_GMFD#i.agegroup ///
		c.tavg_bins_nInfC_n13C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_bins_n13C_n8C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_bins_n8C_n3C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_bins_n3C_2C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_bins_2C_7C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_bins_7C_12C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_bins_12C_17C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_bins_22C_27C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_bins_27C_32C_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_bins_32C_InfC_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_bins_nInfC_n13C_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_bins_n13C_n8C_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_bins_n8C_n3C_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_bins_n3C_2C_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_bins_2C_7C_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_bins_7C_12C_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_bins_12C_17C_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_bins_22C_27C_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_bins_27C_32C_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_bins_32C_InfC_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		, absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
				 i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_bins.ster", replace


* main model but with population weights in the way the interaction model has them
bysort year agegroup: egen tot_pop = total(population)
gen weight = population / tot_pop


reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
	c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
	c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
	c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
	c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
	c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
	[aw = weight] ///
		, absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
				  i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_popweights.ster", replace
