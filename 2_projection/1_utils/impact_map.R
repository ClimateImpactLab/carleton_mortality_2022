# Purpose Generates maps of projected mortality impacts.

IMPACT_MAPS_OUTPUT = glue('{OUTPUT}/2_projection/figures/3a_maps')

IMPACT_MAPS_APPENDIX = glue('{OUTPUT}/2_projection/figures/appendix/maps')

quick_map = function(
    ...,
    FUN,
    plotvar,
    FunArgs=NULL,
    map.df=NULL,
    output_dir=OUTPUT_DEFAULT,
    diff=FALSE,
    export=TRUE, 
    suffix='',
    suf_exclude=c(),
    header='impact-map',
    PlotArgs=list(),
    ftype='png') {

    wrap = function(...) 
        (FUN(...)[c('region', plotvar)])

    if (is.null(map.df))
        map.df=load.saved.map()

    dflist = wrap_mapply(..., FUN=wrap, MoreArgs=FunArgs)
    PlotArgs[['plot.var']] = plotvar
    PlotArgs[['map.df']] = map.df

    if (diff) {
        stopifnot(length(dflist)==2)
        dflist = return_diff(dflist, plotvar)
        PlotArgs[['plot.var']] = 'diff'
    }

    pltlist = wrap_mapply(df=dflist, FUN=join.plot.map, MoreArgs=PlotArgs)

    if (export) {
        vect = as.list(do.call(expand.grid, list(...)))
        i=1
        for (plt in pltlist) {

            suf=''
            for (j in names(vect)){
                if (j %in% suf_exclude)
                    next
                else
                    suf = glue('{suf}_{vect[[j]][i]}')
            }
            
            plt = plt +   
                labs(title = glue('impact-map{suf}{suffix}'))

            outfile = glue('{output_dir}/',
                '{header}{suf}{suffix}.{ftype}')
            ggsave(plt, file=outfile, width=7, height=7)
            message(glue('Exporting {outfile}...'))
            i = i+1

        }
    }

    return(pltlist)
}

mortality_impacts_map = function(
    scn='fulladaptcosts',
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    output_dir=IMPACT_MAPS_OUTPUT,
    color.values='default',
    color.scheme='div',
    crosshatch=FALSE,
    limit=1000,
    rescale_vect=c(-1, -1/5, -1/10, -1/20, -1/40, -1/80, -1.0E-10,
            0, 1.0E-10, 1/80, 1/40, 1/20, 1/10, 1/5, 1),
    suffix='',
    ftype='png'){

    limit=1000

    PlotArgs = list(
        df.key='region',
        topcode.ub=limit,
        topcode = T,
        breaks_labels_val = seq(-limit, limit, limit/10),
        bar.width = unit(130, units = "mm"),
        color.scheme = color.scheme,
        crosshatch = crosshatch,
        colorbar.title='Deaths per 100,000')

    if(!is.null(rescale_vect)){
        rescale_val = rescale_vect*limit
        PlotArgs[['rescale_val']] = rescale_val
    }


    if (!identical(color.values,'default')) {
        PlotArgs[['color.values']] = color.values
    }

    quick_map(
        scn=scn,
        age='combined',
        ssp=ssp, rcp=rcp, iam=iam, 
        plotvar='mean',
        year_list=2099,
        FUN=get_mortality_impacts,
        PlotArgs=PlotArgs,
        output_dir=output_dir,
        ftype=ftype,
        suffix=suffix)

}

mortality_impacts_map_all_adaptation = function(
    rcp='rcp85',
    ssp='SSP3',
    iam='low',
    output_dir=IMPACT_MAPS_APPENDIX) {

    mortality_impacts_map(
        scn=c('fulladaptcosts', 'fulladapt', 'noadapt', 'incadapt'),
        ssp=ssp, rcp=rcp, iam=iam,
        output_dir=output_dir)

}


return_diff = function(dflist, plotvar) {
    
    rhs = dflist[[2]] %>%
        dplyr::select(region, rhs=!!plotvar)

    df = dflist[[1]] %>%
        dplyr::select(region, lhs=!!plotvar) %>%
        dplyr::left_join(rhs, by='region') %>%
        dplyr::mutate(diff = lhs - rhs)

    return(list(df))
}