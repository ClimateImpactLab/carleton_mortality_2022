##############################

# purpose : for India, obtain historical averages of population shares for the following age categories : 

	#0-4
	#5-64
	#65+

# input : 

	# world bank data, indicating historical (for each year) shares for : 
		# 0-14
		# 15-64
		# 65+

	# indian census data, indicating the 2001 shares of more detailed categorie, obtained from https://censusindia.gov.in/Census_And_You/age_structure_and_marital_status.aspx : 
		#0-4 : 10.7
		#5-9 : 12.5
		#10-14 : 12.1 


	# => the approach is to combine the two latter to obtain shares for the target age categories listed on the top of this explanatory header. 

# output : shares are printed and hardcoded into other script

##############################

REPO <- Sys.getenv(c("REPO"))
DB <- Sys.getenv(c("DB"))
OUTPUT <- Sys.getenv(c("OUTPUT"))

library(data.table)

DT <- lapply(X=paste0(glue("{DB}/1_estimation/1_ster/diagnostic_specs/age_share_IND_"),c(1,2,3),".csv"), FUN=function(x) as.data.table(read.csv(file=x, skip=4))[Country.Code=='IND'])
names(DT) <- c('0-14','15-64','65+')
DT <- lapply(DT, function(x) subset(x, select=paste0('X', seq(1960,2001))))
average_hist_shares <- sapply(DT, function(x) rowMeans(x))
stopifnot(sum(average_hist_shares)==100)

census_shares <- c("0-4"=10.7, "5-9"=12.5, "10-14"=12.1)

# therefore, in 2001 the share of 0-4 among 0-14 was 10.7/(10.7+12.5+12.1).
census_share_of_0_4 <- census_shares[1]/sum(census_shares)

#we assume this distribution was constant throughout the history and estimate the average historical 0-14 and 5-64 share:
average_hist_shares['0-4'] <- average_hist_shares['0-14'] * census_share_of_0_4
average_hist_shares['5-64'] <- average_hist_shares['15-64'] + average_hist_shares['0-14']*(1-census_share_of_0_4)
average_hist_shares <- average_hist_shares[c(3,4,5)]
stopifnot(sum(average_hist_shares)==100)
