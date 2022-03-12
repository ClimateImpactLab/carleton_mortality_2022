/*

Purpose: Generates a table calculating out of sample fit (RMSE) of the interacted and uninteracted models,
where the post 2004 observations are predicted using models fitted on the pre 2005 observations.
Creates rows that feed into Table D5 in Carleton et al 2022.


Note: Data must be demeaned/residualized prior to estimation. By providing the residualized data but not the regression 
output that generated it, we are able to mask the not publicly available USA and China mortality data.
Therefor, users can begin the script at this stage rather than being able to residualize themselves. 


Inputs
------

- `DB/0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.
- `DB/y_diagnostics/timecrossval/residualized_series_time` - Residualized series to be merged 1:1 at obs level


Outputs
-------

- `output/1_estimation/tables/5_diagnostic_specs/timecrossval`
    - `rmse_timexval_table.csv` -  csv file containing interacted and uninteracted RMSEs for time crossval test.

Notes
-------

- Log file saved in same directory as output


*/


*****************************************************************************
*                       PART A. Initializing                                *
*****************************************************************************

if "$REPO" == "" {
    global REPO: env REPO
    global DB: env DB 
    global OUTPUT: env OUTPUT 

    do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"
}

set rmsg on
cap log close


* open output & log files
loc data "$DB/1_estimation/2_crossval/timecrossval"
loc output "$output_dir/tables/Table_D5_crossval"

//log using "`output'/logs/crossval_table.smcl", replace 

file open resultcsv using "`output'/rmse_timexval_table.csv", write replace
file write resultcsv "Omitted ADM1s, Observations, RMSE (adapt), RMSE (no adapt), Difference" _n

*************************************************************************
*                      PART C. Prepare Dataset                          *
*************************************************************************


* Prepare data for regressions.
use "$DB/0_data_cleaning/3_final/global_mortality_panel_covariates", clear


* generate dummy for if obs is pre or post 2005
gen pre_05 = year < 2005

* generate sample average Tbar, log gdppc for pre 2005 years
*   (one year one vote given unbalanced panel within adm1 unit)
preserve 
    keep if pre_05 == 1
    bysort iso adm1_id year: keep if _n == 1
    collapse (mean) loggdppc_adm1_avg_pre=loggdppc_adm1 lr_tavg_GMFD_adm1_avg_pre=tavg_GMFD_adm1, by(adm1_code) 
    tempfile avg_pre
    save `avg_pre', replace
restore 

* merge in pre05 data
merge m:1 adm1_code using "`avg_pre'", nogen



* generate sample average Tbar, log gdppc for post 2004 years
*   (one year one vote given unbalanced panel within adm1 unit)
preserve 
    keep if pre_05 == 0
    bysort iso adm1_id year: keep if _n == 1
    collapse (mean) loggdppc_adm1_avg_post=loggdppc_adm1 lr_tavg_GMFD_adm1_avg_post=tavg_GMFD_adm1, by(adm1_code)

    * set up income terciles based on post 2004 incomes
    xtile ytile = loggdppc_adm1_avg_post, nq(3)

    tempfile avg_post
    save `avg_post', replace
restore

* merge in pre05 data
merge m:1 adm1_code using "`avg_post'", nogen



* merge in residualized series 
merge 1:1 adm2_code year agegroup using "`data'/residualized_series_time.dta", nogen


* create local macros for regression terms
forval age = 1/3 {
    forval p = 1/4 {
        loc un_temp          "`un_temp'         tavg_poly_`p'_GMFD_`age'_rsdun"
        loc i_temp           "`i_temp'          tavg_poly_`p'_GMFD_`age'_rsdi"
        loc gdp_pre          "`gdp_pre'         tavg_poly_`p'_GMFD_`age'_gdp_pre_rsdi"
        loc lrt_pre          "`lrt_pre'         tavg_poly_`p'_GMFD_`age'_lrt_pre_rsdi"
        loc gdp_post         "`gdp_post'        tavg_poly_`p'_GMFD_`age'_gdp_post_rsdi"
        loc lrt_post         "`lrt_post'        tavg_poly_`p'_GMFD_`age'_lrt_post_rsdi"
    }
}

* setting model specs
gl specs            "un i"

loc un_lhs          "deathrate_w99_rsdun"
loc i_lhs           "deathrate_w99_rsdi"

loc un_reg          "deathrate_w99_rsdun `un_temp'"
loc i_reg           "deathrate_w99_rsdi  `i_temp' `gdp_pre' `lrt_pre'"
loc i_post_reg      "deathrate_w99_rsdi  `i_temp' `gdp_post' `lrt_post'"



*************************************************************************
*                   PART D. Compute Stats for each cell                 *
*************************************************************************

*--------------------------------------------------
* (1) In sample - pre 2005 obs to serve as reference
*--------------------------------------------------

preserve

* title column
loc title "In Sample Pre 2005 Observations"

* take in sample adm2 years
keep if pre_05 == 1

loc len = _N


* generating weights
bysort year agegroup: egen tot_pop = total(population)
gen weight = population / tot_pop


* calculate RMSEs 
foreach mod in $specs {

    if "`mod'" == "un" {
        loc weights "[aweight = weight]"
    }
    else {
        loc weights ""
    }

    * run regression 
    di "``mod'_reg' `weights'"
    reg ``mod'_reg' `weights'
    est store `mod'_ster


    * Gen in sample yhat and resid
    predict yhat_`mod'
    di "Yhat generated"
    predict resid_`mod', res
    di "resids calculated"


    * RMSE 
    gen resid2_`mod' = resid_`mod'^2
    sum resid2_`mod'
    loc rmse_`mod' = sqrt(r(mean))
}

* rmse dif column
loc dif = `rmse_i' - `rmse_un'

* write out results
file write resultcsv "`title', `len', `rmse_i', `rmse_un', `dif'" _n

di "row added"

restore

*--------------------------------------------------
* (test) In sample - post 2004 obs to serve as reference
*--------------------------------------------------

preserve

* title column
loc title "In Sample Post 2005 Observations"

* take in sample adm2 years
keep if pre_05 == 0

loc len = _N


* generating weights
bysort year agegroup: egen tot_pop = total(population)
gen weight = population / tot_pop


* calculate RMSEs 
foreach mod in "un" "i_post" {

    if "`mod'" == "un" {
        loc weights "[aweight = weight]"
    }
    else {
        loc weights ""
    }

    * run regression 
    di "``mod'_reg' `weights'"
    reg ``mod'_reg' `weights'


    * Gen in sample yhat and resid
    predict yhat_`mod'
    di "Yhat generated"
    predict resid_`mod', res
    di "resids calculated"


    * RMSE 
    gen resid2_`mod' = resid_`mod'^2
    sum resid2_`mod'
    loc rmse_`mod' = sqrt(r(mean))
}

* rmse dif column
loc dif = `rmse_i_post' - `rmse_un'

* write out results
file write resultcsv "`title', `len', `rmse_i_post', `rmse_un', `dif'" _n

di "row added"

restore


*-----------------------------------------
* (2) Predict Out of Sample Post 2004 obs
*-----------------------------------------

preserve

local title "Out of Sample Post 2004 Observations"

* keep post 2005 obs
keep if pre_05 == 0

loc len = _N


* calculate RMSEs for each model
foreach mod in $specs {

    * Gen yhat and resid manually 
    est restore `mod'_ster

    loc line "0"

    * uninteracted terms for both models
    forval age = 1/3 {
        forval p = 1/4 {
            local line = "`line' + _b[tavg_poly_`p'_GMFD_`age'_rsd`mod'] * tavg_poly_`p'_GMFD_`age'_rsd`mod'"
        }
    }

    * interacted terms for interacted model (pre 2005 coefficients, post 2004 covar variables)
    if "`mod'" == "i" {

        forval age = 1/3 {
            forval p = 1/4 {
                local line = "`line' + _b[tavg_poly_`p'_GMFD_`age'_gdp_pre_rsd`mod'] * tavg_poly_`p'_GMFD_`age'_gdp_post_rsd`mod'"
            }
        }
        forval age = 1/3 {
            forval p = 1/4 {
                local line = "`line' + _b[tavg_poly_`p'_GMFD_`age'_lrt_pre_rsd`mod'] * tavg_poly_`p'_GMFD_`age'_lrt_post_rsd`mod'"
            }
        }
    }

    di "`line'"

    predictnl yhat_`mod' = `line'


    di "Yhat generated"

    gen resid_`mod' = ``mod'_lhs' - yhat_`mod'


    * RMSE 
    gen resid2_`mod' = resid_`mod'^2
    sum resid2_`mod'
    loc rmse_`mod' = sqrt(r(mean))



    * calc rmse by iso for additional table
    bysort iso: egen avgresid2_`mod' = mean(resid2_`mod')

    gen isormse_`mod' = sqrt(avgresid2_`mod')

    gsort - isormse_`mod'

    tabstat isormse_`mod', by(iso)
}

* rmse dif column
loc dif = `rmse_i' - `rmse_un'

* write out results
file write resultcsv "`title', `len', `rmse_i', `rmse_un', `dif'" _n

di "row added"

restore



file close resultcsv
cap log close
