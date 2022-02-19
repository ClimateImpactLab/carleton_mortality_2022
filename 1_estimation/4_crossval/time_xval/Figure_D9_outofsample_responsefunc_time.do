/*

Purpose: Generate a plot showing the response functions of the uninteracted model using 
the post 2004 data as well as the interacted model estimated using the pre 2005 data
evaluated at the post 2004 income and T averages. The data is divided into income terciles
based on the post 2004 ADM1 average income. The in sample uninteracted models are predicted
separately for each tercile. 

Inputs
------

- `0_data_cleaning/3_final/global_mortality_panel` - Final mortality panel.



Outputs
-------

- `output/1_estimation/figures/7_crossval/time`
    - `Age*_xval_time_ytile.pdf` - 2 x 1 array of income tercile specific uninteracted model 
    response function of post 2004 data and interacted model of pre 2005 data.
    - `Age*_xval_time_ytile_dif.pdf` - 2 x 2 array showing the difference
    between the response functions of the pre 05 predicted and post 04 models at each 
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


local STER "$ster_dir/age_spec_interacted/crossval/time"
local OUTPUT "$output_dir/figures/Figure_D9_crossval/"
local DATA "$data_dir/3_final"

*set rmsg on
cap log close

//log using "`OUTPUT'/logs/log_prepost05_ytile.smcl", replace

*************************************************************************
*                           PART B. Toggles                         *
*************************************************************************

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
*                           PART C. Prepare Dataset                     *
*************************************************************************

* Prepare data for regressions.
do "$REPO/mortality/1_estimation/1_utils/prep_data.do"


* generate dummy for if obs is pre or post 2005
gen pre_05 = year < 2005

unique adm1_code if pre_05 == 1
unique adm1_code if pre_05 == 0


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


* create dummy variables for each post 05 group
forval terc = 1/3 {
    gen post_`terc' = 0
    replace post_`terc' = 1 if pre_05 == 0 & ytile == `terc' 
}

*************************************************************************
*                      PART D. Aggregate Temperature Bin                *
*************************************************************************

forvalues terc = 1/3 {
   
    preserve 

    keep if post_`terc' == 1

    * create population weights
    bysort year agegroup: egen tot_pop = total(population)
    gen weight_`terc' = population / tot_pop

    * save weighted post 05 income mean for prediction
    sum loggdppc_adm1_avg_post [aw = weight_`terc']
    local ymean_post_`terc' = r(mean)

    * save weighted post 05 Tbar mean for prediction
    sum lr_tavg_GMFD_adm1_avg_post [aw = weight_`terc']
    local tmean_post_`terc' = r(mean)

    * save in sample weights for merge
    keep adm2_code year agegroup weight_`terc'
    tempfile w_`terc'
    save "`w_`terc''", replace

    restore

    * merge in sample weights back into main data
    merge 1:1 adm2_code year agegroup using "`w_`terc''"

    * fill out of sample weight values with 1
    replace weight_`terc' = 1 if _merge == 1
    drop _merge



    *--------------------------------------
    * Aggregate Temp bins for ADM2s in cell
    *-------------------------------------- 

    preserve

    keep if post_`terc' == 1

    * create empty global array of values
    global values

    * make list of all bin variables
    ds tavg_bins*GMFD

    foreach var in `r(varlist)' {
        * take weighted avg of bin and save
        sum `var' [aw = weight_`terc'] 
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
    loc p1temp_`terc' = r(N) - 41

    * save min bin number if we are dropping top 0.5% of temp days ( > 361.35 in cumulative days)
    count if sumval > (`daymax' * .995)
    loc p99temp_`terc' = _N - r(N) - 41

    drop if bin < `x_min'
    drop if bin > `x_max'

    
    if `secaxis' == 1 {

        graph tw bar value bin, color(navy) yaxis(1) || bar value bin, color(navy) yaxis(2)  /// 
        ytitle("T distribution (days)", size(small) axis(1)) ytitle(" ", size(small) axis(2)) ///
        xtitle("") fysize(40) xlabel(`x_min'(`x_int')`x_max', labsize(small)) ///
        ylabel(0(10)30, labsize(small) axis(1)) ylabel(0(10)30, labsize(small) axis(2)) ///
        legend(off) text(23 2 "`adm2_obs_`cell''", size(small)) name(hist_`terc')
    }

    else {

        graph tw bar value bin, color(navy) name(hist_`terc') /// 
        ytitle("T distribution (days)", size(small)) xtitle("") fysize(40) ///
        xlabel(`x_min'(`x_int')`x_max', labsize(small)) ylabel(0(10)30, labsize(small)) 
    }

    restore
}

*************************************************************************
*                       PART E. Run and Save Regressions                *
*************************************************************************

if `run_regs' == 1 {

    * regress uniteracted model for post 2004 ADM2s
    forvalues terc = 1/3 {

        preserve
        keep if pre_05 == 1 | post_`terc' == 1

        reghdfe deathrate_w99 ///
        c.tavg_poly_1_GMFD#i.agegroup#c.post_`terc' ///
        c.tavg_poly_2_GMFD#i.agegroup#c.post_`terc' ///
        c.tavg_poly_3_GMFD#i.agegroup#c.post_`terc' /// 
        c.tavg_poly_4_GMFD#i.agegroup#c.post_`terc' ///
        c.tavg_poly_1_GMFD#i.agegroup#c.pre_05 ///
        c.tavg_poly_2_GMFD#i.agegroup#c.pre_05 ///
        c.tavg_poly_3_GMFD#i.agegroup#c.pre_05 /// 
        c.tavg_poly_4_GMFD#i.agegroup#c.pre_05 ///
        c.tavg_poly_1_GMFD#c.loggdppc_adm1_avg_pre#i.agegroup#c.pre_05 ///
        c.tavg_poly_2_GMFD#c.loggdppc_adm1_avg_pre#i.agegroup#c.pre_05 ///
        c.tavg_poly_3_GMFD#c.loggdppc_adm1_avg_pre#i.agegroup#c.pre_05 ///
        c.tavg_poly_4_GMFD#c.loggdppc_adm1_avg_pre#i.agegroup#c.pre_05 ///
        c.tavg_poly_1_GMFD#c.lr_tavg_GMFD_adm1_avg_pre#i.agegroup#c.pre_05 ///
        c.tavg_poly_2_GMFD#c.lr_tavg_GMFD_adm1_avg_pre#i.agegroup#c.pre_05 ///
        c.tavg_poly_3_GMFD#c.lr_tavg_GMFD_adm1_avg_pre#i.agegroup#c.pre_05 ///
        c.tavg_poly_4_GMFD#c.lr_tavg_GMFD_adm1_avg_pre#i.agegroup#c.pre_05 ///
        i.adm0_code#c.prcp_poly_1_GMFD#i.agegroup#c.post_`terc' ///
        i.adm0_code#c.prcp_poly_2_GMFD#i.agegroup#c.post_`terc' ///
        i.adm0_agegrp_code#c.prcp_poly_1_GMFD#c.pre_05 ///
        i.adm0_agegrp_code#c.prcp_poly_2_GMFD#c.pre_05 ///
        [aw = weight_`terc'] ///
        , absorb( i.adm2_code#i.CHN_ts#i.agegroup#c.post_`terc' ///
        i.adm0_code#i.year#i.agegroup#c.post_`terc' ///
        i.adm2_code#i.CHN_ts#i.agegroup#c.pre_05 ///
        i.adm0_code#i.year#i.agegroup#c.pre_05 ) ///
        cluster(adm1_code)
        estimates save "`STER'/Agespec_combined_ytile`terc'.ster", replace

        restore
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
    forval terc = 1/3 {

        *----------------------------------
        * Generate predictions in sample
        *----------------------------------

        qui est use "`STER'/Agespec_combined_ytile`terc'.ster"

        loc line1 = "_b[`age'.agegroup#c.tavg_poly_1_GMFD#c.post_`terc']*(tavg_poly_1_GMFD-`omit')"
        foreach k of num 2/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.post_`terc']*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
            local line1 "`line1' `add'"
            }

        di "`line1'"
        predictnl yhat_post_`terc'_`age' = `line1', se(se_post_`terc'_`age') ci(lowerci_post_`terc'_`age' upperci_post_`terc'_`age')


        * save response function level at 35 degrees
        loc rf35_`terc'_`age' = yhat_post_`terc'_`age'[41]


        *----------------------------------
        * Generate predictions out of sample
        *----------------------------------

        * interacted terms (level)
        local line2 = "_b[`age'.agegroup#c.tavg_poly_1_GMFD#c.pre_05]*(tavg_poly_1_GMFD-`omit')"
        foreach k of num 2/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.pre_05]*(tavg_poly_1_GMFD^`k' - `omit'^`k')"
            local line2 "`line2' `add'"
            }

        * income terms evaluated at mean of cell
        local z = `ymean_post_`terc''
        foreach k of num 1/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.loggdppc_adm1_avg_pre#c.pre_05] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `z'"
            local line2 "`line2' `add'"
            }

        * Tbar terms evaluated at mean of cell
        local z = `tmean_post_`terc''
        foreach k of num 1/`o' {
            local add = "+ _b[`age'.agegroup#c.tavg_poly_`k'_GMFD#c.lr_tavg_GMFD_adm1_avg_pre#c.pre_05] * (tavg_poly_1_GMFD^`k' - `omit'^`k') * `z'"
            local line2 "`line2' `add'"
            }

        di "`line2'"
        predictnl yhat_pre_`terc'_`age' = `line2', se(se_pre_`terc'_`age') ci(lowerci_pre_`terc'_`age' upperci_pre_`terc'_`age')



        *----------------------------------
        * Calculate difference and axes
        *----------------------------------

        * differences
        loc midline "-("
        loc endline ")"

        loc line3 "`line2' `midline' `line1' `endline'"
        di "`line3'"
        predictnl yhat_dif_`terc'_`age' = `line3', se(se_dif_`terc'_`age') ci(lowerci_dif_`terc'_`age' upperci_dif_`terc'_`age')


        * generate series as a % of 35 degree RF level
         gen yhat_dif35_`terc'_`age' = yhat_dif_`terc'_`age' * 100 / abs(`rf35_`terc'_`age'') 


        preserve

        if `trimrf' == 1{
            drop if tavg_poly_1_GMFD < `p1temp_`terc''
            drop if tavg_poly_1_GMFD > `p99temp_`terc''
        }

        * identify y min and max (because ycommon won't work with histograms below)
        sum upperci_dif_`terc'_`age'
        loc y1_max_`terc'_`age' = r(max)

        sum lowerci_dif_`terc'_`age'
        loc y1_min_`terc'_`age' = r(min)

        restore
    }

    *----------------------------------
    * Set Y axes for charts where ycommon won't work
    *----------------------------------

    * identify total ymin and ymax
    loc y1_max_`age' = max(`y1_max_1_`age'', `y1_max_3_`age'')
    loc y1_min_`age' = min(`y1_min_1_`age'', `y1_min_3_`age'')


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
        loc y1_int_`age' = 5
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

    forvalues terc = 1/3 {

        preserve

        * trim y hat if trimrf == 1
        if `trimrf' == 1 {
            drop if tavg_poly_1_GMFD < `p1temp_`terc''
            drop if tavg_poly_1_GMFD > `p99temp_`terc''
        }

        * set vertical lines for middle 99% of temperature days 
        if `p1temp_`terc'' > `x_min' {
            loc xdashmin "xline(`p1temp_`terc'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"
        }
        else {
            loc xdashmin ""
        }
        
        loc xdashmax "xline(`p99temp_`terc'', lcolor(navy) lwidth(vthin) lpattern(shortdash))"

        di "set vertical lines"

        di `rf35_`terc'_`age''


        * set secondary y axis which is % of 35 degree RF
        loc y2_int_`terc'_`age' = ceil(`y1_int_`age''*100/abs(`rf35_`terc'_`age''))

        loc y2_max_`terc'_`age' = round(`y1_max_`age''*100/abs(`rf35_`terc'_`age''), `y2_int_`terc'_`age'')
        loc y2_min_`terc'_`age' = round(`y1_min_`age''*100/abs(`rf35_`terc'_`age''), `y2_int_`terc'_`age'')

        di `y2_max_`terc'_`age''
        di `y2_min_`terc'_`age''
        di `y2_int_`terc'_`age''


        * set chart titles
        if `terc' == 1 {
            loc subtit = "Low Income"
        }
        if `terc' == 3 {
            loc subtit = "High Income"
        }

        *---------------------------------------------------
        * Plot 2x1 chart showing 2 response functions and CIs
        *---------------------------------------------------

        graph tw line yhat_post_`terc'_`age' yhat_pre_`terc'_`age' tavg_poly_1_GMFD, lc(red navy) lwidth(medthin medthin) lpattern(shortdash solid) ///
        || rarea lowerci_post_`terc'_`age' upperci_post_`terc'_`age' tavg_poly_1_GMFD, col(red%15) lwidth(none) ///
        || rarea lowerci_pre_`terc'_`age' upperci_pre_`terc'_`age' tavg_poly_1_GMFD, col(navy%15) lwidth(none) ///
        , legend(order(1 "post 2004 uninteracted model" 2 "pre 2005 interacted model") size(small) rows(1) rowgap(tiny)) ///
        yline(0, lcolor(gs5) lwidth(vthin)) title("`subtit'", size(medsmall)) ///
        xlabel(`x_min'(`x_int')`x_max', labsize(small)) ylabel(, labsize(small)) xtitle("") ytitle("") name(g`terc'_`age')



        *---------------------------------------------
        * Plot chart showing diff in response functions
        *---------------------------------------------

        if `secaxis' == 1 {

            graph tw line yhat_dif_`terc'_`age' tavg_poly_1_GMFD, lc(red) lwidth(medthin) yaxis(1) ///
            || rarea lowerci_dif_`terc'_`age' upperci_dif_`terc'_`age' tavg_poly_1_GMFD, col(red%15) lwidth(none) yaxis(1) ///
            || line yhat_dif35_`terc'_`age' tavg_poly_1_GMFD, lc(red) lwidth(none) yaxis(2) ///
            ylabel(`y1_min_`age''(`y1_int_`age'')`y1_max_`age'', labsize(small) axis(1)) ytitle("difference in mortality", axis(1) size(small)) ///
            ylabel(`y2_min_`terc'_`age''(`y2_int_`terc'_`age'')`y2_max_`terc'_`age'', labsize(vsmall) axis(2)) ytitle("% of 35 degree RF", axis(2) size(small)) ///
            , title("`subtit'", size(medsmall)) yline(0, lcolor(gs5) lwidth(vthin)) legend(off) `xdashmin' `xdashmax' ///
            xlabel(`x_min'(`x_int')`x_max', labsize(small)) xtitle("") name(h`terc'_`age') fysize(80)         
        }

        else {

            graph tw line yhat_dif_`terc'_`age' tavg_poly_1_GMFD, lc(red) lwidth(medthin) ///
            || rarea lowerci_dif_`terc'_`age' upperci_dif_`terc'_`age' tavg_poly_1_GMFD, col(red%15) lwidth(none) ///
            ylabel(`y1_min_`age''(`y1_int_`age'')`y1_max_`age'', labsize(small)) ytitle("difference in mortality", size(small)) ///
            , title("`subtit'", size(medsmall)) yline(0, lcolor(gs5) lwidth(vthin)) legend(off) `xdashmin' `xdashmax' ///
            xlabel(`x_min'(`x_int')`x_max', labsize(small)) xtitle("") name(h`terc'_`age') fysize(80)                
        }

        restore
    }

    *----------------------------------
    * Combine Plots
    *---------------------------------- 

    * combine 2x1 reponse func charts
    grc1leg g1_`age' g3_`age', cols(2) ycommon imargin(tiny) title("Response Function by Income group, Age `age'", size(medsmall)) ///
    subtitle("Post 2004 Uninteracted Model vs Pre 2005 Interacted Model at Ybar and Tbar means", size(small))

    graph export "`OUTPUT'/Age`age'_xval_time_ytile.pdf", replace
    
    * combine 2x2 response dif/histogram charts
    graph combine h1_`age' h3_`age' hist_1 hist_3, cols(2) imargin(2 2 0 0) ///
    title("Difference in response function by income group", size(medium)) subtitle("Predicted Pre 2005 interacted - Post 2004 uninteracted", size(medsmall))

    //graph export "`OUTPUT'/Age`age'_xval_time_ytile_dif.pdf", replace
}


cap log close








