##############################

# Purpose : read the India-level historical monthly binned daily average temperature data, and reformat it so that it you can make a histogram representation of it.

# Input : that data is /DB/0_data_cleaning/1_raw/Countries/IND/Climate/adm0/weather_data/csv_monthly

##############################

REPO <- Sys.getenv(c("REPO"))
DB <- Sys.getenv(c("DB"))
OUTPUT <- Sys.getenv(c("OUTPUT"))

library(data.table)
library(haven)

#' reads a month-year wide csv, converts it to long, and sets names.
Reformat <- function(file){
	dir <- glue('{DB}/0_data_cleaning/1_raw/Countries/IND/Climate/adm0/weather_data/csv_monthly')
	cons_prefix <- 'GMFD_tavg_bins_'
	cons_suffix <- '_v2_1955_2010_monthly_popwt.csv'
	variable <- file
	for (remove in c(cons_prefix, cons_suffix)){
		variable <- gsub(remove,'',variable)
	}
	DT <- melt(fread(file.path(dir, file)),'ID_0')
	DT[,ID_0:=NULL][,year:=substr(variable,2,5)][,month:=substr(variable,8,9)][,variable:=NULL][]
	DT <- DT[,.(value=sum(value)), by=year]
	setnames(DT,'value',variable)
	setkey(DT, year)
	return(DT)
}

files <- list.files(dir) # get list of files 
DT <- lapply(files, Reformat) #read, reshape, set year keys of all the files 
DT <- Reduce(merge, DT) #merge them on the year
DT <- melt(DT, c('year')) #reshape to long to get : year, bin, value columns
DT <- DT[,.(value=mean(value)),by=variable] 
setnames(DT, c('bin', 'value'))

DT[,bin:=substr(bin, 1,3)]
DT[,bin:=gsub('_', '', bin)][,bin:=gsub('C', '', bin)][,bin:=gsub('n', '-', bin)]
DT[,bin:=ifelse(bin=='-I-', '-31', bin)]
DT[,bin:=as.integer(bin)]
setkey(DT, bin)
write_dta(DT,glue('{OUTPUT}/1_estimation/figures/Figure_D11/tavg_bins_collapsed_IND.dta'))
