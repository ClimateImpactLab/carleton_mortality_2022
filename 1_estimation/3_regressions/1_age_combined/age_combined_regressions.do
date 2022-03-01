/*

Purpose: Estimates the temperature-mortality response function using pooled
subnational data across 40 countries (Discussed in Appendix D).

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.

Outputs
-------

- `data/1_estimation/1_ster/age_combined`
	- `pooled_response_spec*.ster` where * is model 1 through 5. Ster files
	containing uninteracted, age combined regressuion results under various
	fixed effects, estimation, and data construction assumptions.

Notes
------

Summary of models:
    1. 4th-order polynomial OLS (Age x ADM2) & (Age x ADM2) FE
   *2. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE
    3. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) (Age x ADM1 linear trend)
	4. 4th-order polynomial FGLS (Age x ADM2) & (AGE x Country x Year) FE
	5. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE with 13-month climate exposure
* indicates preferred model.

- All regressions are population weighted with clustered standard errors at the
ADM1 level.

- Models also control for AGE x ADM0 precipitation.

- `i.CHN_ts` indicator variable accounts for a discontinuity in China's
mortality/population time series. See 1_estimation/README.md for additional
details.

*/


*****************************************************************************
* 						PART 1. Initializing		 						*
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local ster "$ster_dir/age_combined"

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

*****************************************************************************
* 						PART 2. OLS Regressions                 		    *
*****************************************************************************

* 1. set weighting schemes
bysort year: egen tot_pop = total(population)
gen weight = population / tot_pop

* 2. run regressions

* specification 1
reghdfe deathrate_w99 tavg_poly_1_GMFD tavg_poly_2_GMFD tavg_poly_3_GMFD tavg_poly_4_GMFD ///
		[pw = weight]  ///
		, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year ) ///
		cluster(adm1_code) fast
estimates save "`ster'/pooled_response_spec1_public.ster", replace

* specification 2
reghdfe deathrate_w99 tavg_poly_1_GMFD tavg_poly_2_GMFD tavg_poly_3_GMFD tavg_poly_4_GMFD ///
		[pw = weight] ///
		, absorb(adm0_code##c.prcp_poly_1_GMFD      adm0_code##c.prcp_poly_2_GMFD ///
				 i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)  fast residual(e_hat)
estimates save "`ster'/pooled_response_spec2_public.ster", replace
* save rediduals for FGLS regressions

* specification 3
reghdfe deathrate_w99 tavg_poly_1_GMFD tavg_poly_2_GMFD tavg_poly_3_GMFD tavg_poly_4_GMFD ///
		[pw = weight] ///
		, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
				 i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup adm1_agegrp_code##c.year) ///
		cluster(adm1_code) fast
estimates save "`ster'/pooled_response_spec3_public.ster", replace


*****************************************************************************
* 						PART 3. FGLS Regressions                 		    *
*****************************************************************************

* 1. generate weighting matrix
* get residuals from 1st stage and
* calculate diagonal elements of the weighting matrix
gen e2 = e_hat * e_hat

bysort adm1_code: egen omega = sd(e_hat) if e_hat != .
gen precisionweight = weight * 1/(omega*omega) 

sort iso adm1_id adm2_id year agegroup

* 2. run regressions
* specification 4
reghdfe deathrate_w99 tavg_poly_1_GMFD tavg_poly_2_GMFD tavg_poly_3_GMFD tavg_poly_4_GMFD ///
		[pw = precisionweight] ///
		, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup) ///
		cluster(adm1_code) fast tol(1e-7)
estimates save "`ster'/pooled_response_spec4_public.ster", replace


*****************************************************************************
* 						PART 4. 13-month ave T Regressions         		    *
*****************************************************************************

* specification 5
reghdfe deathrate_w99 tavg_poly_1_GMFD_13m tavg_poly_2_GMFD_13m tavg_poly_3_GMFD_13m tavg_poly_4_GMFD_13m ///
		[pw = weight] ///
		, absorb(adm0_code##c.prcp_poly_1_GMFD adm0_code##c.prcp_poly_2_GMFD ///
				 i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#agegroup ) ///
		cluster(adm1_code) fast
estimates save "`ster'/pooled_response_spec5_public.ster", replace
