# Purpose: Generates Figure II in Carleton et al. (2022), which compares
# in-sample vs. global income and climate distributions in 2015 and 2100.

BLOB_OUTPUT= glue("{OUTPUT}/2_projection/figures/Figure_2_covariate_coverage")
browser()
dir.create(BLOB_OUTPUT)

#' Generates heat plot showing in-sample coverage of covariates in 2015 and 2100 
#' (Figure II in Carleton et al. (2022)). 
#' 
#' Inputs
#' ------
#' SSP, IAM, RCP scenario used to get the appropriate covariates. Note this
#' requires single projection output for those specifications.
#' 
#' Outputs
#' -------
#' Exports heat plots to `outputwd`.
#' 
#' Dependencies
#' -------------
#' impacts:::get_mortality_covariates
#' 
#' Parameters/Return
#' -----------------
#' @param rcp RCP scenario (rcp45, rcp85)
#' @param iam Economic modelling scenario (low, high)
#' @param ssp SSP scenario (SSP2-4)
#' @param grayscale black and white alternative version for the print 
#' @param output_dir Output directory.
#' @return Exports plot, returns NULL.
blob_plot = function(
    rcp='rcp85',
    iam='low',
    ssp='SSP3',
    grayscale=FALSE,
    output_dir=BLOB_OUTPUT) {

    # Countries in sample.
    insample = c(
        "BRA","CHL","CHN","FRA","IND","JPN","MEX","USA",
        "AUT","BEL","BGR","CHE","CYP","CZE","DEU","GBR",
        "DNK","EST","GRC","ESP","FIN","FRA","HRV","HUN",
        "IRL","ISL","ITA","LIE","LTU","LUX","LVA","MNE",
        "MKD","MLT","NLD","NOR","POL","PRT","ROU","SWE",
        "SVN","SVK","TUR")

    # Load covariates.
    cov_path = glue('{DB}/2_projection/3_impacts/',
        'main_specification/raw/single/{rcp}/CCSM4/{iam}/{ssp}')

    covars = get_mortality_covariates(single_path=cov_path, year_list=c(2015, 2099)) %>%
        dplyr::mutate(
            year = ifelse(year==2099, 2100, year),
            iso = substr(region, 1, 3),
            grp = ifelse(iso %in% insample, 1, 0))

    # Divide up data.
    insample_2010 = dplyr::filter(covars, grp==1, year==2015)
    global_2010 = dplyr::filter(covars, year==2015)

    insample_2100 = dplyr::filter(covars, grp==1, year==2100)
    global_2100 = dplyr::filter(covars, year==2100)

    # Generate plots.

    if (grayscale){

        p = ggplot() +
            stat_bin_2d(data=global_2010, aes(x=climtas,y=loggdppc), colour="white", size=.2, geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            stat_bin_2d(data=insample_2010, aes(x=climtas,y=loggdppc), colour="black", size=1, geom = "tile",na.rm=TRUE, fill=NA) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_2015_{rcp}-{iam}-{ssp}_grayscale.pdf')) 

        p = ggplot() +
            stat_bin_2d(data=global_2100, aes(x=climtas,y=loggdppc), colour="white", size=.2, geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            stat_bin_2d(data=insample_2010, aes(x=climtas,y=loggdppc), colour="black", size=1, geom = "tile",na.rm=TRUE, fill=NA) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_2100_{rcp}-{iam}-{ssp}_grayscale.pdf')) 

    } else {

        p = ggplot() +
            stat_bin_2d(data=global_2010, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_world_2015_{rcp}-{iam}-{ssp}_new.pdf'))

        p = ggplot() +
            stat_bin_2d(data=insample_2010, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("orange","red"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_sample_2015_{rcp}-{iam}-{ssp}_new.pdf'))

        p = ggplot() +
            stat_bin_2d(data=global_2100, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("grey","black"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_world_2100_{rcp}-{iam}-{ssp}_new.pdf'))

        p = ggplot() +
            stat_bin_2d(data=insample_2100, aes(x=climtas,y=loggdppc), colour="white",geom = "tile",na.rm=TRUE) +
            scale_fill_gradientn(colours=c("orange","red"),name = "Frequency",na.value=NA, limits=c(0,1600)) +
            xlim(-30,40) + xlab("Annual average temperature") + 
            ylim(3,12) + ylab("log(GDP per capita)") +
            theme(panel.background = element_rect(fill = 'white', colour = 'grey'))
        ggsave(p, filename = glue('{output_dir}/covariate_coverage_climtas_lgdppc_sample_2100_{rcp}-{iam}-{ssp}_new.pdf'))
    }
}   
