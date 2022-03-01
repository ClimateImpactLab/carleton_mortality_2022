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

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"


*****************************************************************************
* 						PART 2. OLS Regressions                 		    *
*****************************************************************************

* 1. run regressions
* specification 
reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
					c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
					c.tavg_poly_1_GMFD#c.lr_hdd_20C_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_hdd_20C_GMFD_adm1_avg#i.agegroup ///
					c.tavg_poly_3_GMFD#c.lr_hdd_20C_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_hdd_20C_GMFD_adm1_avg#i.agegroup ///
					c.tavg_poly_1_GMFD#c.lr_cdd_20C_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_cdd_20C_GMFD_adm1_avg#i.agegroup ///
					c.tavg_poly_3_GMFD#c.lr_cdd_20C_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_cdd_20C_GMFD_adm1_avg#i.agegroup ///
					c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
					c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		, absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
				  i.adm2_code#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code) fast
estimates save "`ster'/Agespec_interaction_HDDCDD_response_public.ster", replace

