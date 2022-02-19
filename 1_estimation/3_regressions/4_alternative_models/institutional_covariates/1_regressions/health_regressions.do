/*

Purpose: Estimates the temperature-mortality response function with
demographic and subnational heterogeneity. Additionally Uses doctors per capita covariate.

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.
- `0_data_cleaning/2_cleaned/institutional_covariates/wdi_docs_pc.dta` - final institutional quality data

Outputs
-------

- `data/1_estimation/1_ster/age_spec_interacted`
    - `Agespec_interaction_response_health_sample.ster` - Ster file containing
    results from an age-stacked regression interacted with ADM1 average income
    and climate for sample overlapping with WDI data
    - `ster'/Agespec_interaction_response_docpc.ster` - Ster file containing results from
    an age-stacked regression interacted with ADM1 average income, climate, and ADM0
    average of WDI doctors per capita
    - `ster'/Agespec_interaction_response_logdocpc.ster` - Ster file containing results from
    an age-stacked regression interacted with ADM1 average income, climate, and ADM0
    average of log of WDI doctors per capita


Notes
------

Summary of model:
    1. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE
    2. 4th-order polynomial OLS, with (tavg x docpc) interactions and
       (Age x ADM2) & (AGE x Country x Year) FE
    3. 4th-order polynomial OLS, with (tavg x logdocpc) interactions and
       (Age x ADM2) & (AGE x Country x Year) FE

- Temperature polynomials are interacted with time-invariant ADM1-level
covariates of average income and climate. Specifically, income and climate are
averages of 13-year and 30-year bartlett kernels, respectively.

- Models also control for AGE x ADM0 precipitation.

- All regressions are unweighted with clustered standard errors at the
ADM1 level.

- `i.CHN_ts` indicator variable accounts for a discontinuity in China's
mortality/population time series. See 1_estimation/README.md for additional
details.

NOTE: This code is an additional test of the main model. As the
`age_spec_interacted_regressions.do` carries forward the perferred model
(Spec. 2) through the rest of the analysis, this code only runs that model
by default.

*/

*****************************************************************************
*                       PART A. Initializing                                *
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local ster "$ster_dir/diagnostic_specs"

*****************************************************************************
*                       PART B. Prepare Data                           *
*****************************************************************************

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

* Merge in WDI doctors per capita data
do "$REPO/mortality/1_estimation/1_utils/health_merge.do"



*****************************************************************************
*                       PART C. OLS Regressions                             *
*****************************************************************************



* 1) main specification, but only run on sample matching WDI doctors pc data availability

reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
    c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
    c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
        , absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
                  i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
        cluster(adm1_code) // removed `fast` as it was not working
estimates save "`ster'/Agespec_interaction_response_health_sample.ster", replace


* 2) main specification but with additional docpc covariate x tavg interaction terms

reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
    c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
    c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
    c.tavg_poly_1_GMFD#c.avg_adm0_docpc#i.agegroup c.tavg_poly_2_GMFD#c.avg_adm0_docpc#i.agegroup ///
    c.tavg_poly_3_GMFD#c.avg_adm0_docpc#i.agegroup c.tavg_poly_4_GMFD#c.avg_adm0_docpc#i.agegroup ///
        , absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
                  i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
        cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_docpc.ster", replace


* 3) main specification but with additional log of docpc covariate x tavg interaction terms

reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
    c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
    c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
    c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
    c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
    c.tavg_poly_1_GMFD#c.avg_adm0_logdocpc#i.agegroup c.tavg_poly_2_GMFD#c.avg_adm0_logdocpc#i.agegroup ///
    c.tavg_poly_3_GMFD#c.avg_adm0_logdocpc#i.agegroup c.tavg_poly_4_GMFD#c.avg_adm0_logdocpc#i.agegroup ///
        , absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
                  i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
        cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_logdocpc.ster", replace

