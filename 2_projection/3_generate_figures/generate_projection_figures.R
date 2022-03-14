# Purpose: Master R script for reproducing post-projection figures in Carleton
# et al. (2022).
# 
# This script reproduces Figures 2, 3, 4, 5, 6 and Appendix Figures B1, D5, E2,
# F1, F2, F3, F4, F5, F6, and F7. It's organized into six sections:
# 
# 1.  Data Coverage (Figures 2, B1)
# 2.  Temperature sensitivity of mortality maps and response function plots. 
#     (Figures 3, D5 & E2) 
# 3.  End of century mortality risk of climate change maps and density plots.
#     (Figures 4, F1 & F6)
# 4.  Time series of projected mortality risk of climate change.
#     (Figures 5, F2, F3, F4, F5, F7, F9, F10 & F11)
# 5.  2099 impacts of climate change by decile of today's income and climate.
#     (Figure 6)
# 6.  The impact of climate change in 2100 compared to contemporary leading
#     causes of death. (Figure 9)
# 
# The toggles below control which portions of the analysis are run.
# The Appendix toggle interacts with each section

# TOGGLES
Part1 = TRUE # Data coverage
Part2 = TRUE # Temp. sensitivity maps and response Functions
Part3 = TRUE # Maps and histograms
Part4 = TRUE # Time series
Part5 = TRUE # Decile plot
Part6 = TRUE # Bar Chart
Appendix = TRUE # Parts 1-4 have Appendix figures

# Paper default: rcp85, low, SSP3

# RCP scenario ('rcp85', 'rcp45')
rcp='rcp85' 

# Economic modeling scenario:
#  'low': "IIASA GDP"
#  'high': "OECD Econ Growth"
iam='low'

# SSP ('SSP2', 'SSP3', 'SSP4')
ssp='SSP3'

# Initialize paths, packages, and user functions.
REPO <- Sys.getenv(c("REPO"))
DB <- Sys.getenv(c("DB"))
OUTPUT <- Sys.getenv(c("OUTPUT"))

source(paste0(REPO, "/carleton_mortality_2022/2_projection/1_utils/load_utils.R"))


# Part 1: Data Coverage.
# 
# This section generates the following figures in Carleton et al. (2022):
# 
#   - Covariate coverage (Figure 2): Joint coverage of income and long-run
#    average temperature for estimating and full samples.
#       - Dependencies: `2_projection/1_utils/covariate_coverage.R`
#       - Output: `output/2_projection/figures/ `
#           - `covariate_coverage_climtas_lgdppc_*_*.pdf` where * indicates
#           (insample vs global) and (2010 vs 2100).
# 
#   - In-sample coverage map (Figure B1): (1) Spatial distribution and
#   resolution and (2) temporal coverage of mortality statistics from all
#   countries used to generate regression estimates of the temperature-mortality
#   relationship.
#       - Dependencies: `2_projection/1_utils/insample_data_coverage.R`
#       - Output: `output/2_projection/figures/Figure_B1_data_coverage`
#           - `country_spacecoverage_map.png` map of spatial
#           distribution/resolution of mortality data.
#           - `country_timecoverage_lineplot.pdf` line plot showing temporal
#           coverage of mortality data
# 

if (Part1) {

    # Covariate coverage - Figure 2
    blob_plot(rcp=rcp, iam=iam, ssp=ssp)

    if (Appendix) {

        # In-sample coverage map - Figure B1
        insample_data_coverage()
    }

}


# Part 2: Temperature sensitivity of mortality maps and response function plots.
# 
# This section generates the following plots in Section 7 of Carleton et al. (2022):
# 
#   - "Beta Maps" (Figure 3, Panels C & D, Figure D5, Panels C, D, G & H):
#   Maps showing the mortality sensitivity of a 35C day for the 64+ age group, both for
#   in-sample regions and for the fully  extrapolated world. 
#       - Dependencies: `2_projection/1_utils/calculate_betas.R`
#       - Output: `output/figures/Figure_3_D5_beta_maps`
#           - `beta_map_*_*.png`, where * indicates (young, oldest) and (global,
#           insample)
# 
#   - "Response function plots" (or "spaghetti plots") (Figure 3, Panels A & B):
#   Impact region-level response functions and the un-weighted
#   average across regions both for in-sample regions and for the fully
#   extrapolated world.
#       - Dependencies: `2_projection/1_utils/calculate_betas.R`
#       - Output: `output/figures/Figure_3_D5_spaghettis`
#           - `*_spaghetti_response_*.pdf`, where * indicates (global, insample)
#           and (young, oldest).
# 
#   - "Delta Maps" (Figure E2): Maps showing the change in the mortality
#    sensitivity to a 35C day for the oldest age group (>64) between 2015 and
#    2050 or 2100.
#       - Dependencies: `2_projection/1_utils/calculate_betas.R`
#       - Output: `output/figures/Figure_E2_delta_maps`
#           - `delta_map_*_*_sensitivity.png`, where * indicates (young, oldest)
#           and (2050, 2100)
#           

if (Part2) {

    # <5 and 65+ age groups appear in Fig. 5
    agelist = c('young','older','oldest')

    # Pre-load map
    if (!exists('shp_master'))
        shp_master = load.saved.map()

    # "Beta Maps" - Figures 3, D5 RHS panels 
    for (age in agelist){ # doing a simple for loop because multiprocessing triggers errors in map loading
        for (insample in c(TRUE,FALSE)){

            out <- wrap_mapply(
                age=age,
                insample=insample,
                FUN=plot.beta.maps,
                MoreArgs=list(
                    shp_master=shp_master,
                    yearlist=c(2015),
                    rcp=rcp, iam=iam, ssp=ssp),
                mc.cores=1)

        }
    }

 
    # "Response function plots" - Figures 3, D5, LHS panels

    out <- wrap_mapply(
        age=agelist,
        insample=c(TRUE, FALSE),
        FUN=plot.spaghetti,
        MoreArgs=list(rcp=rcp, iam=iam, ssp=ssp, ftype='png'),
        mc.cores=4)

    # "Delta Maps" - Figure E2, Panels A and B
    out <- wrap_mapply(
        rcp=c('rcp45', 'rcp85'),
        future=c(2050, 2100),
        age='oldest',
        FUN=plot.delta.maps,
        MoreArgs=list(shp_master=shp_master,
            iam=iam, ssp=ssp),
        mc.cores=4)


}


# Part 3: End of century mortality risk of climate change maps and density
# plots.
# 
# This section generates the following plots in Carleton et al. (2022):
# 
#   - Impact map (Figure 4, F1, F6): Impact-region level map showing the impacts of
#   climate change accounting for income and climate adaptation plus the costs
#   of adapatation in 2100. Impacts represent the mean across Monte Carlo
#   simulations conducted on 33 climate models. 
#       - Dependencies - `2_projection/1_utils/impact_map.R`
#       - Output - `output/figures/Figure_4_impact_maps`
#       - Output - `output/figures/Figure_F1_impact_maps`
#       - Output - `output/figures/Figure_F6_impact_maps`
#           - `impact-map_fulladaptcosts_*rcp*-*SSP*-*iam*-*age*-*year*-*units*.png`
# 
#   - IR density plots (Figure 4): Full distribution of estimated impacts across
#   GCMs and Monte Carlo draws. Solid lines indiciate mean estimate with shading
#   at one, two, and three standard deviations from the mean.
#       - Dependencies - `2_projection/1_utils/density_plots.R`
#       - Output - `output/figures/Figure_4_density_plots`
#           - `density_fulladaptcosts_SSP3_85_*_2099.pdf` where * indicates the
#           unique region code for the 7 cities in the figure.
# 

if (Part3) {

    
    # Impact map without accounting for adaptation costs (Figure 4)
    mortality_impacts_map(rcp='rcp85', iam='low', ssp='SSP3', scn='fulladapt',
        output_dir=glue('{OUTPUT}/figures/Figure_4_impact_maps'))

    # Regions - Beijing, Accra, Chicago, Delhi, Sao Paulo, Sydney, Oslo
    regions = list("CHN.2.18.78","GHA.5.70","USA.14.608",
     "IND.10.121.371","BRA.25.5212.R929786f5729d8f1a", "AUS.4.275", "NOR.12.288")

    # IR density plots without accounting for adaptation costs (Figure 4)
    impacts_density_plot(regions=regions, rcp='rcp85', iam='low', ssp='SSP3', scn='fulladapt',
        output_dir=glue('{OUTPUT}/figures/Figure_4_density_plots'))


    if (Appendix) {

        # Impact maps for 4 adaptation scenarios in order of panels A-D (Figure F1)
        for (scn in c('noadapt', 'incadapt', 'fulladapt', 'fulladaptcosts')) {
            mortality_impacts_map(rcp='rcp85', iam='low', ssp='SSP3', scn=scn, 
                output_dir=glue('{OUTPUT}/figures/Figure_F1_impact_maps'))
        }

        # Impact maps for both RCPs emissions pathways for panels A & B (Figure F6)
        for (rcp in c('rcp45', 'rcp85')) {
            mortality_impacts_map(rcp=rcp, iam='low', ssp='SSP3', scn='fulladapt', 
                output_dir=glue('{OUTPUT}/figures/Figure_F6_impact_maps'))
        }
    }
} 


# Part 4: Time series of projected mortality risk of climate change.
# 
# This section generates the following plots in Carleton et al. (2022):
# 
#   - Time series comparison of adaptation scenarios (Figure 5 Panel A): Includes
#   mortality impacts without adaptation, with only the benefits of income growth,
#   with the benefits of income growth and adaptation, and the full mortality
#   effects accounting for full adaptation and the costs incurred to achieve
#   adaptation.
#       - Dependencies - `2_projection/1_utils/timeseries.R`
#       - Output - `output/figures/Figure_5_timeseries`
#           - `timeseries_adaptation_rcp85-SSP3-low-combined.pdf`
# 
#   - Time series with uncertainty and comparison of RCPs (Figure 8 Panel B):
#   Includes the 10th-90th percentile range of the Monte Carlo simulations for the
#   full mortality risk of climate changes, as well as the mean and interquartile
#   range. Boxplots show the distribution of impacts at end of century for both
#   RCPs.
#       - Dependencies - `2_projection/1_utils/timeseries.R`
#       - Output - `output/figures/Figure_5_timeseries`
#           - `timeseries_rcp-uncertainty_SSP3-low-combined.pdf`

if (Part4) {

    # Time series comparison of adaptation scenarios without accounting for adaptation costs (Figure 5 Panel A)
    timeseries_compare_adaptation(rcp='rcp85', iam='low', ssp='SSP3', with_costs=FALSE,
        output_dir=glue('{OUTPUT}/figures/Figure_5_timeseries'))

    # Time series with uncertainty and comparison of RCPs without accounting for adaptation costs (Figure 5 Panel B)
    timeseries_compare_rcp(rcp='rcp85', iam='low', ssp='SSP3', with_costs=FALSE,
        output_dir=glue('{OUTPUT}/figures/Figure_5_timeseries'))

    # To account for adaptation costs, pass with_costs=TRUE. 


    if (Appendix) {

        # Figure F2: Figure 5 but with adaptation costs
        # Time series comparison of adaptation scenarios without accounting for adaptation costs (Figure F2 Panel A)
        #    - Dependencies - `2_projection/1_utils/timeseries.R`
        #    - Output - `output/figures/Figure_F2_timeseries`
        #      - `timeseries_adaptation_rcp85-SSP3-low-combined_withcosts.pdf`
        #  
        # TTime series with uncertainty and comparison of RCPs (Figure F2 Panel A)
        #    - Dependencies - `2_projection/1_utils/timeseries.R`
        #    - Output - `output/figures/Figure_F2_timeseries`
        #      - `timeseries_rcp-uncertainty_SSP3-low-combined_withcosts.pdf`  
        timeseries_compare_adaptation(rcp='rcp85', iam='low', ssp='SSP3', with_costs=TRUE,
            output_dir=glue('{OUTPUT}/figures/Figure_F2_timeseries'))

        timeseries_compare_rcp(rcp='rcp85', iam='low', ssp='SSP3', with_costs=TRUE,
            output_dir=glue('{OUTPUT}/figures/Figure_F2_timeseries'))


        # Figure F3: Time series comparing impacts without climate and income adaptation. 
        #   - Dependencies: `2_projection/1_utils/timeseries.R`
        #   - Output: `output/2_projection/figures/Figure_F3_timeseries`
        timeseries_compare_incadapt_noadapt(output_dir=glue('{OUTPUT}/figures/Figure_F3_timeseries'))        


        # Figure F4: Heterogeneity in climate change impacts on mortality by age group. 
        #   - Dependencies: `2_projection/1_utils/timeseries.R`
        #   - Output: `output/2_projection/figures/Figure_F4_timeseries`
        timeseries_compare_age_groups(output_dir=glue('{OUTPUT}/figures/Figure_F4_timeseries'))


        # Figure F5: The full mortality risk of climate change under different
        # scenarios of population growth, economic growth, and emissions.
        #   - Dependencies: `2_projection/1_utils/timeseries.R`
        #   - Output: `output/2_projection/figures/Figure_F5_timeseries`
        timeseries_compare_ssp_iam(output_dir=glue('{OUTPUT}/figures/Figure_F5_timeseries'))

        
        # Figure F7: Figure 5 but RCP45
        # Time series comparison of adaptation scenarios without accounting for adaptation costs (Figure F2 Panel A)
        #    - Dependencies - `2_projection/1_utils/timeseries.R`
        #    - Output - `output/figures/Figure_F2_timeseries`
        #      - `timeseries_adaptation_rcp85-SSP3-low-combined_withcosts.pdf`
        #  
        # TTime series with uncertainty and comparison of RCPs (Figure F2 Panel A)
        #    - Dependencies - `2_projection/1_utils/timeseries.R`
        #    - Output - `output/figures/Figure_F2_timeseries`
        #      - `timeseries_rcp-uncertainty_SSP3-low-combined_withcosts.pdf`  
        timeseries_compare_adaptation(rcp='rcp45', iam='low', ssp='SSP3', with_costs=FALSE,
            output_dir=glue('{OUTPUT}/figures/Figure_F7_timeseries'))

        timeseries_compare_rcp(rcp='rcp45', iam='low', ssp='SSP3', with_costs=FALSE,
            output_dir=glue('{OUTPUT}/figures/Figure_F7_timeseries'))

        
        # Figure F9: Robustness of impact projections to alternate functional forms
        # of temperature.
        #   - Dependencies: `2_projection/1_utils/timeseries.R`
        #   - Output: `output/figures/Figure_F9_timeseries`
        timeseries_compare_binnned(output_dir=glue('{OUTPUT}/figures/Figure_F9_timeseries'))   


        # Figure F10: Robustness of impact projections to various linear extrapolations.
        #   - Dependencies: `2_projection/1_utils/timeseries.R`
        #   - Output: `output/figures/Figure_F10_timeseries`
        timeseries_linear_extrapolation(output_dir=glue('{OUTPUT}/figures/Figure_F10_timeseries'))      


        # Figure F11: Robustness to models with different adaptation rates
        #   - Dependencies: `2_projection/1_utils/timeseries.R`
        #   - Output: `output/figures/Figure_F11_timeseries`
        for speed in c('normal', 'slow', 'fast15') {
            timeseries_flexadapt_rate(adaptrate=speed, output_dir=glue('{OUTPUT}/figures/Figure_F11_timeseries'))
        }
    }
}

# Part 5: Climate change impacts and adaptation costs are correlated  
# with present-day income and climate. (Figure 6)
#   - Dependencies: `2_projection/1_utils/new_mortality_deciles_new.R`
#   - Output: `output/figures/Figure_6_deciles`


if (Part5) {

    deciles_plot_new('loggdppc', output_dir=glue('{OUTPUT}/figures/Figure_6_deciles'))
    deciles_plot_new('climtas', output_dir=glue('{OUTPUT}/figures/Figure_6_deciles'))
}


# Part 6: The impact of climate change in 2100 compared to contemporary
# leading causes of death. 
# 
# This section generates the following plots in Carleton et al. (2022):
# 
#   - Bar chart providing impacts at terciles of the income and climate
#   distribution (Figure 9, Figure F8).
#       - Dependencies - `2_projection/1_utils/barchart.R`
#       - Output - `output/figures/Figure_9_barchart`
#           - `tercile_impacts_barchart_rcp85_SSP3_low.csv`
#       - Output - `output/figures/Figure_F8_barchart`
#           - `tercile_impacts_barchart_rcp45_SSP3_low.csv`
#
# NOTES:
#   - Average global mortality rates from leading causes of death are from WHO 
#     (2018): "Global Health Estimates 2016: Deaths by cause, age, sex, by country
#     and by region, 2000-2016."
#   - As this figure is heavily post-processed in Illustrator, we reproduce a
#     CSV containing the mortality results displayed rather than the plot itself.

if (Part6) {

    # The impact of climate change in 2100 compared to contemporary
    # leading causes of death (Figure 9)
    mortality_barchart(rcp='rcp85', iam='low', ssp='SSP3',
        output_dir==glue('{OUTPUT}/figures/Figure_9_barchart'))

    # Same chart but for RCP 45 (Figure F8)
    mortality_barchart(rcp='rcp85', iam='low', ssp='SSP3',
        output_dir==glue('{OUTPUT}/figures/Figure_F8_barchart'))
}
