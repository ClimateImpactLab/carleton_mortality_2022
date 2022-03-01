/*
Purpose: Estimates an alternative model of the main regression specification -
- Excluding precipitation-age interactions from the fixed effects

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.

Outputs
-------

- `data/1_estimation/1_ster/age_spec_interacted`
    - `Agespec_interaction_response_noprecip.ster` - Ster files containing results as
    main model specification without any precip fixed variables.
    - `Agespec_interaction_combined_noprecip.ster` - Ster file containing joint estimation
    of main and tv income model allowing for confidence interval to be taken of difference 

Notes
------

Summary of models:
   Main model: 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE

   noprecip - (adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD) terms ommitted from main specification
*/

*****************************************************************************
*                       PART 1. Initializing                                *
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local ster "$ster_dir/diagnostic_specs"

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

di _N



*****************************************************************************
*                       PART 2. OLS Regressions                             *
*****************************************************************************


* no precip (adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD terms dropped)

reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
    c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
    c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
        , absorb(  i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
        cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_noprecip_public.ster", replace
