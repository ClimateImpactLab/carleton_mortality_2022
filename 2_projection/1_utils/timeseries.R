# Purpose: Produces time series of projected impacts.

TS_OUTPUT_DEFAULT = glue("{OUTPUT}/2_projection/figures/4_timeseries")

TS_APPENDIX_DEFAULT = glue("{OUTPUT}/2_projection/figures/appendix/timeseries")

multi_timeseries = function(
    ...,
    FUN,
    plotvar,
    FunArgs=NULL,
    output_dir=TS_OUTPUT_DEFAULT,
    header='multi_timeseries', 
    suffix='',
    PlotArgs=list(),
    ftype='png') {

    message('Loading data')
    if (length(plotvar) == 1) {
        wrap = function(...) 
            (FUN(...)[c('year', plotvar)])

        PlotArgs[['df.list']] = wrap_mapply(..., FUN=wrap, MoreArgs=FunArgs)
    } else {

        df.list = wrap_mapply(..., FUN=FUN, MoreArgs=FunArgs)
        for (i in seq(1, length(plotvar))) {
            df.list[[i]] = df.list[[i]][c('year', plotvar[i])]
            names(df.list[[i]]) = c('year', 'plotvar')
        }
        PlotArgs[['df.list']] = df.list
    }
    
    PlotArgs[['x.limits']] = PlotArgs[['df.list']][[1]]$year

    # Use timeseries plot function
    message('Ploting...')
    plt = do.call(ggtimeseries, PlotArgs)

    ggsave(plt,
    file=glue('{output_dir}/{header}{suffix}.{ftype}'),
    width=8, height=6)
}


timeseries_compare_adaptation = function(
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    output_dir=TS_OUTPUT_DEFAULT,
    with_costs=TRUE) {

    legend.breaks = c(
        "Mortality effects of climate change without benefits of income growth or adaptation",
        "Mortality effects of climate change with benefits of income growth",
        "Mortality effects of climate change with benefits of income growth and adaptation")

    legend.values = c(
        "Mortality effects of climate change without benefits of income growth or adaptation" = "#D55E00",
        "Mortality effects of climate change with benefits of income growth"= "#E69F00", 
        "Mortality effects of climate change with benefits of income growth and adaptation" = "#009E73")

    scns <- c('noadapt', 'incadapt', 'fulladapt')
    suf <- glue('_{rcp}_{ssp}_{iam}')
    if (with_costs) {
        legend.breaks <- c(legend.breaks, "Full mortality risk of climate change")
        legend.values <- c(legend.values, "Full mortality risk of climate change" = "#000000")
        scns <- c('noadapt', 'incadapt', 'fulladapt', 'fulladaptcosts')
        suf <- glue('{suf}_withcosts')
    }

    PlotArgs=list(
        y.limits=c(-90, 235),
        x.limits = c(2000, 2099),
        legend.breaks=legend.breaks,
        legend.values=legend.values,
        y.breaks=seq(-50,235, by = 50),
        legend.pos=c(0.35, 0.8))

    multi_timeseries(
        scn=scns,
        FUN=get_mortality_impacts,
        header='timeseries_compare_adaptation',
        suffix=suf,
        plotvar='mean',
        FunArgs=list(
            regions='global', 
            year_list=seq(2000, 2099),
            rcp=rcp, iam=iam, ssp=ssp),
        PlotArgs=PlotArgs,
        output_dir=output_dir,
        ftype='pdf')

}


timeseries_compare_rcp = function(
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    output_dir=TS_OUTPUT_DEFAULT,
    with_costs=TRUE) {

    qtl = c('q5', 'q10', 'q25', 'mean', 'q75', 'q90', 'q95')
    scn ='fulladapt'
    suf = ''
    if (with_costs) {
        scn <- 'fulladaptcosts'
        suf <- '_withcosts'
    }
    dflist = wrap_mapply(rcp=c('rcp45', 'rcp85'),
        FUN=get_mortality_impacts,
        MoreArgs=list(
            regions='global',
            qtile=qtl,
            scn=scn,
            year_list=seq(2000, 2099)))

    names(dflist) = c('rcp45', 'rcp85')

    boxplot.85 = as.numeric(dflist[['rcp85']][dflist[['rcp85']]$year==2099, qtl])
    boxplot.45 = as.numeric(dflist[['rcp45']][dflist[['rcp45']]$year==2099, qtl])

    PlotArgs= list(df.list = list(dflist[[rcp]][, c('year', 'mean')]), 
        df.u = dflist[[rcp]], 
        ub = "q75", lb = "q25", 
        ub.2 = "q90", lb.2 = "q10", 
        df.box = boxplot.85, 
        df.box.2 = boxplot.45, 
        y.limits = c(-90, 235),
        x.limits = c(2000, 2099),
        legend.breaks = "Mean", 
        legend.values = "black",
        y.breaks=seq(-50,235, by = 50),
        legend.pos=c(0.35, 0.8))

    plt = do.call(ggtimeseries, PlotArgs)

    ggsave(plt,
    file=glue('{output_dir}/time_series_rcp_uncertainty_{rcp}_{ssp}_{iam}{suf}.pdf'),
    width=8, height=6)

}

timeseries_compare_incadapt_noadapt = function(
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    qtles,
    output_dir=TS_OUTPUT_DEFAULT) {

    qtl = c('q5', 'q10', 'q25', 'mean', 'q75', 'q90', 'q95')
    scn =c('noadapt', 'incadapt')
    suf = ''

    legend.breaks = c(
        "Mortality effects of climate change without benefits of income growth or adaptation",
        "Mortality effects of climate change with benefits of income growth")

    legend.values = c(
        "Mortality effects of climate change without benefits of income growth or adaptation" = "#D55E00",
        "Mortality effects of climate change with benefits of income growth"= "#E69F00")

    dflist = wrap_mapply(scn=scn,
                         FUN=get_mortality_impacts,
        MoreArgs=list(
            regions='global',
            qtile=qtl,
            year_list=seq(2000, 2099),
            rcp=rcp))

    dtlist <- lapply(dflist, as.data.table) 
    #processing uncertainty with data table 
    uncertainty <- lapply(dtlist, function(x) setkey(setnames(x, qtles,c('lb','ub'))[,.(year,lb,ub)], year))
    uncertainty <- Reduce(function(x,y) merge(x,y,suffixes = c("1", "2")), uncertainty)

    dtlist <- lapply(dtlist, function(x) x[,.(year, mean)])

    PlotArgs= list(df.list = lapply(dtlist, as.data.frame), 
        df.u = as.data.frame(uncertainty), 
        ub = "ub1", lb = "lb1", 
        ub.2 = "ub2", lb.2 = "lb2", 
        uncertainty.color=legend.values[1],
        uncertainty.color.2=legend.values[2],
        y.limits = c(-90, 235),
        x.limits = c(2000, 2099),
        legend.breaks = legend.breaks, 
        legend.values = legend.values,
        y.breaks=seq(-50,235, by = 50),
        legend.pos=c(0.35, 0.8))

    plt = do.call(ggtimeseries, PlotArgs)

    ggsave(plt,
    file=glue("{output_dir}/time_series_incadapt_noadapt_uncertainty_{paste(qtles, collapse='_')}_{rcp}_{ssp}_{iam}{suf}.pdf"),
    width=8, height=6)

}
timeseries_linear_extrapolation = function(output_dir=TS_APPENDIX_DEFAULT) {

    one99 = glue('{DB}/2_projection/3_impacts/',
        'single_edgeclip_1-99/rcp85/CCSM4/low/SSP3')

    def_single = glue("{DB}/2_projection/3_impacts/main_specification/raw/single/",
        "rcp85/CCSM4/low/SSP3")

    legend.breaks = c(
        "Mortality effects of climate change without benefits of income growth or adaptation",
        "Mortality effects of climate change with benefits of income growth",
        "Mortality effects of climate change with benefits of income growth and adaptation", 
        "Full mortality risk of climate change")
    legend.values = c(
        "Mortality effects of climate change without benefits of income growth or adaptation" = "#D55E00",
        "Mortality effects of climate change with benefits of income growth"= "#E69F00", 
        "Mortality effects of climate change with benefits of income growth and adaptation" = "#009E73",
        "Full mortality risk of climate change" = "#000000")

    PlotArgs=list(
        y.limits=c(-50, 130),
        x.limits = c(2000, 2099),
        legend.breaks=legend.breaks,
        legend.values=legend.values,
        y.breaks=NULL,
        legend.pos=c(0.35, 0.8))

    multi_timeseries(
        scn=c('noadapt', 'incadapt', 'fulladapt'),
        FUN=get_mortality_impacts_single,
        header='timeseries_compare_adaptation',
        plotvar='impacts',
        suffix='_lin-ext',
        FunArgs=list(regions='global', 
            single_path=one99,
            year_list=seq(2000, 2099)),
        PlotArgs=PlotArgs,
        output_dir=output_dir,
        ftype='png')

    multi_timeseries(
        scn=c('noadapt', 'incadapt', 'fulladapt'),
        FUN=get_mortality_impacts_single,
        header='timeseries_compare_adaptation',
        plotvar='impacts',
        suffix='_main-model',
        FunArgs=list(regions='global', single_path=def_single),
        PlotArgs=PlotArgs,
        output_dir=output_dir,
        ftype='png')

}


#' loads output from a batch of runs where we allowed for four different levels of long run temperature and income adaptation speed.
#' @param adaptrate character. One of c('fast15', 'fast2', 'normal', 'slow'). 
timeseries_flexadapt_rate = function(output_dir=TS_APPENDIX_DEFAULT, adaptrate='normal') {
    speeds = paste0('{DB}/2_projection/3_impacts/',
        c('fastadapt15','fastadapt2','main_specification/raw','slowadapt05'),'/single/rcp85/CCSM4/low/SSP3')
    names(speeds) <- c('fast15', 'fast2', 'normal', 'slow')
    n_single = length(speeds)
    suffixes = c('_flexadapt-fast-15','_flexadapt-fast-2','_flexadapt-normal','_flexadapt-slow')
    names(suffixes) <- names(speeds)

    legend.breaks = c(
        "Mortality effects of climate change without benefits of income growth or adaptation",
        "Mortality effects of climate change with benefits of income growth",
        "Mortality effects of climate change with benefits of income growth and adaptation", 
        "Full mortality risk of climate change")
    legend.values = c(
        "Mortality effects of climate change without benefits of income growth or adaptation" = "#D55E00",
        "Mortality effects of climate change with benefits of income growth"= "#E69F00", 
        "Mortality effects of climate change with benefits of income growth and adaptation" = "#009E73",
        "Full mortality risk of climate change" = "#000000")

    PlotArgs=list(
        y.limits=c(-20, 150),
        x.limits = c(2000, 2099),
        legend.breaks=legend.breaks,
        legend.values=legend.values,
        y.breaks=NULL,
        legend.pos=c(0.35, 0.8))


    cargs <- list(
        scn=c('noadapt', 'incadapt', 'fulladapt', 'fulladaptcosts'),
        FUN=get_mortality_impacts_single,
        header='timeseries_flexadapt',
        plotvar='impacts',
        PlotArgs=PlotArgs,
        output_dir=output_dir,
        ftype='pdf',
        suffix=suffixes[[adaptrate]])


    #iteratively add each single path to a copy of Funargs 
    singlepath <- speeds[[adaptrate]]
    basenamearg <- list()
    basenamearg[[singlepath]] <- 'Agespec_interaction_response_pre-popfix'
    FunArgs <- list(
            regions='global',
            basename=basenamearg,
            year_list=seq(2000, 2099),
            single_path=singlepath)

    allargs <- c(cargs, list(FunArgs=FunArgs))

    done <- do.call(multi_timeseries, allargs)


    return(done)
}

timeseries_compare_binnned = function(output_dir=TS_APPENDIX_DEFAULT) {

    binned = glue("{DB}/2_projection/3_impacts/binned_spec/single/",
        "rcp85/CCSM4/low/SSP3")

    def_single = glue("{DB}/2_projection/3_impacts/main_specification/raw/single/",
        "rcp85/CCSM4/low/SSP3")

    basename = list()
    basename[[binned]] = 'Agespec_interaction_response_bins'
    basename[[def_single]] = 'Agespec_interaction_GMFD_POLY-4_TINV_CYA_NW_w1'

    legend.breaks = c(
        "Binned temperature (no adaptation scenario)",
        "4th order polynomial (no adaptation scenario)")
    legend.values = c(
        "Binned temperature (no adaptation scenario)" = "#009E73",
        "4th order polynomial (no adaptation scenario)" = "#D55E00")
        
    PlotArgs=list(
        y.limits=c(-20, 155),
        x.limits = c(2000, 2099),
        legend.breaks=legend.breaks,
        legend.values=legend.values,
        y.breaks=NULL,
        legend.pos=c(0.35, 0.8))

    multi_timeseries(
        single_path=c(binned, def_single),
        FUN=get_mortality_impacts_single,
        header='timeseries_compare_binned_temp',
        plotvar='impacts',
        suffix='',
        FunArgs=list(
            regions='global',
            scn='noadapt',
            basename=basename,
            year_list=seq(2000, 2099)),
        PlotArgs=PlotArgs,
        output_dir=output_dir,
        ftype='pdf')

}

timeseries_compare_ssp_iam = function(output_dir=TS_APPENDIX_DEFAULT) {

    legend.breaks = c(
        "RCP 4.5",
        "RCP 8.5")
    legend.values = c(
        "RCP 4.5" = "#009E73",
        "RCP 8.5" = "#D55E00")

    PlotArgs=list(
        y.limits=c(-5, 85),
        x.limits = c(2000, 2099),
        legend.breaks=legend.breaks,
        legend.values=legend.values,
        y.breaks=NULL,
        legend.pos=c(0.35, 0.8))

    plot_panel = function(ssp, iam) {
        multi_timeseries(
            rcp=c('rcp45', 'rcp85'),
            FUN=get_mortality_impacts,
            header='timeseries_compare_ssp_iam',
            plotvar='mean',
            suffix=glue('_{ssp}_{iam}'),
            FunArgs=list(
                regions='global',
                ssp=ssp,
                iam=iam, 
                year_list=seq(2000,2099)),
            PlotArgs=PlotArgs,
            output_dir=output_dir,
            ftype='png')
    }

    wrap_mapply(
        ssp=c('SSP2', 'SSP3', 'SSP4'),
        iam=c('low', 'high'),
        FUN=plot_panel )

}


timeseries_compare_age_groups = function(output_dir=TS_APPENDIX_DEFAULT) {

    legend.breaks = c(
        "age > 64",
        "age 5-64",
        "age <5")

    legend.values = c(
        "age > 64" = "#009E73",
        "age 5-64" = "#D55E00",
        "age <5" = "#E69F00")


    Args=list(
        y.limits=c(-5, 400),
        legend.breaks=legend.breaks,
        legend.values=legend.values,
        y.breaks=NULL,
        legend.pos=c(0.35, 0.8))

    multi_timeseries(
        age=c('oldest', 'older', 'young'),
        FUN=get_mortality_impacts,
        header='timeseries_compare_age_groups',
        plotvar='mean',
        suffix='',
        FunArgs=list(
            regions='global',
            year_list=seq(2000,2099)),
        PlotArgs=PlotArgs,
        output_dir=output_dir,
        ftype='png')

}