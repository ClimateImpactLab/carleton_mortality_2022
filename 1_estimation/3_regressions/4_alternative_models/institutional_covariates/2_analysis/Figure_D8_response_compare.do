/*

Purpose: Generate plot comparing response functions of main vs institutional covariate models 
(health, edu, institutions, inequality, informality) for high and low income groups, using the
covariate-specific sample. Together, these figures compose Appendix Figure D8

These plots are produce by dividing the estimating sample into two groups, representing
the top and bottom LR income xtile. Predicted response functions at the mean of covariates
within each bin are plotted using the coefficients estimated in
the covariate-specific age interacted regressions

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.

- `data/1_estimation/1_ster/age_spec_interacted`
    - `Agespec_interaction_response_`mod'_sample.ster` - Ster file containing results from
    an age-stacked regression interacted with ADM1 average income and climate matching the
    sample for the covariate data.
    - `Agespec_interaction_response.ster_`covar'` - Ster file containing results
    from an age-stacked regression interacted with ADM1 average income, climate, and the 
    selected covariate from the model.


Outputs
-------

- `output/1_estimation/figures/5_response_func_compare/`mod'`
    - `Age*_response_compare_`mod'.pdf` - 2 x 1 array with the
    showing the highest and lowest income tercile response functions for the
    main and additional covariate models.
    - `Age*_response_compare_`mod'_dif.pdf` - 2 x 2 array showing the difference
    between the response functions of the alternative and main models at each 
    degree by income group, as well as histograms plotting the population - weighted 
    mean of days in the year falling in that bin for that income group

*/

*************************************************************************
*                           PART A. Initializing                        *
*************************************************************************


clear all
set more off
set matsize 10000
set maxvar 32700

set scheme s1color

global REPO: env REPO
global DB: env DB 
global OUTPUT: env OUTPUT 

do "$REPO/carleton_mortality_2022/0_data_cleaning/1_utils/set_paths.do"

local STER "$ster_dir/diagnostic_specs"
local OUTPUT "$output_dir/figures/Figure_D8"
local DATA "$data_dir/3_final"


*****************************************************************************
*                       PART B. Input Model Info                            *
*****************************************************************************

* which model will you be running this for (health, edu, institutions, inequality, informality)?
//local mod "health"
local mod $mod

* do you want to use the log of the covariate value (ie logdocpc rather than docpc)? (1 = yes)
loc logvar = 0


*************************************************************************
*                           PART C Toggles                             *
*************************************************************************


* trim response function to only be evaluated over middle 99% of daily temp distribution
local trimrf = 0

* do you want a secondary Y axis on the dif plots which is the % of the response funtion at 35 degrees?
loc secaxis = 0

* manually set y-axes (so that they can be consistent between all institutional covar models)
loc common_y = 1

* number of panels
local panels = 2

* xtile income groups (takes lowest and highest)
local g = 3

* polynomial
local o = 4

* set baseline temp
local omit = 20

* x-range for plotting
local x_min = -5
local x_max = 40
local x_int = 10


*************************************************************************
*                           PART C. Prepare Dataset                     *
*************************************************************************

* Prepare data for regressions
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

* Does model-specific cleaning and merging 
do "$REPO/mortality/1_estimation/1_utils/`mod'_merge.do"

* assigns the covariate name from the merge file
local covar $covar

if `logvar' == 1 {
    loc covar = "log`covar'"
}

* assigns the full model name from the merge file
local ctit $ctit

if `logvar' == 1 {
    loc ctit = "Log `ctit'"
}


* sort the panel
sort adm1_code agegroup year


*create var for income tercile
preserve
    collapse (mean) loggdppc_adm1_avg, by(adm1_code year)
    xtile ytile = loggdppc_adm1_avg, nq(`g')
    keep adm1_code year ytile
    tempfile tercile
    save "`tercile'", replace
restore

merge m:1 adm1_code year using "`tercile'", nogen

tab ytile

*----------------------------------
* aggregating temperature bins
*----------------------------------

forval y = 1/3 {

    preserve

    keep if ytile == `y'
    di _N

    bysort year agegroup: egen tot_pop = total(population)
    gen weight = population / tot_pop


    * save weighted covariate means for prediction
    foreach var of varlist loggdppc_adm1_avg lr_tavg_GMFD_adm1_avg avg_adm0_`covar' {

        sum `var' [aw = weight]
        loc zvalue_`var'_`y' = r(mean)
    }


    * create empty global array of values
    global values

    * make list of all bin variables
    ds tavg_bins*GMFD

    foreach var in `r(varlist)' {
        * take weighted avg of bin and save
        sum `var' [aw = weight] 
        global values ${values} `r(mean)' 
    }

    * drop all and set new length to how many bins there are
    drop _all
    local num : list sizeof global(values)
    set obs `num'

    gen value = .
    gen bin = .

    forval i = 1/`num' {
        local thisval : word `i' of ${values}
        replace value = `thisval' if _n == `i'
    }

    * calculate cumulative days
    gen sumval = sum(value)
    * ensure it equals 365
    sum sumval
    loc daymax = r(max)

    replace bin = _n
    replace bin = bin - 41

    * save min bin number if we are dropping bottom 0.5% of temp days ( < 3.65 in cumulative days)
    count if sumval < (`daymax' * .005)
    loc p1temp_`y' = r(N) - 41

    * save min bin number if we are dropping top 0.5% of temp days ( > 361.35 in cumulative days)
    count if sumval > (`daymax' * .995)
    loc p99temp_`y' = _N - r(N) - 41

    drop if bin <= `x_min'
    drop if bin >= `x_max'

    *---------------------------------------------
    * Plot t dist histograms
    *---------------------------------------------

    * set lines for 99% t destribution 
    if `p1temp_`y'' > `x_min'    loc xdashmin "xline(`p1temp_`y'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"
    else                            loc xdashmin ""

    if `p99temp_`y'' < `x_max'   loc xdashmax "xline(`p99temp_`y'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"
    else                            loc xdashmax ""


    if `secaxis' == 1 {

        graph tw bar value bin, color(navy) yaxis(1) || bar value bin, color(navy) yaxis(2)  /// 
        ytitle("exposure (days)", size(small) axis(1)) ytitle(" ", size(small) axis(2)) ///
        xtitle("Daily temperature (C)", size(small)) fysize(40) xlabel(`x_min'(`x_int')`x_max', labsize(small)) ///
        ylabel(0(10)30, labsize(small) axis(1)) ylabel(0(10)30, labsize(small) axis(2)) ///
        legend(off) name(hist_`y') `xdashmin' `xdashmax'
    }

    else {

        graph tw bar value bin, color(navy) name(hist_`y') /// 
        ytitle("exposure (days)", size(small)) xtitle("Daily temperature (C)", size(small)) `xdashmin' `xdashmax' fysize(40) ///
        xlabel(`x_min'(`x_int')`x_max', labsize(small)) ylabel(0(10)30, labsize(small)) ///
        text(25 5 "middle 99% temp distribution", size(small))
    }

    restore
}



*************************************************************************
*                       PART D. Generate Plots                          *
*************************************************************************

*----------------------------------
*generating age-specific plots
*----------------------------------

*create obs of 1 degree range from min to max
local min = `x_min'
local max = `x_max'
local obs = `max' - `min' + 1

drop if _n > 0
set obs `obs'
replace tavg_poly_1_GMFD = _n + `min' - 1


foreach age of numlist 1/3 {

    forval y = 1/3 {

        *--------------------------------------------------------
        *Generate predictions for main model (trimmed for sample)
        *--------------------------------------------------------


        *main model estimates
        estimate use "`STER'/Agespec_interaction_response_`mod'_sample.ster"


        *uninteracted terms
        local line = "_b[`age'.agegroup#c.tavg_poly_1_GMFD]*(tavg_poly_1_GMFD-`omit')"
        foreach k of num 2/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD]*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
            local line "`line' `add'"
            }

        *lgdppc and Tmean at the tercile mean
        foreach var in "loggdppc_adm1_avg" "lr_tavg_GMFD_adm1_avg" {
            loc z = `zvalue_`var'_`y''
            foreach k of num 1/`o' {
                local add = "+ _b[`age'.agegroup#c.`var'#c.tavg_poly_`k'_GMFD] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `z'"
                local line "`line' `add'"
                }
            }


        di "`line'"
        predictnl yhat_main_`y'_`age' = `line', se(se_main_`y'_`age') ci(lowerci_main_`y'_`age' upperci_main_`y'_`age')


        * save response function level at 35 degrees
        loc rf35_`y'_`age' = yhat_main_`y'_`age'[41]



        *----------------------------------
        *Generate predictions for alternative model
        *----------------------------------


        *alt model estimates
        estimate use "`STER'/Agespec_interaction_response_`covar'.ster"

        *uninteracted terms
        local line = "_b[`age'.agegroup#c.tavg_poly_1_GMFD]*(tavg_poly_1_GMFD-`omit')"
        foreach k of num 2/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD]*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
            local line "`line' `add'"
            }

        *lgdppc and Tmean at the tercile mean
        foreach var in "loggdppc_adm1_avg" "lr_tavg_GMFD_adm1_avg" "avg_adm0_`covar'" {
            loc z = `zvalue_`var'_`y''
            foreach k of num 1/`o' {
                local add = "+ _b[`age'.agegroup#c.`var'#c.tavg_poly_`k'_GMFD] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `z'"
                local line "`line' `add'"
                }
            }


        di "`line'"
        predictnl yhat_alt_`y'_`age' = `line', se(se_alt_`y'_`age') ci(lowerci_alt_`y'_`age' upperci_alt_`y'_`age')


        *----------------------------------
        * Calculate difference
        *----------------------------------

        * generate difference between yhat_main and yhat_alt
        gen yhat_dif_`y'_`age' = yhat_alt_`y'_`age' - yhat_main_`y'_`age'


        * generate series as a % of 35 degree RF level
         gen yhat_dif35_`y'_`age' = yhat_dif_`y'_`age' * 100 / abs(`rf35_`y'_`age'')



        * -----------------------------------------------------------------------
        * Identify y min and max (because ycommon won't work with histograms below)
        * -----------------------------------------------------------------------

        preserve

        if `trimrf' == 1 {
            drop if tavg_poly_1_GMFD < `p1temp_`y''
            drop if tavg_poly_1_GMFD > `p99temp_`y''
        }

        * set limits for diff chart (no CIs)
        sum yhat_dif_`y'_`age'
        loc yl_max_`y'_`age' = r(max)
        loc yl_min_`y'_`age' = r(min)

        * set upper limit for levels chart (CIs)
        sum upperci_main_`y'_`age'
        loc yc_main_max_`y'_`age' = r(max)

        sum upperci_alt_`y'_`age'
        loc yc_alt_max_`y'_`age' = r(max)

        loc yc_max_`y'_`age' = max(`yc_main_max_`y'_`age'', `yc_alt_max_`y'_`age'')


        * set lower limit for levels chart (CIs)
        sum lowerci_main_`y'_`age'
        loc yc_main_min_`y'_`age' = r(min)

        sum lowerci_alt_`y'_`age'
        loc yc_alt_min_`y'_`age' = r(min)

        loc yc_min_`y'_`age' = min(`yc_main_min_`y'_`age'', `yc_alt_min_`y'_`age'')

        restore
    }

    *----------------------------------------------------------------------
    * Set common Y axes for charts where ycommon won't work (because of hists)
    *----------------------------------------------------------------------

    foreach s in "l" "c" {

        * identify total ymin and ymax
        loc y`s'_max_`age' = max(`y`s'_max_1_`age'', `y`s'_max_3_`age'')
        loc y`s'_min_`age' = min(`y`s'_min_1_`age'', `y`s'_min_3_`age'')


        loc y`s'range_`age' = `y`s'_max_`age'' - `y`s'_min_`age''
        di "range:"
        di `y`s'range_`age''


        if `y`s'range_`age'' < 2 {
            loc y`s'_max_`age' = round(`y`s'_max_`age''+.1, .2)
            loc y`s'_min_`age' = round(`y`s'_min_`age''-.1, .2)
            loc y`s'_int_`age' = .2
        }

        else if `y`s'range_`age'' > 2 & `y`s'range_`age'' < 8 {
            loc y`s'_max_`age' = ceil(`y`s'_max_`age'')
            loc y`s'_min_`age' = floor(`y`s'_min_`age'')
            loc y`s'_int_`age' = 1
        }

        else if `y`s'range_`age'' > 8 & `y`s'range_`age'' < 20 {
            loc y`s'_max_`age' = round(ceil(`y`s'_max_`age''+1), 2)
            loc y`s'_min_`age' = round(floor(`y`s'_min_`age''-1), 2)
            loc y`s'_int_`age' = 2
        }

        else if `y`s'range_`age'' > 20 & `y`s'range_`age'' < 50 {
            loc y`s'_max_`age' = round(ceil(`y`s'_max_`age''+2.5), 5)
            loc y`s'_min_`age' = round(floor(`y`s'_min_`age''-2.5), 5)
            loc y`s'_int_`age' = 5
        }

        else {
            loc y`s'_max_`age' = round(ceil(`y`s'_max_`age''+5), 10)
            loc y`s'_min_`age' = round(floor(`y`s'_min_`age''-5), 10)
            loc y`s'_int_`age' = 10   
        }

        di "set axes"
    }

    *************************************************************************
    *                       PART G. Generate Plots                          *
    *************************************************************************

    forval y = 1/3 {

        preserve

        * trim y hat if trimrf == 1
        if `trimrf' == 1 {
            drop if tavg_poly_1_GMFD < `p1temp_`y''
            drop if tavg_poly_1_GMFD > `p99temp_`y''
        }

        * set vertical lines for middle 99% of temperature days 
        if `p1temp_`y'' > `x_min'    loc xdashmin "xline(`p1temp_`y'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"
        else                            loc xdashmin ""

        if `p99temp_`y'' < `x_max'   loc xdashmax "xline(`p99temp_`y'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"
        else                            loc xdashmax ""


        * label chart titles
        if `y' == 1 loc inctit "Low"
        if `y' == 3 loc inctit "High"

        * set y axes (manually across the 5 covariates or automatically based on best fit)
        if `common_y' == 1 & `age' == 1 {
            loc yllab   "-1(0.5)1.5"
            loc yclab   "-4(2)8"
            * set secondary y axis for difference plot which is % of 35 degree RF
            loc y2_int_`y'_1 = ceil(0.5*100/abs(`rf35_`y'_`age''))
            loc y2_max_`y'_1 = round(2*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
            loc y2_min_`y'_1 = round(-1*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
        }
        else if `common_y' == 1 & `age' == 2 {
            loc yllab   "-0.9(0.3)1.2"
            loc yclab   "-3(1)3"
            * set secondary y axis for difference plot which is % of 35 degree RF
            loc y2_int_`y'_2 = ceil(0.3*100/abs(`rf35_`y'_`age''))
            loc y2_max_`y'_2 = round(1.2*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
            loc y2_min_`y'_2 = round(-0.9*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
        }
        else if `common_y' == 1 & `age' == 3 {
            loc yllab   "-4(2)10"
            loc yclab   "-15(15)45"
            * set secondary y axis for difference plot which is % of 35 degree RF
            loc y2_int_`y'_3 = ceil(2*100/abs(`rf35_`y'_`age''))
            loc y2_max_`y'_3 = round(10*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
            loc y2_min_`y'_3 = round(-4*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
        }
        else {
            loc yllab   "`yl_min_`age''(`yl_int_`age'')`yl_max_`age''"
            loc yclab   "`yc_min_`age''(`yc_int_`age'')`yc_max_`age''"
            * set secondary y axis for difference plot which is % of 35 degree RF
            loc y2_int_`y'_`age' = ceil(`yl_int_`age''*100/abs(`rf35_`y'_`age''))
            loc y2_max_`y'_`age' = round(`yl_max_`age''*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
            loc y2_min_`y'_`age' = round(`yl_min_`age''*100/abs(`rf35_`y'_`age''), `y2_int_`y'_`age'')
        }

        loc y2lab       "`y2_min_`y'_`age''(`y2_int_`y'_`age'')`y2_max_`y'_`age''"        


        *---------------------------------------------------
        * Plot chart showing 2 response functions and CIs
        *---------------------------------------------------

        graph tw line yhat_main_`y'_`age' yhat_alt_`y'_`age' tavg_poly_1_GMFD, lc(navy red) lwidth(medthin medthin) lpattern(solid shortdash) ///
        || rarea lowerci_main_`y'_`age' upperci_main_`y'_`age' tavg_poly_1_GMFD, col(navy%15) lwidth(none) ///
        || rarea lowerci_alt_`y'_`age' upperci_alt_`y'_`age' tavg_poly_1_GMFD, col(red%15) lwidth(none) ///
        , legend(order(1 "main model" 2 "`mod' model") size(small) rows(1) rowgap(tiny)) ///
        yline(0, lcolor(gs5) lwidth(vthin)) title("`inctit' Income", size(medsmall)) `xdashmin' `xdashmax' ///
        ylabel(`yclab', labsize(small)) ytitle("mortality response", size(small)) ///
        xlabel(`x_min'(`x_int')`x_max', labsize(small)) xtitle("") name(g`y'_`age') fysize(80)

        di "saved graph 1"

        *---------------------------------------------
        * Plot chart showing diff in response functions
        *---------------------------------------------

        if `secaxis' == 1 {

            graph tw line yhat_dif_`y'_`age' tavg_poly_1_GMFD, lc(red) lwidth(medthin) yaxis(1) ///
            || line yhat_dif35_`y'_`age' tavg_poly_1_GMFD, lc(red) lwidth(none) yaxis(2) ///
            ylabel(`yllab', labsize(small) axis(1)) ytitle("difference in mortality", axis(1) size(small)) ///
            ylabel(`y2lab', labsize(vsmall) axis(2)) ytitle("% of 35 degree RF", axis(2) size(small)) ///
            , title("`inctit' Income", size(medsmall)) yline(0, lcolor(gs5) lwidth(vthin)) legend(off) `xdashmin' `xdashmax' ///
            xlabel(`x_min'(`x_int')`x_max', labsize(small)) xtitle("") name(h`y'_`age') fysize(80)        
        }

        else {

            graph tw line yhat_dif_`y'_`age' tavg_poly_1_GMFD, lc(red) lwidth(medthin) ///
            ylabel(`yllab', labsize(small)) ytitle("difference in mortality", size(small)) ///
            , title("`inctit' Income", size(medsmall)) yline(0, lcolor(gs5) lwidth(vthin)) legend(off) `xdashmin' `xdashmax' ///
            xlabel(`x_min'(`x_int')`x_max', labsize(small)) xtitle("") name(h`y'_`age') fysize(80)                
        }

        di "saved graph 2"

        restore
    }

    *----------------------------------
    * Combine Plots
    *---------------------------------- 

    * label chart titles
    if `age' == 1 loc agetit "< 5" 
    if `age' == 2 loc agetit "5 - 64"
    if `age' == 3 loc agetit "> 64"

    * combine 2x1 reponse func charts
    grc1leg g1_`age' g3_`age' hist_1 hist_3, cols(2) imargin(2 2 0 0 ) title("Heterogeneity in the Mortality-Temperature Relationship, Age `agetit'", size(medsmall)) ///
    subtitle("Robustness to Inclusion of the `ctit' Covariate", size(small))

    if `common_y' == 1 graph export "`OUTPUT'/Age`age'_response_compare_`covar'_ycommon.pdf", replace
    if `common_y' != 1 graph export "`OUTPUT'/Age`age'_response_compare_`covar'.pdf", replace
    
    * combine 2x2 response dif/histogram charts
    graph combine h1_`age' h3_`age' hist_1 hist_3, cols(2) imargin(2 2 0 0) ///
    title("Heterogeneity in the Mortality-Temperature Relationship, Age `agetit'", size(medium)) subtitle("Robustness to Inclusion of the `ctit' Covariate", size(medsmall))

    //if `common_y' == 1 graph export "`OUTPUT'/`mod'/Age`age'_response_compare_`covar'_dif_ycommon.pdf", replace
    //if `common_y' != 1 graph export "`OUTPUT'/`mod'/Age`age'_response_compare_`covar'_dif.pdf", replace
}


cap log close


