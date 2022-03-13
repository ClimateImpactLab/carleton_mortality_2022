/*

Purpose: Estimates age specific temperature-mortality response function with
termperature-income and temperature-LR climate interaction terms. 

The `Agespec_interaction_response` file is the main regression that is discussed
in Carleton et al 2022, and is carried through to the projection system 
and beyond:

*2. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE


Notes: In this public release, the `_public` suffix is added on to signify
that the regressions would be run on the publically available mortality 
sample, which excludes USA and China.

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.

Outputs
-------

- `data/1_estimation/1_ster/age_spec_interacted`
	- `Agespec_interaction_response.ster` - Ster file containing results from
	an age-stacked regression interacted with ADM1 average income and climate. 

- `data/1_estimation/1_ster/age_spec_interacted/altspec`
	- `Agespec_response_spec3_interacted.ster` - Ster files containing covariate
	interacted regression results under fixed effect model assumptions from
	specifications 1, 3, 4, and 5.

Notes
------

Summary of models:
    1. 4th-order polynomial OLS (Age x ADM2) & (Age x ADM2) FE
   *2. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE
    3. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) (Age x ADM1 linear trend)
	4. 4th-order polynomial FGLS (Age x ADM2) & (AGE x Country x Year) FE
	5. 4th-order polynomial OLS (Age x ADM2) & (AGE x Country x Year) FE with 13-month climate exposure
* indicates preferred model.

- Temperature polynomials are interacted with time-invariant ADM1-level 
covariates of average income and climate. Specifically, income and climate are
averages of 13-year and 30-year bartlett kernels, respectively.

- Models also control for AGE x ADM0 precipitation.

- All regressions are unweighted with clustered standard errors at the
ADM1 level.

- `i.CHN_ts` indicator variable accounts for a discontinuity in China's
mortality/population time series. See 1_estimation/README.md for additional
details.

NOTE: As we only carry forward the perferred model (Spec. 2) through the rest of
the analysis, this code only runs that model by default. To run interacted
regressions for other specifications, modify the `altspec` toggle below from
0 to 1.

*/


*****************************************************************************
* 						PART 1. Initializing		 						*
*****************************************************************************

if "$REPO" == "" {
	global REPO: env REPO
	global DB: env DB 
	global OUTPUT: env OUTPUT 

	do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

local ster "$ster_dir/age_spec_interacted"

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

local altspec 0

*****************************************************************************
* 						PART 2. OLS Regressions                 		    *
*****************************************************************************

* 1. run regressions
* specification 
reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
	c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
	c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
	c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
	c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
	c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		, absorb( adm0_agegrp_code##c.prcp_poly_1_GMFD  adm0_agegrp_code##c.prcp_poly_2_GMFD ///
				  i.adm2_code#i.CHN_ts#i.agegroup  i.adm0_code#i.year#i.agegroup ) ///
		cluster(adm1_code)
estimates save "`ster'/Agespec_interaction_response_public.ster", replace 


if (`altspec') {

	*****************************************************************************
	* 							Alternative FE OLS Regressions          		*
	*****************************************************************************

	* 1. set weighting schemes
	bysort year agegroup: egen tot_pop = total(population)
	gen weight = population / tot_pop

	* 2. run regressions
	* specification 1
	reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
		c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
		c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///	
		c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
			, absorb( i.adm0_code#c.prcp_poly_1_GMFD#i.agegroup i.adm0_code#c.prcp_poly_2_GMFD#i.agegroup ///
			 i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year ) ///
			cluster(adm1_code)
	estimates save "`ster'/altspec/Agespec_response_spec1_interacted_public.ster", replace

	* specification 3
	reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
		c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
		c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///	
		c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
			, absorb( i.adm0_code#c.prcp_poly_1_GMFD#i.agegroup i.adm0_code#c.prcp_poly_2_GMFD#i.agegroup ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup adm1_agegrp_code##c.year) ///
			cluster(adm1_code)
	estimates save "`ster'/altspec/Agespec_response_spec3_interacted_public.ster", replace


	*****************************************************************************
	* 								FGLS Regressions                 		    *
	*****************************************************************************

	preserve

		* 1. generate weighting matrix
		bysort adm2_code agegroup: gen n = _N
		drop if n < 5
		* get residuals from 1st stage
		* specification 2
		reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
			c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
			c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
			c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///			
			c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
			c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
				, absorb( i.adm0_code#c.prcp_poly_1_GMFD#i.agegroup i.adm0_code#c.prcp_poly_2_GMFD#i.agegroup ///
				 i.adm2_code#i.CHN_ts#i.agegroup   i.adm0_code#i.year#i.agegroup ) ///
				cluster(adm1_code) residual(e_hat)

		* calculate diagonal elements of the weighting matrix
		bysort adm1_code: egen omega = sd(e_hat) if e_hat != .
		gen precisionweight = 1/(omega*omega) 

		sort iso adm1_id adm2_id agegroup year

		* 2. run regressions
		* specification 4
		reghdfe deathrate_w99 c.tavg_poly_1_GMFD#i.agegroup c.tavg_poly_2_GMFD#i.agegroup ///
			c.tavg_poly_3_GMFD#i.agegroup c.tavg_poly_4_GMFD#i.agegroup ///
			c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#i.agegroup ///
			c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#i.agegroup ///	
			c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
			c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
				[pw = precisionweight] ///
				, absorb(i.adm0_code#c.prcp_poly_1_GMFD#i.agegroup i.adm0_code#c.prcp_poly_2_GMFD#i.agegroup ///
					i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup)  ///
				cluster(adm1_code) tol(1e-7) maxiter(10000)

		estimates save "`ster'/altspec/Agespec_response_spec4_interacted_public.ster", replace
	restore

	*****************************************************************************
	* 								13-month ave T Regressions         		    *
	*****************************************************************************

	* specification 5
	reghdfe deathrate_w99 c.tavg_poly_1_GMFD_13m#i.agegroup c.tavg_poly_2_GMFD_13m#i.agegroup ///
		c.tavg_poly_3_GMFD_13m#i.agegroup c.tavg_poly_4_GMFD_13m#i.agegroup ///
		c.tavg_poly_1_GMFD_13m#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_2_GMFD_13m#c.loggdppc_adm1_avg#i.agegroup ///
		c.tavg_poly_3_GMFD_13m#c.loggdppc_adm1_avg#i.agegroup c.tavg_poly_4_GMFD_13m#c.loggdppc_adm1_avg#i.agegroup ///	
		c.tavg_poly_1_GMFD_13m#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_2_GMFD_13m#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
		c.tavg_poly_3_GMFD_13m#c.lr_tavg_GMFD_adm1_avg#i.agegroup c.tavg_poly_4_GMFD_13m#c.lr_tavg_GMFD_adm1_avg#i.agegroup ///
			, absorb(i.adm0_code#c.prcp_poly_1_GMFD#i.agegroup i.adm0_code#c.prcp_poly_2_GMFD#i.agegroup ///
				i.adm2_code#i.CHN_ts#i.agegroup i.adm0_code#i.year#i.agegroup ) ///
			cluster(adm1_code)
	estimates save "`ster'/altspec/Agespec_response_spec5_interacted_public.ster", replace

}
