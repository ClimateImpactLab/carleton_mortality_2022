
################################################
# GENERATE ADAPTATION COST ESTIMATES FOLLOWING REVEALED PREFERNCE MODEL

# This script uses climate projection data and outputs from the projection of future mortality impacts of climate 
# change (see 2_projection/2_run_projections/README.md for details) to construct empirical estimates of unobserved
# adaptation costs, following the conceptual framework outlined in Section VI of Carleton et al. (2022).

# This calculation is the empirical implementation of Equation (7) in Section VI, except that it omits the VSL.
# The VSL is later multiplied by these adaptation cost estimates in the valuation step of the paper pipeline.
# See 3_valuation/ for details on the monetization of mortality impacts of climate change, including estimated 
# adaptation costs.

# This script does not need to be run directly in order to replicate paper results. It is called by scripts in other
# parts of the 2_projection/ directory and is implemented automatically. 

###########################
# Syntax: cost_curves(rcp, climate_model, impactspath), Where:
# rcp = which RCP? enter as a string --  'rcp85' or 'rcp45'
# climate_model = which climate model? enter as a string -- e.g. 'MIROC-ESM'
# impactspath = filepath for the projected impacts for this model
###########################

rm(list=ls())

list.of.packages <- c('pracma','ncdf4','dplyr','DataCombine','zoo','abind')
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")
devtools::install_github("cran/rPython") 
invisible(lapply(c(list.of.packages, 'rPython'), function(x) suppressPackageStartupMessages({library(x, character.only=TRUE)})))
suppressPackageStartupMessages({source("generate/stochpower.R")})

###############################################
# Set up
###############################################

args <- commandArgs(trailingOnly=T)

rcp = args[1]
climmodel = args[2]

# Filepath for climate covariates and annual temperatures by region-year through 2100
tavgpath = paste0('/shares/gcp/outputs/temps/',rcp,'/',climmodel,'/climtas.nc4')

# Filepath for impacts
impactspath <- args[3] # paste0("outputs/", sector, "/", impactsfolder, "/median-clipped/rcp", rcp, "/", climmodel, "/high/SSP4/moratlity_cubic_splines_2factors_", climdata, "_031617.nc4")

suffix <- args[4] # "-costs"

# Averaging method: This is the method used to construct 'TMEAN' from annual temperatures. We use
# a Bartlett kernel, as is done in estimation of the panel regression in Equation (4).
avgmethod = 'bartlett'

# Base year for costs
baseyear <- 2015

##############################################################################################
# Load realized climate variable 
##############################################################################################

nc.tavg <- nc_open(tavgpath)
temps.avg <- ncvar_get(nc.tavg, 'averaged') #average temperatures
regions <- ncvar_get(nc.tavg, 'regions')
year.avg <- ncvar_get(nc.tavg, 'year')

##############################################################################################
# Load adaptive investments term generated in projection process
  # This is gamma1*E[T] in Equation (7). It is generated in the process
  # of computing the Monte Carlo simulation, because it depends on the 
  # draw of statistical uncertainty (gamma1) and on the climate model (E[T]).
  # Note that it will be zero if the response function is fully flat (no further
  # adaptation is feasible, therefore there are no further adaptation costs).
##############################################################################################

nc.imp <- nc_open(impactspath)
impacts.climtaseff <- ncvar_get(nc.imp, 'climtas_effect') # Sum of adaptive investments at daily level

#check whether timesteps in climate file = timesteps in impacts file
if (length(year.avg) != length(ncvar_get(nc.imp, 'year'))) {
  if (length(dim(impacts.climtaseff)) == 2)
    impacts.climtaseff <- impacts.climtaseff[, 1:length(year.avg)]
  else
    impacts.climtaseff <- impacts.climtaseff[1:length(year.avg)]    
}

rm(nc.imp)

if (length(dim(impacts.climtaseff)) == 1) {
    extended <- matrix(0, 1, length(impacts.climtaseff))
    extended[1,] <- impacts.climtaseff
    impacts.climtaseff <- extended
    temps.avg <- temps.avg[regions == 'IND.33.542.2153',, drop=F]
    regions <- c('IND.33.542.2153')
}

print("IMPACTS LOADED")

##############################################################################################
# Generate a moving average of the adaptive investments term
     # From the projection output we have gamma1*T, but we need 
     # gamma1*E[T]. Since gamma1 is a scalar for each Monte Carlo
     # simulation, we simply compute E[gamma1*T]=gamma1*E[T] using 
     # a Bartlett kernel to compute the expectation.
##############################################################################################

# 15-year moving average 
movingavg <- array(NA, dim=dim(impacts.climtaseff))

R <- dim(impacts.climtaseff)[1]

if(avgmethod == 'bartlett') {
# BARTLETT KERNEL
for(r in 1:R) { #loop over all regions
    if (sum(is.finite(impacts.climtaseff[r,])) > 0)
      tempdf <- impacts.climtaseff[r,]
      movingavg[r,] <- movavg(tempdf,15,'w')
  }
}

if(avgmethod=='movingavg') {
  for(r in 1:R) { #loop over all regions
    if (sum(is.finite(impacts.climtaseff[r,])) > 0)
    movingavg[r,] <- ave(impacts.climtaseff[r,], FUN=function(x) rollmean(x, k=15, fill="extend"))
  }
}

print("MOVING AVERAGE OF ADAPTIVE INVESTMENTS CALCULATED")

###############################################
# For each region-year, calculate csosts
###############################################

# Initialize 
results <- array(0, dim=c(dim(temps.avg)[1], 2, dim(temps.avg)[2]) )

# Loop: for each impact region and each year, calculate bounds
  # NOTE: "upper" and "lower" bounds are computed for each impact region and year.
  # However, only "upper" bounds are used in the paper, as they reflect the discrete 
  # approximation in Equation (7) of the continusous revealed preference solution
  # shown in Equation (6). The two bounds are equal in the limit, as the difference between
  # TMEAN_t and TMEAN_t-1 approaches zero.
                         
for (r in 1:R){

    options(warn=-1)
    # Need a lag variable of the expected value of adaptive investments term
    tempdf <- as.data.frame(movingavg[r,])
    colnames(tempdf) <- "climvar"
    expect <- slide(tempdf, Var='climvar', NewVar = 'lag', slideBy=-1, reminder=F)
    rm(tempdf)
    
    # COSTS: CUMULATIVE COSTS VERSION
    tempdf <- as.data.frame(temps.avg[r,])
    colnames(tempdf) <- "climcov"
    avg2 <- slide(tempdf, Var="climcov", NewVar = 'lag', slideBy=-1, reminder=F)
    avg2$diff <- avg2$lag - avg2$climcov
    rm(tempdf)
    options(warn=0)

    # Lower and upper bounds
    results[r,1,] <-  avg2$diff * (expect$climvar[which(year.avg==baseyear)]) # lower
    results[r,2,] <-  avg2$diff * (expect$climvar) # upper
    
    # Clear
    rm(avg, expect)
 
  # Track progress
  if (r/1000 == round(r/1000)) {
    print(paste0("------- REGION ", r, " FINISHED ------------"))
  }
}

###############################################
# ADD ZEROs AT START, CUMULATIVELY SUM
###############################################

#Add in costs of zero for initial years
  baseline <- which(year.avg==baseyear)
  for (a in 1:baseline) {
    results[,,a] <- matrix(0,dim(results)[1], dim(results)[2])
  }

# Cumulative sum over all years for cumulative results
for (r in 1:R) {
  results[r,1,] <- cumsum(results[r,1,])
  results[r,2,] <- cumsum(results[r,2,])
}

###############################################
# Export as net CDF
###############################################

year <- year.avg
dimregions <- ncdim_def("region", units="" ,1:R)
dimtime <- ncdim_def("year",  units="", year)

varregion <- ncvar_def(name = "regions",  units="", dim=list(dimregions))
varyear <- ncvar_def(name = "years",   units="", dim=list(dimtime))

varcosts_lb <- ncvar_def(name = "costs_lb", units="deaths/100000", dim=list(dimregions, dimtime))
varcosts_ub <- ncvar_def(name = "costs_ub", units="deaths/100000", dim=list(dimregions, dimtime))

vars <- list(varregion, varyear, varcosts_lb, varcosts_ub)

# Filepath for cost output
outpath <- gsub(".nc4", paste0(suffix, ".nc4"), impactspath)

cost_nc <- nc_create(outpath, vars)

print("CREATED NEW NETCDF FILE")

ncvar_put(cost_nc, varregion, regions)
ncvar_put(cost_nc, varyear, year)
ncvar_put(cost_nc, varcosts_lb, results[,1 ,])
ncvar_put(cost_nc, varcosts_ub, results[,2 ,])
nc_close(cost_nc)

print("----------- DONE DONE DONE ------------")
