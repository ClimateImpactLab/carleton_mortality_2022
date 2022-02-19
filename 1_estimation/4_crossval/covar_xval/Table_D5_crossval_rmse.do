/*

Purpose: Generates a table calculating out of sample fit (RMSE) of the interacted and uninteracted models,
where each row a left out subsection of observations based on their income and climate covariate values 
(each divided into mutually exclusive 3x3 terciles). The interacted and uninteracted models  are then estimated
using the remaing 8/9 adm1s, and used to predict the omitted subsample. Aggregate out of sample RMSEs are calculated 
using the y-hats from the out of sample subsection predictions.


Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.
- `y_diagnostics/covarcrossval/residualized_series` - Residualized series to be merged 1:1 at obs level
- `0_data_cleaning/2_cleaned/covar_pop_count` - IR level population data from projection system from which
2010 and 2100 share of population in each subsections are calculated.


Outputs
-------

- `output/1_estimation/tables/5_diagnostic_specs/rmse_test`
    - ``mod'_rmse_table.csv` -  csv with predictive summary statistics for main model (model speific sample),
    institution model, and institution model with 0s for that covariate.

Notes
-------

- Residualized data is used from file 
- Calculates population figures from covar_pop_count.dta; script to calculate that is saved in 
1_estimation/3_regressions/z_depreciated  

*/


*****************************************************************************
*                       PART A. Initializing                                *
*****************************************************************************

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

set rmsg on
//cap log close

* open output & log files
loc ster "$ster_dir/age_spec_interacted/crossval"
loc data "$DB/1_estimation/2_crossval/covarcrossval"
loc output "$output_dir/tables/Table_D5_crossval"

//log using "`output'/logs/crossval_table.smcl", replace 

file open resultcsv using "`output'/rmse_xval_table_space.csv", write replace
file write resultcsv "Omitted ADM1s, Observations, 2010 Pop Share, 2100 Pop Share, RMSE (adapt), RMSE (no adapt), Difference, R2 (adapt), R2 (no adapt), Difference" _n


*************************************************************************
*                      PART C. Prepare Dataset                          *
*************************************************************************


* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

* merge in residualized series 
merge 1:1 adm2_code year agegroup using "`data'/residualized_series.dta"

drop _merge

* generating terciles of income and tbar based on ADM1
preserve
    collapse (mean) loggdppc_adm1_avg lr_tavg_GMFD_adm1_avg, by(adm1_code)


    * create ytile and save cutoff values
    xtile ytile = loggdppc_adm1_avg, nq(3)
    forval terc = 1/2{
        sum loggdppc_adm1_avg if ytile == `terc'
        loc yc`terc' = r(max)
    }

    * create ttile and save cutoff values
    xtile ttile = lr_tavg_GMFD_adm1_avg, nq(3)
    forval terc = 1/2{
        sum lr_tavg_GMFD_adm1_avg if ttile == `terc'
        loc tc`terc' = r(max)
    }

    keep adm1_code ytile ttile
    tempfile tercile
    save "`tercile'", replace
restore

* merging back into main dataset
merge m:1 adm1_code using "`tercile'", nogen


*************************************************************************
*                   PART D. Construct Pop Figures                       *           
*************************************************************************


*generating age-specific population figures for globe in 2010 and 2100
preserve

    use "$DB/0_data_cleaning/2_cleaned/covar_pop_count.dta", clear
    rename (loggdppc tmean) (lgdppc Tmean)

    gen ytile = .
    gen ttile = .
    replace ytile = 1 if lgdppc<=`yc1'
    replace ytile = 2 if lgdppc>`yc1' & lgdppc<=`yc2'
    replace ytile = 3 if lgdppc>`yc2'
    replace ttile = 1 if Tmean<=`tc1'
    replace ttile = 2 if Tmean>`tc1' & Tmean<=`tc2'
    replace ttile = 3 if Tmean>`tc2'

gen popshare2 = 1 - popshare1 - popshare3
gen pop1 = popshare1*pop
gen pop2 = popshare2*pop
gen pop3 = popshare3*pop
drop if popshare2<0

collapse (sum) pop pop1 pop2 pop3, by(ytile ttile year)
bysort year: egen pop_tot = total(pop)
bysort year: egen pop1_tot = total(pop1)
bysort year: egen pop2_tot = total(pop2)
bysort year: egen pop3_tot = total(pop3)
bysort year: gen pop_per = (pop/pop_tot)*100
bysort year: gen pop1_per = (pop1/pop1_tot)*100
bysort year: gen pop2_per = (pop2/pop2_tot)*100
bysort year: gen pop3_per = (pop3/pop3_tot)*100


local i = 1
sort year ytile ttile
foreach y of numlist 1/3 {
    foreach t of numlist 1/3 {
        local a_Y`y'T`t'_g_2010 = round(pop_per[`i'],.50)
        local a_Y`y'T`t'_g_2100 = round(pop_per[`=`i'+9'],.50)
        local i = `i' + 1
    }
}

restore


*************************************************************************
*                   PART E. Construct Reg Specs                         *           
*************************************************************************


* create local variables for regression
forval age = 1/3 {
    forval p = 1/4 {
        loc un_temp          "`un_temp'         tavg_poly_`p'_GMFD_`age'_rsdun"
        loc i_temp           "`i_temp'          tavg_poly_`p'_GMFD_`age'_rsdi"
        loc i_gdp            "`i_gdp'           tavg_poly_`p'_GMFD_`age'_gdp_rsdi"
        loc i_lrt            "`i_lrt'           tavg_poly_`p'_GMFD_`age'_lrt_rsdi"
    }
}

* setting model specs
gl specs            "un i"

loc un_lhs          "deathrate_w99_rsdun"
loc i_lhs           "deathrate_w99_rsdi"

loc un_reg          "deathrate_w99_rsdun `un_temp'"
loc i_reg           "deathrate_w99_rsdi  `i_temp' `i_gdp' `i_lrt'"


*************************************************************************
*                   PART F. Compute Stats for each cell                 *
*************************************************************************

*--------------------------------------------------
* (1) In sample - full sample to serve as reference
*--------------------------------------------------

* title column
loc title "Full Sample In Sample"

loc len = _N


* Populate RMSE columns
foreach mod in $specs {

    preserve

    
    est use "`ster'/Agespec_`mod'nteracted_residualized_full.ster"

    * Gen yhat and resid
    predict yhat_`mod'
    di "Yhat generated"


    gen resid_`mod' = ``mod'_lhs' - yhat_`mod'


    * RMSE 
    gen resid2_`mod' = resid_`mod'^2
    sum resid2_`mod'
    loc rmse_`mod' = sqrt(r(mean))

    * R2
    scalar sse = r(sum)

    sum ``mod'_lhs'
    scalar mean_var = r(mean) 
    gen diff_`mod' = ``mod'_lhs' - mean_var
    gen diff2_`mod' = diff_`mod'^2
    sum diff2_`mod'
    scalar sst = r(sum)

    loc r2_`mod' = 1-(sse/sst)

    restore
}

* rmse dif column
loc dif = `rmse_i' - `rmse_un'
loc dif2 = `r2_i' - `r2_un'

* write out results
file write resultcsv "`title', `len', 100, 100, `rmse_i', `rmse_un', `dif', `r2_i', `r2_un', `dif2'" _n

di "row added"


*--------------------------------------------------
* (2) Out of sample - Ybar and Tbar cells
*--------------------------------------------------

gen yhat_un     = .
gen yhat_i      = .

* run for each "leave-one-out" cell 
forval y = 1/3 {
    forval t = 1/3 {

        * title column
        loc title "Ybar `y' - Tbar `t' `mod'"


        * Populate RMSE columns
        foreach mod in $specs {

            preserve

            * estimate using all but cell
            drop if ytile == `y' & ttile == `t'       
    

            * generating weights for no adapt
            bysort year agegroup: egen tot_pop = total(population)
            gen weight = population / tot_pop


            if "`mod'" == "un" {
                loc weights "[aweight = weight]"
            }
            else {
                loc weights ""
            }

            * run regression 
            di "``mod'_reg' `weights'"
            reg ``mod'_reg' `weights'

            restore


            * predict out of sample cells

            * Gen yhat and resid
            predict yhat_`mod'_`y'_`t'                  if ytile == `y' & ttile == `t'
            replace yhat_`mod' = yhat_`mod'_`y'_`t'     if ytile == `y' & ttile == `t'
            di "Yhat generated"


            * Obs column
            count if ytile == `y' & ttile == `t'
            loc len_`y'_`t' = r(N)


            * Calculate residuals
            gen resid_`mod'_`y'_`t' = .
            replace resid_`mod'_`y'_`t' = ``mod'_lhs' - yhat_`mod'  if ytile == `y' & ttile == `t'


            * RMSE 
            gen resid2_`mod'_`y'_`t' = resid_`mod'_`y'_`t'^2
            sum resid2_`mod'_`y'_`t'
            loc rmse_`mod'_`y'_`t' = sqrt(r(mean))

            * R2
            scalar sse = r(sum)

            sum ``mod'_lhs' if ytile == `y' & ttile == `t'
            scalar mean_var = r(mean) 
            gen diff_`mod'_`y'_`t' = ``mod'_lhs' - mean_var if ytile == `y' & ttile == `t'
            gen diff2_`mod'_`y'_`t' = diff_`mod'_`y'_`t'^2
            sum diff2_`mod'_`y'_`t'
            scalar sst = r(sum)

            loc r2_`mod'_`y'_`t' = 1-(sse/sst)

        }

        * rmse dif column
        loc dif = `rmse_i_`y'_`t'' - `rmse_un_`y'_`t''
        loc dif2 = `r2_i_`y'_`t'' - `r2_un_`y'_`t''

        * write out results
        file write resultcsv "`title', `len_`y'_`t'', `a_Y`y'T`t'_g_2010', `a_Y`y'T`t'_g_2100', `rmse_i_`y'_`t'', `rmse_un_`y'_`t'', `dif', `r2_i_`y'_`t'', `r2_un_`y'_`t'', `dif2'" _n

        di "row added"
    }
}

*--------------------------------------------------
* (3) Out of sample full sample (weighted avg of leave 1 out)
*--------------------------------------------------

* title column
loc title "Full Sample Out of Sample"

loc len = _N


* compute weighted averages of adapt and no adapt rmse
loc rmse_un = 0
loc rmse_i = 0


foreach mod in $specs {

    * gen rmse and r2 for total out of sample
    gen resid_`mod'  = ``mod'_lhs' - yhat_`mod'

    * RMSE 
    gen resid2_`mod' = resid_`mod'^2
    sum resid2_`mod'
    loc rmse_`mod' = sqrt(r(mean))

    * R2
    scalar sse = r(sum)

    sum ``mod'_lhs'
    scalar mean_var = r(mean) 
    gen diff_`mod' = ``mod'_lhs' - mean_var
    gen diff2_`mod' = diff_`mod'^2
    sum diff2_`mod'
    scalar sst = r(sum)

    loc r2_`mod' = 1-(sse/sst)
}


* rmse dif column
loc dif = `rmse_i' - `rmse_un'
loc dif2 = `r2_i' - `r2_un'


* write out results
file write resultcsv "`title', `len', 100, 100, `rmse_i', `rmse_un', `dif', `r2_i', `r2_un', `dif2'" _n

di "row added"


file close resultcsv
cap log close
