# Purpose: Calculates response functions for purposes of plotting responses and
# visualizing temperature sensitivity (e.g., maps of the effect of a 35C day on mortality).  

CSVV_DEFAULT = glue('{DB}/2_projection/3_impacts/main_specification/inputs/',
    'Agespec_interaction_GMFD_POLY-4_TINV_CYA_NW_w1.csvv')

COV_DEFAULT = glue('{DB}/2_projection/3_impacts/main_specification/raw/',
    'single/rcp85/CCSM4/low/SSP3')

BETA_INPUT_DEFAULT = glue('{DB}/2_projection/3_impacts/main_specification/raw/',
    'single')

BETA_OUTPUT_DEFAULT = glue('{OUTPUT}/figures/Figure_3_D5_beta_maps')
RF_OUTPUT_DEFAULT = glue('{OUTPUT}/figures/Figure_3_D5_spaghettis')
DELTA_OUTPUT_DEFAULT = glue('{OUTPUT}/figures/Figure_E2_delta_maps')

#' Generates response functions, or betas (which we define as the sensitivity of
#' mortality to a given temperature day, i.e., the response function height at
#' X degrees celsius) for a given age group and future year. This function
#' is used primarily to generate values for plots, as the CIL projection
#' system handles generating response functions for actual impacts estimation. In
#' particular, this function supports Figures 5 and 6 in Carleton et al. (2019).
#' 
#' Inputs
#' ------
#' This function requires an age group and directories to the variables that
#' determine the response function in a given location and year, i.e., the
#' coefficients (`CSVV`), the minimum mortality temperature (`MMTdir`) and the
#' covariates (`covar`).
#' 
#' Outputs
#' -------
#' Dataframe long by region, temperature, year, with variables for various clipping
#' assumptions and diagnostic output. For example `betas_all_clip` corresponds to a
#' response function with all clipping assumptions used in our projections.
#' 
#' Parameters/Return
#' -----------------
#' @param age agegroup ('young', 'older', 'oldest')
#' @param CSVV Full path to CSVV file.
#' @param MMTdir Directory containing minimum mortality temperatures (MMT) for each region.
#' @param override_MMTdir FALSE to use the MMTs within the MMTdir file, or any numeric value, to set the reference temperature for all regions to an arbitrary number.
#' @param cov_path Full path to `allpreds` file and `polymins` file (usually 
#' in single output directory directory)
#' @param baseline baseline year for counterfactual approximation (2015)
#' @param yearlist Years for which to estimate response.
#' @param summ_temp Temperature at which to filter response to and generate
#' summary statistics with (NULL returns entire response function)
#' @param inc_adapt Determins whether income adaptation is calculated (T/F)
#' @return Dataframe containing responses for all regions in the specified
#' years, with various clipping assumptions.
calculate.beta = function(
    age,
    CSVV=CSVV_DEFAULT,
    MMTdir=COV_DEFAULT,
    override_MMTdir=FALSE,
    cov_path=COV_DEFAULT,
    baseline=2015,
    yearlist=c(2015, 2050, 2100),
    summ_temp=35,
    inc_adapt=F) {

    #load minimum ref temp 
    ref_temperatures = memo.csv(glue("{MMTdir}/",
        "Agespec_interaction_GMFD_POLY-4_TINV_CYA_NW_w1-{age}-polymins.csv"), 
        stringsAsFactors = F)

    ref_temperatures$brute = NULL #not used anyways 

    #if user wants to override the MMTs with specified values, a hacky solution to change minimum number of lines
    #is to direclty modify the loaded MMTs file. 
    if (!isFALSE(override_MMTdir)){
        stopifnot(is.numeric(override_MMTdir) & length(override_MMTdir)==1) #verifying it's a single numeric number
        ref_temperatures$analytic = NULL
        ref_temperatures$analytic = rep(override_MMTdir, nrow(ref_temperatures)) #replacing the analytic solutions column
    }

    #load covariates
    filt=glue('Agespec_interaction_GMFD_POLY-4_TINV_CYA_NW_w1-{age}')
    betas = memo.csv(glue('{cov_path}/mortality-allpreds.csv')) %>%
        dplyr::filter(
            model==filt,
            year %in% yearlist)

    #read csvv - switch this to dt fread to avoid the meta line issues.
    model = "poly"
    skip.no = ifelse(model == "poly", 18,  16) 
    csvv = read.csv(CSVV, skip = skip.no, header = F,
        sep= ",", stringsAsFactors = T)

    squish_function = stringr::str_squish

    # Update necessary additions to year list.
    if (!(baseline %in% yearlist))
        yearlist = c(baseline, yearlist)

    if (!is.null(summ_temp) & !(2100 %in% yearlist))
        yearlist = c(yearlist, 2100)

    #subset to relevant rows & remove blank spaces in characters
    csvv = csvv[-c(2,4,6, nrow(csvv)-1, nrow(csvv)), ] %>%
        rowwise() %>%
        mutate_all(~ squish_function(.)) %>%
        ungroup()

    #extract only cols from specified age group, transpose and put into df
    col.interval = ifelse(model == "poly", 11, 5) 
    if (age=="oldest")
        csvv = data.frame(t(csvv[1:3, (3+2*col.interval):(3+3*col.interval)]))
    else if (age == "young")
        csvv = data.frame(t(csvv[1:3, 1:(1+col.interval)]))
    else
        csvv = data.frame(t(csvv[1:3, (2+col.interval):(2+2*col.interval)]))

    names(csvv) = c("pred", "covar", "gamma")
    csvv$gamma = as.numeric(as.character(csvv$gamma))

    message('Data loaded. Calculating Betas...')
    # Calculate effective betas (full adaption)
    # Note that we define a "beta" as the temperature sensitivity of mortality at a given
    # daily average temp, i.e., the height of the response function at X degrees C.
    betas$tas = csvv$gamma[csvv$pred=="tas" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas" & csvv$covar=="loggdppc"]*betas$loggdppc

    betas$tas2 = csvv$gamma[csvv$pred=="tas2" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas2" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas2" & csvv$covar=="loggdppc"]*betas$loggdppc

    betas$tas3 = csvv$gamma[csvv$pred=="tas3" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas3" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas3" & csvv$covar=="loggdppc"]*betas$loggdppc

    betas$tas4 = csvv$gamma[csvv$pred=="tas4" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas4" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas4" & csvv$covar=="loggdppc"]*betas$loggdppc

    # Calculate effective betas (clim adapt only) for clipping assumption that rising income
    # cannot increase temp. sensitivity of mortality (affectionately called "good-money" clipping).
    betas$tas_clim = csvv$gamma[csvv$pred=="tas" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas" & csvv$covar=="loggdppc"]*betas$loggdppc[betas$year==baseline]

    betas$tas2_clim = csvv$gamma[csvv$pred=="tas2" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas2" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas2" & csvv$covar=="loggdppc"]*betas$loggdppc[betas$year==baseline]

    betas$tas3_clim = csvv$gamma[csvv$pred=="tas3" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas3" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas3" & csvv$covar=="loggdppc"]*betas$loggdppc[betas$year==baseline]

    betas$tas4_clim = csvv$gamma[csvv$pred=="tas4" & csvv$covar=="1"] + 
        csvv$gamma[csvv$pred=="tas4" & csvv$covar=="climtas"]*betas$climtas + 
        csvv$gamma[csvv$pred=="tas4" & csvv$covar=="loggdppc"]*betas$loggdppc[betas$year==baseline]

    if (inc_adapt) {
        betas$tas_inc <- csvv$gamma[csvv$pred=="tas" & csvv$covar=="1"] +
            csvv$gamma[csvv$pred=="tas" & csvv$covar=="climtas"]*betas$climtas[betas$year==baseline] +
            csvv$gamma[csvv$pred=="tas" & csvv$covar=="loggdppc"]*betas$loggdppc
        betas$tas2_inc <- csvv$gamma[csvv$pred=="tas2" & csvv$covar=="1"] +
            csvv$gamma[csvv$pred=="tas2" & csvv$covar=="climtas"]*betas$climtas[betas$year==baseline] +
            csvv$gamma[csvv$pred=="tas2" & csvv$covar=="loggdppc"]*betas$loggdppc
        betas$tas3_inc <- csvv$gamma[csvv$pred=="tas3" & csvv$covar=="1"] +
            csvv$gamma[csvv$pred=="tas3" & csvv$covar=="climtas"]*betas$climtas[betas$year==baseline] +
            csvv$gamma[csvv$pred=="tas3" & csvv$covar=="loggdppc"]*betas$loggdppc
        betas$tas4_inc <- csvv$gamma[csvv$pred=="tas4" & csvv$covar=="1"] +
            csvv$gamma[csvv$pred=="tas4" & csvv$covar=="climtas"]*betas$climtas[betas$year==baseline] +
            csvv$gamma[csvv$pred=="tas4" & csvv$covar=="loggdppc"]*betas$loggdppc
    }


    #create vector of temperatures
    temp = seq(-20,50) 

    #expand dataframe by length(temp)
    betas.expanded = betas[rep(seq_len(nrow(betas)), length(temp)), ]
    betas.expanded = betas.expanded[order(betas.expanded$region, betas.expanded$year),]
    exp.temp <- rep(temp, nrow(betas))
    betas.expanded$temp = exp.temp
    
    betas.expanded = left_join(betas.expanded, ref_temperatures, by = c("region"))

    response = calculate_response(betas.expanded, temp, inc_adapt)


    if (!is.null(summ_temp)) {

        # Calculate percentage decrease in marginal impacts caused by increasing incomes
        if (inc_adapt) {
            b_2015 = mean(response$betas_all_clip[
                response$year==baseline & response$temp==summ_temp])
            full_2100 = mean(response$betas_all_clip[
                response$year==2100 & response$temp==summ_temp])
            inc_2100 = mean(response$betas_all_clip_inc[
                response$year==2100 & response$temp==summ_temp]) 
            response$decline = (b_2015 - inc_2100)/(b_2015 - full_2100)*100 
        }

        # Store temperature distribution weighted average response to days above 30C in 
        # 2015 in Houston (Harris County USA.44.2628) and Seattle (King County USA.48.2971) 
        # relative to 20C (do this for each age group).

        # Houston: In sample proportion of days above 30C
        weights = list(
            '30' = .8344115,
            '31' = .1491691, 
            '32' = .0153181, 
            '33' = .0011013)

        vals = c()
        for (temp in c(30, 31, 32, 33)) {
            v = ( response$betas_all_clip[response$temp==temp &
                response$region=="USA.44.2628" & 
                response$year == baseline] - 
                response$betas_all_clip[response$temp==20 &
                response$region=="USA.44.2628" & 
                response$year == 2015] ) * weights[[paste(temp)]]
            vals = c(vals, v)
        }
        response$houston = sum(vals)

        # Seattle: only one day at 30C in our entire sample, so just 
        # taking the 30C beta.
        response$seattle = ( 
            response$betas_all_clip[response$temp==30 &
                response$region=="USA.48.2971" &
                response$year == baseline] - 
            response$betas_all_clip[response$temp==20 &
                response$region=="USA.48.2971" &
                response$year == 2015] )

        # Subset to just the necessary temperature
        response = subset(response, response$temp==summ_temp)
    }

    return(response)
}


#' This is merely a helper function for `calculate.beta` above. It uses the model
#' coefficients, MMT and covariates, to calculate the temperature-mortality
#' response. It is nevertheless a key function because it implements the various adaptation constrainting (clipping) assumptions, which are documented in the code 
#' but best outlined in the main text and appendix of Carleton et al. (2019). Sequentially : 
#' 
#' 1. Rising income cannot increase temp. sensitivity of mortality (goodmoney-clipping)
#' 2. Weakly increasing monotonicity to the left and right of the MMT. 
#'
#' @param betas.expanded Intermediate dataframe from `calculate.beta` containing
# coefficients, MMT, and covariates.
#' @param temp Vector of temperatures at which to calculate the response. Note
#' that due to weak monotonicity clipping, this vector must include a wide range
#' of temperatures, even if the function is only mean to output the beta at one
#' particular temperature value.
#' @param inc_adapt Determins whether income adaptation is calculated (T/F)
#' @return Dataframe containing clipped response functions.
calculate_response = function( betas.expanded, temp, inc_adapt=F) {

    # Calculate response (full adaptation)
    # Note that we define a "beta" as the temperature sensitivity of mortality at a given
    # daily average temp, i.e., the height of the response function at X degrees C.
    betas.expanded$resp = betas.expanded$tas*(betas.expanded$temp) + 
        betas.expanded$tas2*(betas.expanded$temp^2) + 
        betas.expanded$tas3*(betas.expanded$temp^3) + 
        betas.expanded$tas4*(betas.expanded$temp^4)

    betas.expanded$resp_ref = betas.expanded$tas*(betas.expanded$analytic) + 
        betas.expanded$tas2*(betas.expanded$analytic^2) + 
        betas.expanded$tas3*(betas.expanded$analytic^3) + 
        betas.expanded$tas4*(betas.expanded$analytic^4)

    betas.expanded$betas = betas.expanded$resp - betas.expanded$resp_ref

    #calculate response (clim adapt)
    betas.expanded$resp_clim = betas.expanded$tas_clim*(betas.expanded$temp) + 
        betas.expanded$tas2_clim*(betas.expanded$temp^2) + 
        betas.expanded$tas3_clim*(betas.expanded$temp^3) + 
        betas.expanded$tas4_clim*(betas.expanded$temp^4)

    betas.expanded$resp_ref_clim = betas.expanded$tas_clim*(betas.expanded$analytic) + 
        betas.expanded$tas2_clim*(betas.expanded$analytic^2) + 
        betas.expanded$tas3_clim*(betas.expanded$analytic^3) + 
        betas.expanded$tas4_clim*(betas.expanded$analytic^4)

    betas.expanded$betas_clim = betas.expanded$resp_clim - betas.expanded$resp_ref_clim


    # Implementing adaptation constraint ('clipping') assumptions. See details in Carleton et al (2019). 
    # Note things are sequential. 

    # 1. Rising income cannot increase temp. sensitivity of mortality (goodmoney-clipping)

    # Compare climadapt and fulladapt response and take the lesser of the two.
    # Implemented with pmin() which iterates over two vectors taking the minimum of pairs.
    betas.expanded$clipped_gm_betas = pmin(betas.expanded$betas, betas.expanded$betas_clim) 

    #dummy indicating whether a given beta was good-money-clipped or not.
    betas.expanded$gm_clipping =ifelse(
        betas.expanded$clipped_gm_betas != betas.expanded$betas,
        1, 0)

    # 2. Rule out negative temperature sensitivity (Levels-clipping)


    # First, dummy variable indicating whether the good money clipped beta is negative
    betas.expanded$levels_clipping = ifelse(
        betas.expanded$clipped_gm_betas<0,
        TRUE, FALSE)
    # Second, actually resetting to 0 the good money clipped beta if it's negative. 
    betas.expanded$clipped_lvl_betas = ifelse(
        betas.expanded$clipped_gm_betas < 0, 
        0, betas.expanded$clipped_gm_betas)


    # 3. assumption of weakly increasing monotonicity (forcing response to be U-shaped, i.e, U-clipping). See appendix of Carleton et al (2019) for details. 

    # for temperatures hotter than the MMT, assign to a new U-clipped hot beta the level-clipped beta value (computed in (2)), otherwise, assign it zero. 
    betas.expanded$clipped_u_betas = ifelse(
        betas.expanded$temp >= betas.expanded$analytic, 
        betas.expanded$clipped_lvl_betas, 0) 

    # for temperatures colder than the MMT, assign to a new U-clipped cold beta the level-clipped beta value (computed in (2)), otherwise, assign it zero. 
    betas.expanded$clipped_u_betas_cold = ifelse(
        betas.expanded$temp < betas.expanded$analytic, 
        betas.expanded$clipped_lvl_betas, 0) 

    # finally compute the all assumptions beta. In practice it just means enforcing a parabola with positive values. Code is cryptic, so explanations : 
    # pick the betas for each region and year
    # compute the cumulative maximum of the cold clipped betas (they start at 0 by definition from above, so they will be at least 0)
    # compute the cumulative maximum of the hot side clipped betas (idem)
    # cumulative maximum is an implementation of the weak monotonicity ('ever increasing or constant sensitivity') left and right of MMT. 

    betas.expanded = betas.expanded %>% 
        dplyr::group_by(region, year) %>% 
        dplyr::arrange(-temp, .by_group=T) %>%
        dplyr::mutate(clipped_u2_betas_cold = cummax(clipped_u_betas_cold)) %>%
        dplyr::arrange(temp, .by_group=T) %>%
        dplyr::mutate(clipped_u2_betas = cummax(clipped_u_betas),
            betas_all_clip = clipped_u2_betas + clipped_u2_betas_cold) %>% # can simply take the sum because one is always zero and the other not. 
        ungroup()

    betas.expanded$u_clipping = ifelse(
        betas.expanded$clipped_u_betas != betas.expanded$betas_all_clip,
        TRUE, FALSE)

    betas.expanded$clipped = ifelse(
        betas.expanded$u_clipping | betas.expanded$levels_clipping,
        1, 0)
    
    # Repeat beta calculation process for incadapt if it's needed.
    if (inc_adapt) {


        betas.expanded$resp_inc = betas.expanded$tas_inc*(betas.expanded$temp) + 
            betas.expanded$tas2_inc*(betas.expanded$temp^2) + 
            betas.expanded$tas3_inc*(betas.expanded$temp^3) + 
            betas.expanded$tas4_inc*(betas.expanded$temp^4)

        betas.expanded$resp_ref_inc = betas.expanded$tas_inc*(betas.expanded$analytic) + 
            betas.expanded$tas2_inc*(betas.expanded$analytic^2) + 
            betas.expanded$tas3_inc*(betas.expanded$analytic^3) + 
            betas.expanded$tas4_inc*(betas.expanded$analytic^4)

        betas.expanded$betas_inc = betas.expanded$resp_inc - betas.expanded$resp_ref_inc


        # Rising income cannot increase temp. sensitivity of mortality (goodmoney-clipping)
        betas.expanded$clipped_gm_betas_inc = pmin(
            betas.expanded$betas_inc, betas.expanded$betas_clim) 
        betas.expanded$gm_clipping_inc =ifelse(
            betas.expanded$clipped_gm_betas_inc != betas.expanded$betas_inc,
            1, 0) 
      
        # No negative temp. sensitivity (Levels-clipping)
        betas.expanded$levels_clipping_inc = ifelse(
            betas.expanded$clipped_gm_betas_inc<0,
            1, 0)

        betas.expanded$clipped_lvl_betas_inc = ifelse(
            betas.expanded$clipped_gm_betas_inc < 0,
            0, betas.expanded$clipped_gm_betas_inc)
      
        # Weak increasing monotonicity (U-clipping)
        betas.expanded$clipped_u_betas_inc = ifelse(
            betas.expanded$temp >= betas.expanded$analytic, 
            betas.expanded$clipped_lvl_betas_inc, 0) 

        betas.expanded$clipped_u_betas_inc_cold = ifelse(
            betas.expanded$temp < betas.expanded$analytic, 
            betas.expanded$clipped_lvl_betas_inc, 0) 

        betas.expanded = betas.expanded %>% 
            dplyr::group_by(region, year) %>% 
            dplyr::arrange(-temp, .by_group=T) %>%
            dplyr::mutate(clipped_u2_betas_inc_cold = cummax(clipped_u_betas_inc_cold)) %>%
            dplyr::arrange(temp, .by_group=T) %>%
            dplyr::mutate(clipped_u2_betas_inc = cummax(clipped_u_betas_inc),
                betas_all_clip_inc = clipped_u2_betas_inc + clipped_u2_betas_inc_cold) %>%
            ungroup()

        betas.expanded$u_clipping_inc = ifelse(
            betas.expanded$clipped_u_betas_inc != betas.expanded$betas_all_clip_inc,
            1, 0)
    }
    return(betas.expanded)
}

#' Plots maps providing that spatial distribution of the temperature sensitivity of
#' mortality at a particular temperature value and year. In our analysis we call
#' these objects "betas", though they represent the height of the response function
#' at a given temperature value. (Figure 5)
#' 
#' Inputs
#' ------
#' This function requires an age group as well as any inputs to `calculate.beta`,
#' though note that most important parameters for reproducing paper plots are
#' defaults in both functions.
#' 
#' Outputs
#' -------
#' Exports "beta" maps to `output_dir`.
#' 
#' Dependencies
#' -------------
#' calculate.beta
#' 
#' Parameters/Return
#' -----------------
#' @param age agegroup ('young', 'older', 'oldest')
#' @param limits_val list containing bounds for plotted maps by age group.
#' @param yearlist years in which generate betas.
#' @param grey_uclip T/F for diagnostic in which uclipped regions are greyed
#' out.
#' @param insample T/F for greying regions outside the estimation sample.
#' @param inputwd Directory containing input single directory
#' @param output_dir Output directory
#' @param shp_master Shapefile, will load default if NULL.
#' @param betas.plot Betas dataframe (output from calculate.betas). Loads by
#' default if NULL, but saves on compute time if running a bunch of output.
#' @param summ_temp Temperature at which to calculate beta.
#' @param grayscale black and white plor for print version of mortality paper
#' @return Exports maps, returns NULL.
plot.beta.maps = function(
    age,
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    limits_val=list(
        young = 20,
        older = 20,
        oldest = 20 ),
    yearlist=c(2015, 2050, 2100), 
    grey_uclip=FALSE, 
    insample=FALSE,
    inputwd=BETA_INPUT_DEFAULT,
    output_dir=BETA_OUTPUT_DEFAULT,
    shp_master=NULL,
    betas.plot=NULL,
    summ_temp=35,
    grayscale=FALSE,
    override_MMTdir=FALSE,
    ...) {

    # create output directory
    dir.create(output_dir, showWarnings = FALSE)    

    cov_path = glue('{inputwd}/{rcp}/CCSM4/{iam}/{ssp}')

    if (is.null(betas.plot))
        betas.plot = calculate.beta(age, yearlist=yearlist,
            summ_temp=summ_temp, cov_path=cov_path, override_MMTdir=override_MMTdir,...)
    message("Betas calculated. Plotting maps...")

    # Load shapefile.
    if (is.null(shp_master))
        shp_master = load.map()

    #join impact data to shapefile 
    shp = left_join(shp_master, betas.plot, by=c('id' = 'region'))

    for (yr in yearlist){
        
        #subset data to year
        shp_plot = subset(shp, year==yr)

        #set up plotting parameters. 
        titlename = paste(yr,": Age", age)
        
        
        #recode values that exceed limits_val to limits_val
        shp_plot$betas_all_clip = ifelse(shp_plot$betas_all_clip > limits_val[[age]], 
            limits_val[[age]], 
            shp_plot$betas_all_clip)
        
        if(!isFALSE(override_MMTdir)){
            suffix = paste0('_', override_MMTdir,'reftemp')
        } else {
            suffix = ''
        }

        filename = glue("{output_dir}/beta_map_{age}_{ssp}_{rcp}_{iam}_{yr}{suffix}")
        
        if (grey_uclip) {
            
            #recode negative betas to NA
            shp_plot$betas_all_clip = ifelse(
                shp_plot$u_clipping == 1,
                NA, shp_plot$betas_all_clip)
            
            # Update filename.
            filename = glue("{output_dir}/beta_map_{age}_{ssp}_{rcp}_{iam}_{yr}_grey-uclip")
        }
        
        if (insample) {

            insamplelist = c("BRA", "CHL", "CHN", "FRA", "JPN", "MEX", "USA",
                "AUT", "BEL", "BGR", "CHE", "CYP", "CZE", "DEU", "DNK", "EST", 
                "GRC", "ESP", "FIN", "HRV", "HUN", "IRL", "ISL", "ITA", "LIE", 
                "LTU", "LUX", "LVA", "MNE", "MKD", "MLT", "NLD", "NOR", "POL", 
                "PRT", "ROU", "SWE", "SVK", "TUR", "GBR")
            
            #recode outofsample IRs to NA
            shp_plot$betas_all_clip = ifelse(!(substr(shp_plot$id, 1,3) %in% insamplelist), 
                NA, shp_plot$betas_all_clip)

            na.df = dplyr::filter(shp_plot, is.na(betas_all_clip))
            
            # Update filename.
            filename = paste0(filename,"_insample")
        }
        
        # Set variables for plotting.
        titleunit = glue("Damages at {summ_temp}C relative to reference temperature (deaths per 100,000)")
        breaks_labels_val = round(seq(0, limits_val[[age]], limits_val[[age]]/4), digits = 5)
        minval = min(shp_plot$betas_all_clip, na.rm=T) 
        maxval = max(shp_plot$betas_all_clip, na.rm=T)
        caption_val = glue("Min in {yr}: {minval}    Max in {yr}:  {maxval}    White: Out of Sample")
        if(grey_uclip) 
            caption_val = glue("Min in {yr}: {minval}    Max in {yr}:  {maxval}    Grey: u-clipped")
        
        message(paste("Plotting age", age, yr, sep=" "))

        crs_str = "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"
        lakeslist = list(
            "CA-", "USA.23.1273","USA.14.642","USA.50.3082","USA.50.3083",
            "USA.23.1275","USA.15.740", "USA.24.1355", "USA.33.1855", "USA.36.2089", 
            "USA.23.1272", "UGA.32.80.484","UGA.32.80.484.2761", "TZA.13.59.1169", 
            "TZA.5.26.564", "TZA.17.86.1759", "ATA")
        lakes10 = ne_download(scale = 110, type = 'lakes', category = 'physical') %>%
            spTransform(CRS(crs_str)) %>%
            fortify(lakes10, region = "name")

        world10 = ne_download(scale = 110, type = 'coastline', category = 'physical') %>%
            spTransform(CRS(crs_str)) %>%
            fortify(world10, region = "name")

        
        if (grayscale){
            color.values = rev(gray.colors(15, start=0.01, end=0.9))
            filename = paste0(filename,"_grayscale")

        } else {
            color.values = rev(c("#c92116", "#ec603f", "#fd9b64", "#fdc370", "#fee69b","#fef7d1", "#f0f7d9"))
        }
        

        if (grayscale){

            p = ggplot(data = shp_plot, aes(x=long, y=lat)) +
                geom_polygon(aes(group=group), color = "black", size=.25) + 
                geom_polygon(aes(group=group, fill=betas_all_clip)) +
                geom_polygon(data = lakes10, aes(x=long, y=lat, group=group), fill="white") +
                coord_equal() +
                theme_bw() +     
                theme(
                    plot.title = element_text(hjust=0.5, size = 10), 
                    plot.caption = element_text(hjust=0.5, size = 7), 
                    legend.title = element_text(hjust=0.5, size = 10), 
                    legend.position = "bottom",
                    legend.text = element_text(size = 7),
                    axis.title= element_blank(), 
                    axis.text = element_blank(),
                    axis.ticks = element_blank(),
                    panel.grid = element_blank(),
                    panel.border = element_blank()) +   
                labs(
                    title = paste0("Mortality Betas at 35C ",titlename), 
                    caption = caption_val) + 
                scale_fill_gradientn(
                    colors = color.values,
                    values = rescale(c(0, seq(0.000000001, limits_val[[age]], limits_val[[age]]/4))),
                    na.value = "white",
                    limits = c(0, limits_val[[age]]),
                    breaks = breaks_labels_val, 
                    labels = breaks_labels_val,
                    guide = guide_colorbar(
                        title = titleunit,
                        direction = "horizontal",
                        barheight = unit(4, units = "mm"),
                        barwidth = unit(180, units = "mm"),
                        draw.ulim = F,
                        title.position = 'top',
                        title.hjust = 0.5,
                        label.hjust = 0.5))    
            file_out = paste0(filename, ".png")


            if (insample){
                p = p + geom_polygon(data = na.df, aes(group=group), fill = "white")
            }

            ggsave(p, file = file_out, width = 10, height = 6)
            message(glue("Saved {file_out}"))
        
        } else {

            p = ggplot(data = shp_plot, aes(x=long, y=lat)) +
                geom_polygon(aes(group=group, fill=betas_all_clip), color = "white", size=.01) +
                geom_polygon(data = lakes10, aes(x=long, y=lat, group=group), fill="white") +
                coord_equal() +
                theme_bw() +     
                theme(
                    plot.title = element_text(hjust=0.5, size = 10), 
                    plot.caption = element_text(hjust=0.5, size = 7), 
                    legend.title = element_text(hjust=0.5, size = 10), 
                    legend.position = "bottom",
                    legend.text = element_text(size = 7),
                    axis.title= element_blank(), 
                    axis.text = element_blank(),
                    axis.ticks = element_blank(),
                    panel.grid = element_blank(),
                    panel.border = element_blank()) +   
                labs(
                    title = paste0("Mortality Betas at 35C ",titlename), 
                    caption = caption_val) + 
                scale_fill_gradientn(
                    colors = rev(c("#c92116", "#ec603f", "#fd9b64",
                        "#fdc370", "#fee69b","#fef7d1", "#f0f7d9")),
                    values = rescale(c(0, seq(0.000000001, limits_val[[age]], limits_val[[age]]/4))),
                    na.value = "grey80",
                    limits = c(0, limits_val[[age]]),
                    breaks = breaks_labels_val, 
                    labels = breaks_labels_val,
                    guide = guide_colorbar(
                        title = titleunit,
                        direction = "horizontal",
                        barheight = unit(4, units = "mm"),
                        barwidth = unit(180, units = "mm"),
                        draw.ulim = F,
                        title.position = 'top',
                        title.hjust = 0.5,
                        label.hjust = 0.5))
            file_out = paste0(filename, ".png")
            ggsave(p, file = file_out, width = 10, height = 6)
            message(glue("Saved {file_out}"))
        }
    }
}

#' Plots unique response functions for all 25k impact regions, with alpha
#' determined by that impact region's temperature distribution. Often referred to
#' as "Spaghetti plots". (Figure 5)
#' 
#' Inputs
#' ------
#' This function requires an age group as well as any inputs to `calculate.beta`,
#' though note that most important parameters for reproducing paper plots are
#' defaults in both functions.
#' 
#' Outputs
#' -------
#' Exports "spaghetti" plots to `output_dir`.
#' 
#' Dependencies
#' -------------
#' calculate.beta
#' 
#' Parameters/Return
#' -----------------
#' @param age age agegroup ('young', 'older', 'oldest')
#' @param insample T/F for greying regions outside the estimation sample.
#' @param y.limits vector providing limits of the x-axis
#' @param x.limits vector providing limits of the x-axis
#' @param y.label y-axis label
#' @param tempdir location of temperature data used to weight alpha.
#' @param inputwd Directory containing input single directory
#' @param output_dir Output directory
#' @param betas.plot dataframe (output from calculate.betas). Loads by
#' default if NULL, but saves on compute time if running a bunch of output.
#' @param ftype file type for output (png or pdf, usually)
#' @return Exports plots, returns NULL.
plot.spaghetti = function(
    age='oldest',
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    insample=FALSE, 
    y.limits=c(0,15), 
    x.limits=c(-15,40),
    y.label="Change in death rate relative to reference temperature", 
    tempdir=TEMP_DEFAULT,
    inputwd=BETA_INPUT_DEFAULT,
    output_dir=RF_OUTPUT_DEFAULT,
    betas.plot=NULL,
    ftype='pdf',
    override_MMTdir=FALSE,
    ... ) {


    message('starting spaghetti wrapper...')

    # create output directory
    dir.create(output_dir, showWarnings = FALSE) 

    cov_path = glue('{inputwd}/{rcp}/CCSM4/{iam}/{ssp}')

    message('calculating betas...')
    if (is.null(betas.plot))
        betas = calculate.beta(age, baseline=2010,
            yearlist=c(2010), summ_temp=NULL, cov_path=cov_path, override_MMTdir=override_MMTdir,...)
    
    df = betas %>%
        dplyr::select(hierid=region, betas_all_clip, temp) %>%
        data.frame()

    region = "Global"
    ggregion = region
    if (insample) {

        message('keeping IRs that are part of the estimation sample countries...')

        insamplelist = c("BRA", "CHL", "CHN", "FRA", "JPN", "MEX", "USA",
            "AUT", "BEL", "BGR", "CHE", "CYP", "CZE", "DEU", "DNK", "EST", 
            "GRC", "ESP", "FIN", "HRV", "HUN", "IRL", "ISL", "ITA", "LIE", 
            "LTU", "LUX", "LVA", "MNE", "MKD", "MLT", "NLD", "NOR", "POL", 
            "PRT", "ROU", "SWE", "SVK", "TUR", "GBR")

        #subset data to insamplelist IRs
        df <- as.data.table(df) #speedup. why does this code love data frames?
        df <- df[substr(hierid, 1, 3) %in% insamplelist,]
        #vector of regions for the plotting code
        ggregion <- unique(df[, hierid])
        #subset name for the plot
        region="In-sample"
        df <- as.data.frame(df) #back to data frame

    }

    message('plotting spaghetti...')

    p = ggspaghetti(
        df=df,
        region=ggregion,
        variable="betas_all_clip", 
        temp.variable="temp", 
        key="hierid",
        y.limits=y.limits,
        x.limits=x.limits,
        y.label=y.label )

    message('saving...')

    if(!isFALSE(override_MMTdir)){
        suffix = paste0('_', override_MMTdir,'reftemp')
    } else {
        suffix = ''
    }

    myfile = glue("{output_dir}/{region}_spaghetti_response_{age}_{ssp}_{rcp}_{iam}{suffix}")
    
    ggsave(p, filename=glue("{myfile}.{ftype}"),
        width = 7, height = 7)  

    return(p)
}


#' Plots maps providing the spatial distribution of the _change_ in the temperature
#' sensitivity of mortality at a given temperature across two future years. Here
#' we call these delta maps, but they're really delta of beta maps by the
#' definition of beta above.
#' 
#' Inputs
#' ------
#' This function requires an age group as well as any inputs to `calculate.beta`,
#' though note that most important parameters for reproducing paper plots are
#' defaults in both functions.
#' 
#' Outputs
#' -------
#' Exports "delta" maps to `output_dir`.
#' 
#' Dependencies
#' -------------
#' calculate.beta
#' 
#' Parameters/Return
#' -----------------
#' @param  age agegroup ('young', 'older', 'oldest')
#' @param limits_val list containing bounds for plotted maps by age group.
#' @param baseline baseline year for counterfactual approximation (2015)
#' @param future Future year from which to subtract baseline.
#' @param inputwd Directory containing input single directory
#' @param output_dir Output directory
#' @param shp_master Shapefile, will load default if NULL.
#' @param betas.plot Betas dataframe (output from calculate.betas). Loads by
#' default if NULL, but saves on compute time if running a bunch of output.
#' @param summ_temp Temperature at which to calculate beta.
#' @return Exports maps, returns NULL.
plot.delta.maps = function(
    age,
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    limits_val=list(
        young = -6,
        older = -2,
        oldest = -20 ),
    baseline=2015,
    future=2100,
    inputwd=BETA_INPUT_DEFAULT,
    output_dir=DELTA_OUTPUT_DEFAULT,
    shp_master=NULL,
    betas.plot=NULL,
    summ_temp=35,
    override_MMTdir=FALSE,
    ...) {

    cov_path = glue('{inputwd}/{rcp}/CCSM4/{iam}/{ssp}')

    # create output directory
    dir.create(output_dir, showWarnings = FALSE) 

    if (is.null(betas.plot))    
        betas.plot = calculate.beta(age,
            baseline=baseline,
            yearlist=list(baseline, future), 
            summ_temp=summ_temp,
            cov_path=cov_path, 
            override_MMTdir=override_MMTdir,
            ...)
    message("Betas calculated. Plotting maps...")

    #reshape from long to wide
    betas.reshape = dplyr::select(betas.plot, region, year, betas_all_clip) %>% 
      tidyr::spread(year, betas_all_clip)
    names(betas.reshape) = c("region", "baseline", "future")
    
    #calculate difference
    betas.reshape$diff = betas.reshape$future -  betas.reshape$baseline
    
    # Load shapefile.
    if (is.null(shp_master))
        shp_master = load.map()

    #join impact data to shapefile 
    shp_plot = left_join(shp_master, betas.reshape, by = c('id' = 'region'))
  
    #set up plotting parameters
    titlename = paste(future,": Age", age)
    
    #recode values that exceed limits_val to limits_val
    shp_plot$diff = ifelse(
        shp_plot$diff < limits_val[[age]],
        limits_val[[age]], shp_plot$diff)
    
    filename = glue("{output_dir}/delta_map_{age}_{ssp}_{rcp}_{iam}_{future}_sensitivity.png")
    
    # Set variables for plotting.
    titleunit = glue("Change in marginal damages of a day at {summ_temp}C  (deaths per 100,000)")
    breaks_labels_val = round(seq(limits_val[[age]], 0, 
            abs(limits_val[[age]])/5), digits = 5)
    minval = min(shp_plot$diff, na.rm=T)
    maxval = max(shp_plot$diff, na.rm=T)
    caption_val = glue("Min: {minval}    Max:  {maxval}")
    
    print(paste("plotting age", age, future, sep=" "))

    crs_str = "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"
    lakeslist = list(
        "CA-", "USA.23.1273","USA.14.642","USA.50.3082","USA.50.3083",
        "USA.23.1275","USA.15.740", "USA.24.1355", "USA.33.1855", "USA.36.2089", 
        "USA.23.1272", "UGA.32.80.484","UGA.32.80.484.2761", "TZA.13.59.1169", 
        "TZA.5.26.564", "TZA.17.86.1759", "ATA")
    lakes10 = ne_download(scale = 110, type = 'lakes', category = 'physical') %>%
        spTransform(CRS(crs_str)) %>%
        fortify(lakes10, region = "name")
    
    #plot
    p = ggplot(data = shp_plot, aes(x=long, y=lat)) +
        geom_polygon(aes(group=group, fill=diff)) + # IR polygons
        geom_polygon(data = lakes10, aes(x=long, y=lat, group=group), fill="white") +
        coord_equal() +
        theme_bw() +     
        theme(
            plot.title = element_text(hjust=0.5, size = 10), 
            plot.caption = element_text(hjust=0.5, size = 7), 
            legend.title = element_text(hjust=0.5, size = 10), 
            legend.position = "bottom",
            legend.text = element_text(size = 7),
            axis.title= element_blank(), 
            axis.text = element_blank(),
            axis.ticks = element_blank(),
            panel.grid = element_blank(),
            panel.border = element_blank()) +   
        labs(
            title = paste0("Sensitivity to high temperature ", future, "-", baseline), 
            caption = caption_val) + 
        scale_fill_gradientn(
            colors = rev(c("#ffffbe", "#fffff7", "#fffff1",
                "#D9F0A3", "#78C679", "#238443", "#006837")),
            values = rescale(c(-20, -18, -16, -14, -12, -8, -4, 
                -2, -1, -0.1, -0.000000001, 0, 0.000000001, 0.5, 2.5)), 
            na.value = "grey80",
            limits = c(limits_val[[age]], 3),
            breaks = breaks_labels_val, 
            labels = breaks_labels_val,
            guide = guide_colorbar(
                title = titleunit,
                direction = "horizontal",
                barheight = unit(4, units = "mm"),
                barwidth = unit(180, units = "mm"),
                draw.ulim = F,
                title.position = 'top',
                title.hjust = 0.5,
                label.hjust = 0.5))
    ggsave(p, file = filename, width = 10, height = 6)
}
