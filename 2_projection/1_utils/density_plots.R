# Purpose: Generates density plots providing the full distribution of estimated
# mortality impacts across all Monte Carlo simulations.

DENSITY_DEFAULT_REGIONS = list("CHN.2.18.78","GHA.5.70","USA.14.608",
 "IND.10.121.371","BRA.25.5212.R929786f5729d8f1a", "AUS.4.275", "NOR.12.288")

DENSITY_OUTPUT = glue('{OUTPUT}/2_projection/figures/3b_density_plots')

impacts_density_plot = function(
    regions=DENSITY_DEFAULT_REGIONS,
    year_list=2099,
    scn='fulladaptcosts',
    ssp='SSP3',
    iam='low',
    rcp='rcp85',
    output_dir=DENSITY_OUTPUT,
    topcode.ub=1000,
    topcode.lb=-500,
    ylim=c(0, 0.008),
    xlim=c(-500, 1000),
    ...) {

    impacts_fin = get_mortality_impacts(
        regions=regions, 
        year_list=year_list,
        scn='fulladaptcosts',
        extract="valuescsv",
        ssp=ssp, iam=iam, rcp=rcp,
        ...)

    for (y in year_list) {
        
        for (ir in regions) {
            
            ir.df = dplyr::filter(impacts_fin, region==ir, year==y)        
         
             plot = ggkd(
                df.kd = ir.df, 
                topcode.ub = topcode.ub,
                topcode.lb = topcode.lb,
                ir.name = ir,
                x.label = "Change in deaths per 100,000 population", 
                kd.color = "#666666") 
            
            plot = plot + coord_cartesian(
                ylim=ylim,
                xlim=xlim)
            
            ggsave(plot, 
                file = glue("{output_dir}/density_{scn}_{ssp}_{iam}_{rcp}_{ir}_{y}.pdf"), 
                width = 12, height = 6)
            
        }
        
    }
}
                    
                    
 
