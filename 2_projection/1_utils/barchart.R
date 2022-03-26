# Purpose: Produces impacts at terciles of the income and climate distributions
# for purposes of the bar chart in Figure IX.

BARCHART_OUTPUT= glue("{OUTPUT}/figures/Figure_9_barchart")


#' This function generates the impacts values required to generate the bar chart
#' in Figure IX of Carleton et al. 2022. Note that generating the figure in the
#' paper is largely a post processing effort that relies upon excel (due to
#' arbitrarily ordered barchart stacking) and Adobe Illustrator.
#' 
#' Inputs
#' ------
#' This function relies on `get_econvar`, `get_mortality_covariates`, and
#' `get_mortality_impacts` for population, covariate, and impacts data,
#' respectively. It accepts parameters for RCP, IAM, and SSP, which are passed
#' onto those functions.
#' 
#' Outputs
#' -------
#' Exports CSV file containing impacts at each tercile of income and climate,  
#' as well as the global average. 
#' 
#' Dependencies
#' ------------
#' - econvar:::get_econvar
#' - impacts:::get_mortality_covariates
#' - impacts:::get_mortality_impacts
#' - utils:::wrap_mapply
#' 
#' Parameters/Return
#' -----------------
#' @param rcp RCP scenario (rcp45, rcp85)
#' @param iam Economic modelling scenario (low, high)
#' @param ssp SSP scenario (SSP2-4)
mortality_barchart = function(
    rcp='rcp85',
    iam='low',
    ssp='SSP3',
    output_dir=BARCHART_OUTPUT) {

	# create output directory
	dir.create(output_dir, showWarnings = FALSE)


	# Load Population (2099).
	pop = get_econvar('pop', iam=iam, ssp=ssp, year_list=2099, as.DT=T)[,
		year:=NULL]

	# Load covariates (2015).
	cov_path = glue('{DB}/2_projection/3_impacts/',
	    'main_specification/raw/single/{rcp}/CCSM4/{iam}/{ssp}')
	covars = get_mortality_covariates(single_path=cov_path, year_list=2015, as.DT=T)

	# Split covariates into terciles of income and climate.
	covars$ytile = ntile(covars$loggdppc, 3)
	covars$ttile = ntile(covars$climtas, 3)
	covars = covars[, year:=NULL]

	# Load impacts and adaptation costs.
	impacts = wrap_mapply(
		scn=c('fulladaptcosts', 'fulladapt', 'costs'),
		FUN=get_mortality_impacts,
		MoreArgs=list(
			year_list=2099,
			ssp=ssp,
			iam=iam,
			rcp=rcp,
			as.DT=T))

	impacts = rbindlist(impacts, use.names=T, idcol='scn')
	impacts = dcast(impacts, region + year ~ scn, value.var='mean')[
		, year:=NULL]

	# Merge together
	df = Reduce(merge, list(impacts, pop, covars))

	# Collapse to weighted mean of climate.
	clim = df[, lapply(.SD, weighted.mean, pop), keyby='ttile',
		.SDcols=c('fulladaptcosts', 'fulladapt', 'costs')]
	clim = cbind(clim, data.table(
		group=c('cold climate', 'middle climate', 'hot climate')))[
		, ttile:=NULL]

	# Collapse to weighted mean of income
	inc = df[, lapply(.SD, weighted.mean, pop), keyby='ytile',
		.SDcols=c('fulladaptcosts', 'fulladapt', 'costs')]
	inc = cbind(inc, data.table(
		group=c('low income', 'middle income', 'high income')))[
		, ytile:=NULL]

	# Global average
	global = df[, lapply(.SD, weighted.mean, pop),
		.SDcols=c('fulladaptcosts', 'fulladapt', 'costs')][
		, group := 'global']

	# Append and export.
	out = rbindlist(list(global, clim, inc), use.names=T)
	message(glue('Saving {output_dir}/tercile_impacts_barchart_{rcp}_{ssp}_{iam}.csv'))
	fwrite(out, glue('{output_dir}/tercile_impacts_barchart_{rcp}_{ssp}_{iam}.csv'))

}
