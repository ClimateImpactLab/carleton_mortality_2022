/*

Purpose: Generate either a 3x3 or 2x2 array plot, each cell displaying two response functions. The data
is broken up into terciles along both covariate axis based on the post 2004 averages of LR income (Y axis)
and Tbar (X axis). For each cell, the response function of the uninteracted model using the in sample
data and the predicted response function of the interacted model using the out of sample data are shown. 


Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.


Outputs
-------

- `data/1_estimation/1_ster/age_spec_interacted/crossval`
    - `Agespec_uninteracted_`ytile'_`ttile'.ster` - regression of uninteracted model using only ADM2s that 
    fall in both the given income and Tbar terciles.
    - `Agespec_interacted_`ytile'_`ttile'.ster` - regression of interacted model using all ADM2s except those 
    that fall in both the given income and Tbar terciles.

- `output/figures/Figure_D9_crossval/`
    - `Age*_xval_dual_conditioned_3x3.pdf` - 3 x 3 array with each ADM2 falling into one of the cells
    based on its post-2004 ADM1 average income and Tbar. An in sample response function using the uninteracted
    model and an out of sample response function using the interaction model are plotted.
    - `Age*_xval_dual_conditioned_2x2.pdf` - 2 x 2 array showing only the "corners" of the 3 x 3 chart -
    i.e. the ADM2s that fall into cold-rich, cold-poor, hot-rich, hot-poor groups.
     with the data divided on either.
    - `Age*_xval_resids_2x2_dif.pdf` - 2 x 4 array showing the difference
    between the in sample and out of sample response functions at each 
    degree by income and Tbar group, as well as histograms plotting the population - weighted 
    mean of days in the year falling in that bin for that income group


Notes
-------

- Because of how many regressions have to be run, this file saves .sters giving the user the option
of skipping that part of the process with the "run_regs" toggle.

- The out of sample interacted model is evaluated at the post 2004 population weighted means of 
Ybar and Tbar of the in sample ADM2s.


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


local STER "$ster_dir/age_spec_interacted/crossval/space"
local OUTPUT "$output_dir/figures/Figure_D9_crossval/"
local DATA "$data_dir/3_final"

set rmsg on
cap log close

//log using "`OUTPUT'/logs/log_combined.smcl", replace


*************************************************************************
*                           PART B. Toggles                         *
*************************************************************************

* how many groups are we splitting the data into (default is terciles, 3)
local g = 3

* do you want to run the regressions (1) or just produce the plots using the saved .ster (0)
local run_regs = 0

* trim response function to only be evaluated over middle 99% of daily temp distribution
local trimrf = 1

* do you want a secondary Y axis on the dif plots which is the % of the response funtion at 35 degrees?
loc secaxis = 0

* model polynomial
local o = 4

* baseline temp for response function
local omit = 20

* x-range for plotting
local x_min = -5
local x_max = 36
local x_int = 10


*************************************************************************
*                         PART C. Prepare Dataset                       *
*************************************************************************


* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"

* test with smaller sample
*sample 10

* generating terciles of income and tbar based on ADM1
preserve
    collapse (mean) loggdppc_adm1_avg lr_tavg_GMFD_adm1_avg, by(adm1_code)
    xtile ytile = loggdppc_adm1_avg, nq(`g')
    xtile ttile = lr_tavg_GMFD_adm1_avg, nq(`g')
    keep adm1_code ytile ttile
    tempfile tercile
    save "`tercile'", replace
restore

* merging back into main dataset
merge m:1 adm1_code using "`tercile'", nogen

* create single categorical variable for each ytile ttile group 
egen cell = group(ytile ttile)

* create dummy variables for falling in or out of sample for each group
forval num = 1/9 {
    gen insample_`num' = 0
    replace insample_`num' = 1 if cell == `num'
    gen outsample_`num' = 1 - insample_`num'
}


*************************************************************************
*        PART D. Calculate Summary Stats and Aggregate Temp Bins        *
*************************************************************************


* calculating num ADM1s, ADM2s, and weighted covar avgs
forval cell = 1/9 {

    preserve 

    * select only obs from subsample
    keep if cell == `cell'

    * set weighting schemes
    bysort year agegroup: egen tot_pop = total(population)
    gen weight_`cell' = population / tot_pop

    * count ADM1s and ADM2s
    by adm1_code year, sort: gen nadm1 = _n == 1 
    count if nadm1
    local adm1_obs_`cell' = r(N)
    local adm1_obs_`cell' = "#adm1-year: " + strofreal(`adm1_obs_`cell'', "%9.0gc")
    
    by adm2_code year, sort: gen  nadm2= _n == 1 
    count if nadm2
    local adm2_obs_`cell' = r(N)
    local adm2_obs_`cell' = "#adm2-year: " + strofreal(`adm2_obs_`cell'', "%9.0gc")

    * set in sample covar weighted means 
    sum loggdppc_adm1_avg [aw = weight_`cell']
    loc ymean_`cell' = r(mean)

    sum lr_tavg_GMFD_adm1_avg [aw = weight_`cell']
    loc tmean_`cell' = r(mean)

    * save in sample weights for merge
    keep adm2_code year agegroup weight_`cell'
    tempfile w_`cell'
    save "`w_`cell''", replace

    restore

    * merge in sample weights back into main data
    merge 1:1 adm2_code year agegroup using "`w_`cell''"

    * fill out of sample weight values with 1
    replace weight_`cell' = 1 if _merge == 1
    drop _merge


    *--------------------------------------
    * Aggregate Temp bins for ADM2s in cell
    *-------------------------------------- 

    preserve

    * select only obs from subsample
    keep if cell == `cell'
    
    * create empty global array of values
    global values

    * make list of all bin variables
    ds tavg_bins*GMFD

    foreach var in `r(varlist)' {
        * take weighted avg of bin and save
        sum `var' [aw = weight_`cell'] 
        global values ${values} `r(mean)' 
    }

    * drop all and set new length to how many bins there are
    drop _all
    local num : list sizeof global(values)
    set obs `num'

    gen value = .
    gen bin = .

    * set value to avg days in bin
    forval i = 1/`num' {
        local thisval : word `i' of ${values}
        replace value = `thisval' if _n == `i'
    }

    * calculate cumulative days
    gen sumval = sum(value)
    * ensure it equals 365
    sum sumval
    loc daymax = r(max)

    * set bin to order of bin (lowest = 1)
    replace bin = _n
    * recenter so that it is set to upper limit of bin 
    replace bin = bin - 41

    * save min bin number if we are dropping bottom 0.5% of temp days ( < 3.65 in cumulative days)
    count if sumval < (`daymax' * .005)
    loc p1temp_`cell' = r(N) - 41

    * save min bin number if we are dropping top 0.5% of temp days ( > 361.35 in cumulative days)
    count if sumval > (`daymax' * .995)
    loc p99temp_`cell' = _N - r(N) - 41

    * drop bins outside of x axis limit
    drop if bin < `x_min'
    drop if bin > `x_max'

    
    * plot and save histogram
    if `secaxis' == 1 {

        graph tw bar value bin, color(navy) yaxis(1) || bar value bin, color(navy) yaxis(2)  /// 
        ytitle("T distribution (days)", size(small) axis(1)) ytitle(" ", size(small) axis(2)) ///
        xtitle("") fysize(40) xlabel(`x_min'(`x_int')`x_max', labsize(small)) ///
        ylabel(0(10)30, labsize(small) axis(1)) ylabel(0(10)30, labsize(small) axis(2)) ///
        legend(off) text(23 2 "`adm2_obs_`cell''", size(small)) name(hist_`cell')        
    }

    
    else {

        graph tw bar value bin, color(navy) /// 
        ytitle("T distribution (days)", size(small)) ylabel(0(10)30, labsize(small)) ///
        xtitle("") xlabel(`x_min'(`x_int')`x_max', labsize(small)) fysize(40) ///
        legend(off) text(23 2 "`adm2_obs_`cell''", size(small)) name(hist_`cell')
    }

    restore

} 

*************************************************************************
*                       PART E. Run and Save Regressions                *
*************************************************************************

if `run_regs' == 1 {
    forval cell = 1/9 {

        reghdfe deathrate_w99 ///
        c.tavg_poly_1_GMFD#c.insample_`cell'#i.agegroup ///
        c.tavg_poly_2_GMFD#c.insample_`cell'#i.agegroup ///
        c.tavg_poly_3_GMFD#c.insample_`cell'#i.agegroup ///
        c.tavg_poly_4_GMFD#c.insample_`cell'#i.agegroup ///
        c.tavg_poly_1_GMFD#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_2_GMFD#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_3_GMFD#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_4_GMFD#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg#c.outsample_`cell'#i.agegroup ///
        c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg#c.outsample_`cell'#i.agegroup ///
        i.adm0_code#c.prcp_poly_1_GMFD#i.agegroup#c.insample_`cell' ///
        i.adm0_code#c.prcp_poly_2_GMFD#i.agegroup#c.insample_`cell' ///
        i.adm0_agegrp_code#c.prcp_poly_1_GMFD#c.outsample_`cell' ///
        i.adm0_agegrp_code#c.prcp_poly_2_GMFD#c.outsample_`cell' ///
        [aw = weight_`cell'] ///
        , absorb( i.adm2_code#i.CHN_ts#i.agegroup#c.insample_`cell' ///
        i.adm0_code#i.year#i.agegroup#c.insample_`cell' ///
        i.adm2_code#i.CHN_ts#i.agegroup#c.outsample_`cell' ///
        i.adm0_code#i.year#i.agegroup#c.outsample_`cell' ) ///
        cluster(adm1_code)
        est save "`STER'/Agespec_combined_`cell'.ster", replace
    }
}


*************************************************************************
*                    PART F. Generate Predictions                       *
*************************************************************************


*create obs of 1 degree range from min to max
local min = `x_min'
local max = `x_max'
local obs = `max' - `min' + 1

drop if _n > 0
set obs `obs'
replace tavg_poly_1_GMFD = _n + `min' - 1


* loop through age groups to make age-specific plot
forval age = 1/3 {
    forval cell = 1/9 {

        qui est use "`STER'/Agespec_combined_`cell'.ster"

        * uninteracted terms (level)
        loc line1 = "_b[`age'.agegroup#c.tavg_poly_1_GMFD#c.insample_`cell']*(tavg_poly_1_GMFD-`omit')"
        foreach k of num 2/`o' {
                local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.insample_`cell']*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
                local line1 "`line1' `add'"
                }

            di "`line1'"
            predictnl yhat_in_`cell'_`age' = `line1', se(se_in_`cell'_`age') ci(lowerci_in_`cell'_`age' upperci_in_`cell'_`age')


        * save response function level at 35 degrees
        loc rf35_`cell'_`age' = yhat_in_`cell'_`age'[41]


            
        * interacted terms (level)
        local line2 = "_b[`age'.agegroup#c.tavg_poly_1_GMFD#c.outsample_`cell']*(tavg_poly_1_GMFD-`omit')"
        foreach k of num 2/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.outsample_`cell']*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
            local line2 "`line2' `add'"
            }

        * income terms evaluated at mean of cell
        local z = `ymean_`cell''
        foreach k of num 1/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.loggdppc_adm1_avg#c.outsample_`cell'] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `z'"
            local line2 "`line2' `add'"
            }

        * Tbar terms evaluated at mean of cell
        local z = `tmean_`cell''
        foreach k of num 1/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.lr_tavg_GMFD_adm1_avg#c.outsample_`cell'] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `z'"
            local line2 "`line2' `add'"
            }
        

        di "`line2'"
        predictnl yhat_out_`cell'_`age' = `line2', se(se_out_`cell'_`age') ci(lowerci_out_`cell'_`age' upperci_out_`cell'_`age')


        * differences
        loc midline "-("
        loc endline ")"

        loc line3 "`line2' `midline' `line1' `endline'"
        di "`line3'"
        predictnl yhat_dif_`cell'_`age' = `line3', se(se_dif_`cell'_`age') ci(lowerci_dif_`cell'_`age' upperci_dif_`cell'_`age')


        * generate series as a % of 35 degree RF level
         gen yhat_dif35_`cell'_`age' = yhat_dif_`cell'_`age' * 100 / abs(`rf35_`cell'_`age'') 



        preserve

        * trim y hat if trimrf == 1
        if `trimrf' == 1 {
            drop if tavg_poly_1_GMFD < `p1temp_`cell''
            drop if tavg_poly_1_GMFD > `p99temp_`cell''
        }

        * identify y min and max (because ycommon won't work with histograms below)
        sum upperci_dif_`cell'_`age'
        loc y1_max_`cell'_`age' = r(max)

        sum lowerci_dif_`cell'_`age'
        loc y1_min_`cell'_`age' = r(min)

        restore
    }


    *----------------------------------
    * Set Y axes for charts where ycommon won't work
    *----------------------------------

    * identify total ymin and ymax
    loc y1_max_`age' = max(`y1_max_7_`age'', `y1_max_9_`age'', `y1_max_1_`age'', `y1_max_3_`age'')
    loc y1_min_`age' = min(`y1_min_7_`age'', `y1_min_9_`age'', `y1_min_1_`age'', `y1_min_3_`age'')


    loc y1range_`age' = `y1_max_`age'' - `y1_min_`age''
    di "range:"
    di `y1range_`age''


    if `y1range_`age'' < 6 {
        loc y1_max_`age' = ceil(`y1_max_`age'')
        loc y1_min_`age' = floor(`y1_min_`age'')
        loc y1_int_`age' = 1
    }

    else if `y1range_`age'' > 30 {
        loc y1_max_`age' = round(ceil(`y1_max_`age''), 5)
        loc y1_min_`age' = round(floor(`y1_min_`age''), 5)
        loc y1_int_`age' = 10
    }

    else {
        loc y1_max_`age' = round(ceil(`y1_max_`age''), 2)
        loc y1_min_`age' = round(floor(`y1_min_`age''), 2)
        loc y1_int_`age' = 2
    }

    di `y1_max_`age''
    di `y1_min_`age''
    di `y1_int_`age''


    di "set axes"


    *************************************************************************
    *                       PART G. Generate Plots                          *
    *************************************************************************

    forval cell = 1/9 {

        preserve

        * trim y hat if trimrf == 1
        if `trimrf' == 1 {
            drop if tavg_poly_1_GMFD < `p1temp_`cell''
            drop if tavg_poly_1_GMFD > `p99temp_`cell''
        }

        * set vertical lines for middle 99% of temperature days 
        if `p1temp_`cell'' > `x_min' {
            loc xdashmin "xline(`p1temp_`cell'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"
        }
        else {
            loc xdashmin ""
        }
        
        loc xdashmax "xline(`p99temp_`cell'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"

        di "set vertical lines"

        di `rf35_`cell'_`age''


        * set secondary y axis which is % of 35 degree RF
        loc y2_int_`cell'_`age' = ceil(`y1_int_`age''*100/abs(`rf35_`cell'_`age''))

        loc y2_max_`cell'_`age' = round(`y1_max_`age''*100/abs(`rf35_`cell'_`age''), `y2_int_`cell'_`age'')
        loc y2_min_`cell'_`age' = round(`y1_min_`age''*100/abs(`rf35_`cell'_`age''), `y2_int_`cell'_`age'')

        di `y2_max_`cell'_`age''
        di `y2_min_`cell'_`age''
        di `y2_int_`cell'_`age''

        * set chart titles
        loc yterc = "Low"
        if `cell' > 6 {
            loc yterc = "High"
        }

        loc tterc = "Cold"
        if mod(`cell'/3, 1) == 0 {
            loc tterc = "Hot"
        }



        *---------------------------------------------------
        * Plot 2x1 chart showing 2 response functions and CIs
        *---------------------------------------------------

        graph tw line yhat_in_`cell'_`age' yhat_out_`cell'_`age' tavg_poly_1_GMFD ///
        , lc(red navy) lwidth(medthin medthin) lpattern(shortdash solid) ///
        || rarea lowerci_in_`cell'_`age' upperci_in_`cell'_`age' tavg_poly_1_GMFD, col(red%15) lwidth(none) ///
        || rarea lowerci_out_`cell'_`age' upperci_out_`cell'_`age' tavg_poly_1_GMFD, col(navy%15) lwidth(none) ///
        legend(order(1 "in sample - uninteracted" 2 "out of sample - interacted") size(small) rows(1) rowgap(tiny)) ///
        yline(0, lcolor(gs5) lwidth(vthin)) title("`yterc' Income - `tterc'", size(small)) ///
        xlabel(`x_min'(`x_int')`x_max', labsize(small)) ylabel(, labsize(small)) xtitle("") ytitle("") name(g_`cell'_`age')

        di "saved chart 1"


        *---------------------------------------------
        * Plot chart showing diff in response functions
        *---------------------------------------------

        if `secaxis' == 1 {

            graph tw line yhat_dif_`cell'_`age' tavg_poly_1_GMFD, lc(red) lwidth(medthin) yaxis(1) ///
            || rarea lowerci_dif_`cell'_`age' upperci_dif_`cell'_`age' tavg_poly_1_GMFD, col(red%15) lwidth(none) yaxis(1) ///
            || line yhat_dif35_`cell'_`age' tavg_poly_1_GMFD, lc(red) lwidth(none) yaxis(2) ///
            ylabel(`y1_min_`age''(`y1_int_`age'')`y1_max_`age'', labsize(small) axis(1)) ytitle("difference in mortality", axis(1) size(small)) ///
            ylabel(`y2_min_`cell'_`age''(`y2_int_`cell'_`age'')`y2_max_`cell'_`age'', labsize(vsmall) axis(2)) ytitle("% of 35 degree RF", axis(2) size(small)) ///
            , legend(off) yline(0, lcolor(gs5) lwidth(vthin)) `xdashmin' `xdashmax' ///
            xlabel(`x_min'(`x_int')`x_max', labsize(small)) xtitle("") name(h_`cell'_`age') fysize(80) title("`yterc' Income - `tterc'", size(small))        
        }

        else {

            graph tw line yhat_dif_`cell'_`age' tavg_poly_1_GMFD, lc(red) lwidth(medthin) ///
            || rarea lowerci_dif_`cell'_`age' upperci_dif_`cell'_`age' tavg_poly_1_GMFD, col(red%15) lwidth(none) ///
            ylabel(`y1_min_`age''(`y1_int_`age'')`y1_max_`age'', labsize(small)) ytitle("difference in mortality", size(small)) ///
            , legend(off) yline(0, lcolor(gs5) lwidth(vthin)) `xdashmin' `xdashmax' ///
            xlabel(`x_min'(`x_int')`x_max', labsize(small)) xtitle("") name(h_`cell'_`age') fysize(80) title("`yterc' Income - `tterc'", size(small))

        }         

        di "saved chart 2"

        restore

    }

    *----------------------------------
    * Combine Plots
    *---------------------------------- 

    * combine 2x2 reponse func charts
    grc1leg g_7_`age' g_9_`age' g_1_`age' g_3_`age', cols(2) ycommon imargin(zero) ///
    title("Response Function by Income and Tbar groups: Age `age'", size(medsmall)) ///
    subtitle("In sample Uninteracted model vs Out of sample Interacted model", size(medsmall)) ///

    graph export "`OUTPUT'/Age`age'_xval_combined_2x2.pdf", replace

    * combine 2x2 response dif/histogram charts
    graph combine h_7_`age' h_9_`age' hist_7 hist_9 h_1_`age' h_3_`age' hist_1 hist_3 , cols(2) imargin(2 2 0 0) ///
    title("Difference in response function by income group", size(medsmall)) subtitle("Predicted out of sample - In sample uninteracted", size(small))
    
    //graph export "`OUTPUT'/Age`age'_xval_combined_2x2_dif.pdf", replace

}



cap log close



