/*=======================================================================

Purpose: Uses HDDCDD regressions to generate plots of response functions and
scatters of response values of these and main regressions (Appendix Figure D6)


==========================================================================*/

*****************************************************************************
* 						PART 0. Initializing		 					*
*****************************************************************************
* 0. seeds for generating random numbers
local seed 999

* 1. set up path

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local ster 		"$ster_dir/diagnostic_specs"
local output 	"$output_dir/figures/Figure_D6"

use "$data_dir/3_final/global_mortality_panel", clear

*****************************************************************************
* 						PART 1. Generate variables for regressions			*
*****************************************************************************
drop if year > 2010

* 1. create winsorized deathrate with-in country-agegroup
bysort iso agegroup: egen deathrate_p99 = pctile(deathrate), p(99)
gen deathrate_w99 = deathrate
replace deathrate_w99 = deathrate_p99 if deathrate > deathrate_p99 & !mi(deathrate)
drop deathrate_p99

* 2. set up sample  
* (no long being regression sample in this file)
gen sample = 0
replace sample = 1 if year < = 2010
replace sample = 1 if agegroup != 0 | iso == "IND"
replace sample = 0 if mi(deathrate_w99)
replace sample = 0 if mi(tavg_poly_1_GMFD)
replace sample = 0 if mi(prcp_poly_1_GMFD)
replace sample = 0 if mi(loggdppc_adm1_avg)
replace sample = 0 if mi(lr_tavg_GMFD_adm1_avg)

keep if sample == 1

* 3. clean up ids
sort iso adm1_id
egen adm0_code 			= group(iso)
egen adm1_code 			= group(iso adm1_id)
replace adm2_id 		= adm1_id if iso == "JPN"

sort iso adm1_id adm2_id
egen adm2_code 			= group(iso adm1_id adm2_id)

egen adm0_agegrp_code 	= group(iso agegroup)
egen adm1_agegrp_code	= group(iso adm1_id agegroup)




*****************************************************************************
* 						PART 3. Betas at 35C for all insample regions       *
*****************************************************************************

* 1. keep IDs and covariates
keep adm0 iso adm1 adm1_id adm0_code adm1_code ///
	loggdppc_adm1_avg lr_tavg_GMFD_adm1_avg lr_hdd_20C_GMFD_adm1_avg lr_cdd_20C_GMFD_adm1_avg
duplicates drop

gen T = 35

* 2. Get the regression parameters from .ster files	
quietly {
	* 2.1. import estimation results for Tmean
	estimate use "`ster'/Agespec_interaction_response.ster"
	
	forvalues agegrp = 1(1)3 {
		forvalues i = 1(1)4 {

			gen beta_poly`i'_agegrp`agegrp'_Tmean = _b[`agegrp'.agegroup#c.tavg_poly_`i'_GMFD] ///
									+ _b[`agegrp'.agegroup#c.lr_tavg_GMFD_adm1_avg#c.tavg_poly_`i'_GMFD] * lr_tavg_GMFD_adm1_avg  ///
									+ _b[`agegrp'.agegroup#c.loggdppc_adm1_avg#c.tavg_poly_`i'_GMFD] * loggdppc_adm1_avg 
		}
	}
	*
		
	* 2.2. import estimation results for HDD CDD
	estimate use "`ster'/Agespec_interaction_HDDCDD_response.ster"
		
	forvalues agegrp = 1(1)3 {
		forvalues i = 1(1)4 {
			gen beta_poly`i'_agegrp`agegrp'_HDDCDD = _b[`agegrp'.agegroup#c.tavg_poly_`i'_GMFD] ///
									+ _b[`agegrp'.agegroup#c.lr_hdd_20C_GMFD_adm1_avg#c.tavg_poly_`i'_GMFD] * lr_hdd_20C_GMFD_adm1_avg ///
									+ _b[`agegrp'.agegroup#c.lr_cdd_20C_GMFD_adm1_avg#c.tavg_poly_`i'_GMFD] * lr_cdd_20C_GMFD_adm1_avg ///
									+ _b[`agegrp'.agegroup#c.loggdppc_adm1_avg#c.tavg_poly_`i'_GMFD] * loggdppc_adm1_avg
		}
	}
	*


* 3. Calculate the response at 35C relative to 20C

	foreach m in "Tmean" "HDDCDD" {
		forvalues agegrp = 1(1)3 {
			replace T = 35
			gen Y_`m'_agegrp`agegrp' 	= T * beta_poly1_agegrp`agegrp'_`m' + T * T * beta_poly3_agegrp`agegrp'_`m' + ///
										  T * T * T * beta_poly3_agegrp`agegrp'_`m' + T * T * T * T * beta_poly4_agegrp`agegrp'_`m'
			replace T = 20
			gen Y_ref	= T * beta_poly1_agegrp`agegrp'_`m' + T * T * beta_poly3_agegrp`agegrp'_`m' + ///
							T * T * T * beta_poly3_agegrp`agegrp'_`m' + T * T * T * T * beta_poly4_agegrp`agegrp'_`m'
			replace Y_`m'_agegrp`agegrp' = Y_`m'_agegrp`agegrp' - Y_ref
			drop Y_ref
		}
		*
	}
	*

* 4. PLOT the responses from both models
	forvalues agegrp = 1(1)3 {
		if `agegrp' == 1 { 
			local agegroup = "0-4"
		}
		if `agegrp' == 2 { 
			local agegroup = "5-64"
		}
		if `agegrp' == 3 { 
			local agegroup = "65+"
		}
		*
				
		graph twoway ///
				(line Y_HDDCDD_agegrp`agegrp' Y_HDDCDD_agegrp`agegrp', sort lp(dash) color(gs4)) ///
				(scatter Y_Tmean_agegrp`agegrp' Y_HDDCDD_agegrp`agegrp', ms(T) msize(vsmall) color(dknavy)) ///
				, legend(off)  ///
					xtitle("Deaths per 100,000 (from HDD CDD Model)") ///
					ytitle("Deaths per 100,000 (from Tmean Model)") ///
					title("Age `agegroup'") ///
					xlabel( , labs(small) grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					xtick( , grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ylabel( , labs(small) glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					ytick(, grid gmin gmax glw(thin) glpattern(dot) glc(gs10) tlc(gs12)) ///
					graphregion(color(gs16))
		graph save "`output'/gph/RF_comparemodels_35C_agegrp`agegrp'.gph", replace
	}
	*

	graph combine "`output'/gph/RF_comparemodels_35C_agegrp1.gph" ///
					"`output'/gph/RF_comparemodels_35C_agegrp2.gph" ///
					"`output'/gph/RF_comparemodels_35C_agegrp3.gph" ///
					, ///
		title("Responses at 35C (relative to 20C)", size(medsmall)) ///
		iscale(* .8) rows(1)  ysize(5) xsize(12)  ///
		graphregion( color(gs16) )
	graph export "`output'/RF_comparemodels_35C.pdf", as(pdf) replace
		
}
* end of quietly




