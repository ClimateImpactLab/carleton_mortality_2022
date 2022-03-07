# Purpose: Loads "economic" variables (income, income per capita, and population)
# from stored datasets and provides helper functions for population-weighted averages.

EV_INPUT_DEFAULT = glue('{DB}/2_projection/2_econ_vars')

#' Extracts population and income data from SSP projections.
#' 
#' Inputs
#' ------
#' `data/2_projection/2_econ_vars/SSP*.nc4` - Netcdf files containing age-specific
#' and total population, GDP, and GDP per capita vaariables for each SSP/IAM
#' combination at the impact region level. This function extracts economic
#' variables from these datasets based upon various parameters defining the desired
#' output. When needed, values for aggregated regions are produced by calculating
#' the total across child impact regions and re-calculating per capita income.
#' 
#' Outputs
#' -------
#' Dataframe containing projected economic variables conistsent with input parameters.
#' 
#' Parameters/Return
#' -----------------
#' @param units pop, gdp, or gdppc (2019$). Also extracts age-specific pop:
#' (pop0to4, pop5to64, pop65plus)
#' @param regions Regions, can be IRs or aggregated regions. Also accepts:
#' - all: all ~25k impact regions; 
#' - iso: country-level output; 
#' - global: global outputs
#' @param ssp SSP scenario (SSP1-5)
#' @param iam Economic modelling scenario (low, high)
#' @param year_list List of years to extract between 2020 and 2099.
#' @param input_dir Directory containing socioecon data (note default)
#' @param scale_variable Can be used to scale output, e.g. millions of dollars
#'
#' @return Dataframe containing projected values.
get_econvar = function(
	units='pop', 
	regions='all', 
	ssp='SSP3', 
	iam='low', 
	year_list=seq(2020,2099), 
	input_dir=EV_INPUT_DEFAULT, 
	scale_variable=1,
    as.DT=FALSE ) {

    # Parse inputs to determine list of regions
    region_list = return_region_list(regions)
    resolution_list = check_resolution(region_list)
    scale_func = function(x, scl) (x * scl)	

    agepop = c('pop0to4', 'pop5to64', 'pop65plus')
    incvars = c('gdp', 'gdppc')

    check_share = any(sapply(
        agepop, function(x) (match(x, units, nomatch=0)>0)))
    if (check_share)
        popvars=c('pop', agepop)
    else
        popvars=c('pop')

    all_vars = c('region', 'year', popvars, incvars)

    df = open_econvar_nc4(glue('{input_dir}/{ssp}.nc4'), 
        varlist=c(popvars, incvars))[
        year %in% year_list & model==iam]
    dflist = list()
    # Extract Impact Regions
    if (!is.null(resolution_list[['ir_level']]))
        dflist[['ir_level']] = df[
            region %in% resolution_list[['ir_level']]][
                , ..all_vars]

    # Collapse aggregated regions.
    levels = c(popvars, 'gdp')
    if (!is.null(resolution_list[['aggregated']])) {
        aggregates = get_children(resolution_list[['aggregated']])
        for (reg in names(aggregates)) {
            dflist[[reg]] = df[
                region %in% aggregates[[reg]],
                lapply(.SD, sum), by=year, .SDcols=levels][
                    , gdppc := gdp / pop][, region := reg][
                        , ..all_vars]         
        }
    }

    # Convert dollars to 2019$.
    out = rbindlist(dflist, use.names=TRUE)[
    , (incvars) := lapply(.SD, scale_func, scl=1.273526), 
        .SDcols=incvars]

    # Scale and export.
    sub_vars = c('region', 'year', units)
    out = out[, (units) := lapply(.SD, scale_func, scl=scale_variable), 
        .SDcols=units][
            , ..sub_vars]

    # Convert to dataframe or leave as data.table.
    if (!as.DT) df = data.frame(df)

    return(out)

}

#' Converts economic data nc4 into workable dataframe. Primarily a 
#' helper function for `get_econvar`.
#' 
#' @param nc4_dir Directory to nc4 containing economic variables.
#' @param varlist list of variables to extract from nc4. Includes:
#' 'pop', 'gdp', 'gdppc', 'pop0to4', 'pop5to64', 'pop65plus'
#' @return Dataframe containing nc4 .
open_econvar_nc4 = function(nc4_dir, varlist=c('pop', 'gdp', 'gdppc')) {

    ncin=nc_open(nc4_dir)
    args = list(ncin=ncin)
    dflist = wrap_mapply(var=varlist, FUN=nc4_to_array, MoreArgs=args)

    lambda = function(array, name) {
        df = data.table(data.table::melt(array))
        names(df) =  c('year', 'region', 'model', name) 
        return(df) 
    }

    df = mapply(dflist, names(dflist), FUN=lambda, SIMPLIFY=FALSE)
    nc_close(ncin)
    return(Reduce(merge,df))
}


#' Converts Netcdf variable into an R ndarray with
#' named dimensions. 
#'
#' @param var Variable in Netcdf.
#' @param ncin Netcdf.
#' @return ndarray with named dimensions.
nc4_to_array = function(var, ncin) {

    dims = c()
    dim_list = list()
    for (i in seq(1, length(ncin$var[[var]][['dim']]))) {
        d = ncin$var[[var]][['dim']][[i]][['vals']]
        dims = c(dims, length(d))
        dim_list[[i]] = d
    }

    out_array = ncvar_get(ncin, var)
    out = array(
        out_array,
        dim=dims,
        dimnames=dim_list)

    return(out)
}

#' <one-line>
#'
#' <description>
#'
#' @param  df <description>
#' @param young <description>
#' @param older <description>
#' @param oldest <description>
#' @param regions <description>
#' @param year <description>
#' @param varn <description>
#' @param ...  <description>
#' @return <description>
popwt_collapse_columns = function(
    df,
    young,
    older,
    oldest,
    regions='region',
    year='year',
    varn='combined',
    ... ) {

    popvars = c('pop', 'pop0to4', 'pop5to64', 'pop65plus')
    groups = c(regions, year)

    pop = get_econvar(
        units=popvars,
        regions=unlist(unique(df[regions])),
        year_list=unlist(unique(df[year])), ...) %>%
        dplyr::select(one_of(c(groups, popvars)))

    df = left_join(df, pop, by=groups) 

    df[varn] = (
        df[young] * df$pop0to4 +
        df[older] * df$pop5to64 +
        df[oldest] * df$pop65plus ) / df$pop

    df = dplyr::select(df, -one_of(popvars))
    
    return(df)
}


popwt_collapse_rows = function(
    df,
    varlist,
    avg_over='region',
    groups=c(),
    pop=NULL,
    ... ) {

    popvars = c('pop')

    if (is.null(pop)) {
        pop = get_econvar(
            units=popvars,
            regions='all',
            year_list=unlist(unique(df['year'])), ...) %>%
            dplyr::select(all_of(c('region', 'year', popvars)))
        message('Pop loaded...')
    }

    groups = c('region', 'year', groups)

    df = df %>% 
        left_join(pop, by=groups) %>%
        group_by_at(vars(one_of(groups[!(groups %in% avg_over)]))) %>%
        summarize_at(vars(one_of(varlist)), ~ weighted.mean(., w=pop)) %>%
        ungroup() %>%
        data.frame()
    
    return(df)
}


popwt_collapse_to_region = function(
    df,
    varlist,
    ag_region,
    ...) {

    stopifnot(length(ag_region)==1)

    reglist = get_children(ag_region)
    irs = reglist[[1]]

    if (length(irs)==0)
        return(df[df[regions]==ag_region,])

    df = df %>%
        dplyr::filter(region %in% irs)  %>%
        popwt_collapse_rows(varlist=varlist, ...) %>%
        dplyr::mutate(region = ag_region)

    return(df)

}