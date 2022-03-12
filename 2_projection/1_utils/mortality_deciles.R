# Produces box-and-whisker plots of future mortality impacts of climate change
# by deciles of today's income and climate distributions (Figure VI).

DECILES_OUTPUT = glue("{OUTPUT}/2_projection/figures/appendix/decile_plots")

deciles_plot = function(
	covar,
	ssp='SSP3', 
	iam='low', 
	rcp='rcp85',
	scnlist=c('fulladaptcosts', 'fulladapt', 'costs'),
	year=2099, 
	baseline=2015,
	output_dir=DECILES_OUTPUT,
	demean=FALSE,
	suffix='',
	ftype='pdf') {
	
	#load impacts
	impacts_fin = wrap_mapply(
		scn=c('fulladaptcosts', 'fulladapt', 'costs'),
		FUN=get_mortality_impacts,
		MoreArgs=list(
			year_list=2099, as.DT=T,
			ssp=ssp, iam=iam, rcp=rcp))

	impacts_fin = rbindlist(impacts_fin, use.names=T, idcol='scn')
	impacts_fin = as.data.table(dcast(impacts_fin, region + year ~ scn, value.var='mean'))[, year:=NULL]
	impacts_fin=data.frame(impacts_fin)

	# Load Population (2015, 2099)
	pop.baseline = get_econvar('pop', iam=iam, ssp=ssp, year_list=baseline) %>%
		dplyr::select(region, pop)
	
	pop.EOC = get_econvar('pop', iam=iam, ssp=ssp, year_list=year) %>%
		dplyr::select(region, pop) 

	stopifnot(covar=='loggdppc' | covar=='climtas')
	#baseline pop-weighted deciles
	cov_path = glue('{DB}/2_projection/3_impacts/',
	    'main_specification/raw/single/{rcp}/CCSM4/{iam}/{ssp}')

	covariates = get_mortality_covariates(single_path=cov_path, year_list=2015) %>%
				dplyr::select(region, year, climtas, loggdppc)
	
	#merge in baseline population
	covariates = left_join(covariates, pop.baseline, by = "region")
	covariates$pop = covariates$pop/sum(covariates$pop)
	
	# Weighted quantiles.
	quantile_cov_box = data.frame(cov = rep(covariates[[covar]],
		times = covariates$pop*100000000))
	quantiles_cov = quantile(quantile_cov_box['cov'], probs = seq(0, 1, by = 0.1), na.rm = T)
	
	#assign values based on quantiles
	covariates$quantile = cut(covariates[[covar]], breaks = quantiles_cov, 
		labels = c("1","2","3","4","5","6","7","8","9","10"), include.lowest=TRUE)
							
	#merge deciles into main df
	impacts_fin = left_join(impacts_fin, covariates, by = "region")
	
	#count the number of impact regions in each quantile
	total = 0
	for (qt in 1:10){
		count = length(unique(impacts_fin$region[impacts_fin$quantile==qt]))
		print(paste0("There are ", count, " impact regions in decile ", qt))
		total = total + count
	}
	
	xlabel = glue('{baseline} {covar} Decile')

	
	# If TRUE, demean each impact by its IR's gcm-weighted mean
	if (demean){
	
		# Calculate each IR's gcm-weighted mean per year
		sum_wts_ir = sum(impacts_fin$weight)/length(unique(impacts_fin$region)) 
		
		# multiply value by weight and normalize weights because they don't sum to one, 
		# and get the average value across the batches for each year per IR
		impacts_fin_year = aggregate(
			list(mean.fulladaptcosts = (impacts_fin$fulladaptcosts*impacts_fin$weight/sum_wts_ir), 
				mean.costs = (impacts_fin$costs*impacts_fin$weight/sum_wts_ir), 
				mean.fulladapt = (impacts_fin$fulladapt*impacts_fin$weight/sum_wts_ir)), 
			by = list(year = impacts_fin$year, region = impacts_fin$region), FUN = sum, na.rm = T) 
		
		#merge IR means into impacts_fin
		impacts_fin = left_join(impacts_fin, impacts_fin_year, by = c("region", "year"))
		
		#demean each impact
		impacts_fin$fulladaptcosts = impacts_fin$fulladaptcosts - impacts_fin$mean.fulladaptcosts
		impacts_fin$fulladapt = impacts_fin$fulladapt - impacts_fin$mean.fulladapt
		impacts_fin$costs = impacts_fin$costs - impacts_fin$mean.costs

		impacts_fin = impacts_fin %>%
			dplyr::select(year, batch, gcm, region, 
				loggdppc, quantile, costs, fulladapt, fulladaptcosts)
		suffix = paste0('_demean', suffix)
	}

	#Create boxplots for each decile
	for (adapt in scnlist) {
		
		quantiles.df = c()
		
		for (q in 1:10) { #loop over quantiles
			
			print(paste("subsetting to quantile", q))
						
			#subset to decile
			impacts_quantile = dplyr::filter(impacts_fin, quantile == q)
			
			length(unique(impacts_quantile$region))
			
			if (adapt == "fulladapt"){
				impacts_quantile$value = impacts_quantile$fulladapt
				color.bar = "#CF3E57"
			} else if (adapt == "fulladaptcosts"){
				impacts_quantile$value = impacts_quantile$fulladaptcosts
				color.bar = "#9A263A"
			} else if (adapt == "costs"){
				impacts_quantile$value = impacts_quantile$costs
				color.bar = "#F3D1CD"
			} else { #share
				impacts_quantile$value = impacts_quantile$costs/impacts_quantile$fulladaptcosts
			}

			# Calculate 2099 pop-weighted median and quantiles.
			impacts_quantile_year = impacts_quantile %>%
				dplyr::select(-pop) %>%
				left_join(pop.EOC, by = c("region")) 
			impacts_quantile_year$pop = impacts_quantile_year$pop/sum(impacts_quantile_year$pop) 
			quantile_box = data.frame(value = rep(impacts_quantile_year$value, times = impacts_quantile_year$pop*100000000)) 
			quantiles = quantile(quantile_box$value, probs = c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), na.rm = T)
			
			whisker = data.frame(
				decile = q, #set position 
				minerrorbar = quantiles['5%'],
				maxerrorbar = quantiles['95%'],
				ymin = quantiles['10%'], 
				ymax = quantiles['90%'], 
				lower = quantiles['25%'], 
				upper = quantiles['75%'],
				middle.median = quantiles['50%'],
				middle.mean = weighted.mean(impacts_quantile_year$value, impacts_quantile_year$pop)) #popweighted-mean

			 quantiles.df = rbind(quantiles.df, whisker) #combine into one df
			 
		}

		if (covar == 'loggdppc') {
			xtit = '2015 Income Decile'
		} else if (covar == 'climtas') {
			xtit = '2015 Climate Decile'
		}
			
		p = ggplot() + 
			geom_errorbar(
				data = quantiles.df,  
				aes(x=decile, ymin = ymin, ymax = ymax), 
				color = "black",
				lty = "solid",
				width = 0,
				#alpha = 0.5,
				size = .8) +
			geom_boxplot(
				data = quantiles.df, 
				aes(group=decile, x=decile, ymin = lower, ymax = upper, 
					lower = lower, upper = upper, middle = middle.median), 
				fill=color.bar, 
				color=color.bar,
				size = 0,
				stat = "identity") + #boxplot 
			geom_point(
				data = quantiles.df, 
				aes(x=decile, y = middle.mean, group = 1), 
				size=2,
				stroke=1,
				fill="white", 
				color="black",
				shape=21, 
				alpha = 0.9) +
			geom_abline(intercept=0, slope=0, size=0.1, alpha = 0.5) + 
			scale_fill_gradientn(
				colors = rev(brewer.pal(9, "RdGy"))) + 
			scale_color_gradientn(
				colors = rev(brewer.pal(9, "RdGy"))) + 
			scale_x_discrete(limits=seq(1,10),breaks=seq(1,10)) +
			theme_bw() +
			theme() +
			theme(
				panel.grid.major = element_blank(), 
				panel.grid.minor = element_blank(),
				panel.background = element_blank(),
				legend.position="none",
				axis.line = element_line(colour = "black")) +
			xlab(xtit) +
			ylab("Change in deaths per 100,000 population") +
			ggtitle(paste0(rcp,"-",ssp, "-", iam, "-", adapt)) # +
			# coord_cartesian(ylim = c(-350, 600))  

		ggsave(p, file = glue("{output_dir}/deciles_{adapt}_{ssp}_{rcp}_{iam}_{covar}{suffix}_test.{ftype}"), width = 6, height = 7)
		
	}
}



deciles_damages_plot = function(
	covar,
	ssp='SSP3', 
	iam='low', 
	rcp='rcp85',
	scnlist=c('deathcosts', 'deaths', 'costs'),
	valuation='vly_epa_scaled',
	year=2099, 
	baseline=2015,
	output_dir=DECILES_OUTPUT,
	demean=FALSE,
	suffix='',
	ftype='pdf') {
	
	#load impacts
	damages_fin = wrap_mapply(
		scn=scnlist,
		FUN=get_mortality_damages,
		MoreArgs=list(
			year_list=2099, as.DT=T,
			ssp=ssp, iam=iam, rcp=rcp,
			valuation=valuation))

	# change column names so rbindlist works
	for (s in scnlist) {
		setnames(damages_fin[[s]], glue("monetized_{s}_{valuation}_mean"), "mean")
	}

	damages_fin = rbindlist(damages_fin, use.names=T, idcol='scn')
	damages_fin = as.data.table(dcast(damages_fin, region + year ~ scn, value.var='mean'))[, year:=NULL]
	damages_fin = data.frame(damages_fin)

	# Load Population (2015, 2099)
	pop.baseline = get_econvar('pop', iam=iam, ssp=ssp, year_list=baseline) %>%
		dplyr::select(region, pop)
	
	pop.EOC = get_econvar('pop', iam=iam, ssp=ssp, year_list=year) %>%
		dplyr::select(region, pop) 

	stopifnot(covar=='loggdppc' | covar=='climtas')
	#baseline pop-weighted deciles
	cov_path = glue('{DB}/2_projection/3_impacts/',
	    'main_specification/raw/single/{rcp}/CCSM4/{iam}/{ssp}')

	covariates = get_mortality_covariates(single_path=cov_path, year_list=2015) %>%
				dplyr::select(region, year, climtas, loggdppc)
	
	#merge in baseline population
	covariates = left_join(covariates, pop.baseline, by = "region")
	covariates$pop = covariates$pop/sum(covariates$pop)
	
	# Weighted quantiles.
	quantile_cov_box = data.frame(cov = rep(covariates[[covar]],
		times = covariates$pop*100000000))
	quantiles_cov = quantile(quantile_cov_box['cov'], probs = seq(0, 1, by = 0.1), na.rm = T)
	
	#assign values based on quantiles
	covariates$quantile = cut(covariates[[covar]], breaks = quantiles_cov, 
		labels = c("1","2","3","4","5","6","7","8","9","10"), include.lowest=TRUE)
							
	#merge deciles into main df
	damages_fin = left_join(damages_fin, covariates, by = "region")
	
	#count the number of impact regions in each quantile
	total = 0
	for (qt in 1:10){
		count = length(unique(damages_fin$region[damages_fin$quantile==qt]))
		print(paste0("There are ", count, " impact regions in decile ", qt))
		total = total + count
	}
	
	xlabel = glue('{baseline} {covar} Decile')

	
	# If TRUE, demean each impact by its IR's gcm-weighted mean
	if (demean){
	
		# Calculate each IR's gcm-weighted mean per year
		sum_wts_ir = sum(damages_fin$weight)/length(unique(damages_fin$region)) 
		
		# multiply value by weight and normalize weights because they don't sum to one, 
		# and get the average value across the batches for each year per IR
		damages_fin_year = aggregate(
			list(mean.deathcosts = (damages_fin$deathcosts*damages_fin$weight/sum_wts_ir), 
				mean.costs = (damages_fin$costs*damages_fin$weight/sum_wts_ir), 
				mean.deaths = (damages_fin$deaths*impacts_fin$weight/sum_wts_ir)), 
			by = list(year = damages_fin$year, region = damages_fin$region), FUN = sum, na.rm = T) 
		
		#merge IR means into impacts_fin
		damages_fin = left_join(damages_fin, damages_fin_year, by = c("region", "year"))
		
		#demean each impact
		damages_fin$fulladaptcosts = damages_fin$deathcosts - damages_fin$mean.deathcosts
		damages_fin$deaths = damages_fin$deaths - damages_fin$mean.deaths
		damages_fin$costs = damages_fin$costs - damages_fin$mean.costs

		damages_fin = damages_fin %>%
			dplyr::select(year, batch, gcm, region, 
				loggdppc, quantile, costs, fulladapt, fulladaptcosts)
		suffix = paste0('_demean', suffix)
	}

	#Create boxplots for each decile
	for (scn in scnlist) {
		
		quantiles.df = c()
		
		for (q in 1:10) { #loop over quantiles
			
			print(paste("subsetting to quantile", q))
						
			#subset to decile
			damages_quantile = dplyr::filter(damages_fin, quantile == q)
			
			length(unique(damages_quantile$region))
			
			if (scn == "deaths"){
				damages_quantile$value = damages_quantile$deaths
				color.bar = "#CF3E57"
			} else if (scn == "deathcosts"){
				damages_quantile$value = damages_quantile$deathcosts
				color.bar = "#9A263A"
			} else if (scn == "costs"){
				damages_quantile$value = damages_quantile$costs
				color.bar = "#F3D1CD"
			} else { #share
				damages_quantile$value = damages_quantile$costs/damages_quantile$deathcosts
			}

			# Calculate 2099 pop-weighted median and quantiles.
			damages_quantile_year = damages_quantile %>%
				dplyr::select(-pop) %>%
				left_join(pop.EOC, by = c("region")) 
			damages_quantile_year$pop = damages_quantile_year$pop/sum(damages_quantile_year$pop) 
			quantile_box = data.frame(value = rep(damages_quantile_year$value, times = damages_quantile_year$pop*100000000)) 
			quantiles = quantile(quantile_box$value, probs = c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), na.rm = T)
			
			whisker = data.frame(
				decile = q, #set position 
				minerrorbar = quantiles['5%'],
				maxerrorbar = quantiles['95%'],
				ymin = quantiles['10%'], 
				ymax = quantiles['90%'], 
				lower = quantiles['25%'], 
				upper = quantiles['75%'],
				middle.median = quantiles['50%'],
				middle.mean = weighted.mean(damages_quantile_year$value, damages_quantile_year$pop)) #popweighted-mean

			 quantiles.df = rbind(quantiles.df, whisker) #combine into one df
			 
		}

		if (covar == 'loggdppc') {
			xtit = '2015 Income Decile'
		} else if (covar == 'climtas') {
			xtit = '2015 Climate Decile'
		}
			
		p = ggplot() + 
			geom_errorbar(
				data = quantiles.df,  
				aes(x=decile, ymin = ymin, ymax = ymax), 
				color = "black",
				lty = "solid",
				width = 0,
				#alpha = 0.5,
				size = .8) +
			geom_boxplot(
				data = quantiles.df, 
				aes(group=decile, x=decile, ymin = lower, ymax = upper, 
					lower = lower, upper = upper, middle = middle.median), 
				fill=color.bar, 
				color=color.bar,
				size = 0,
				stat = "identity") + #boxplot 
			geom_point(
				data = quantiles.df, 
				aes(x=decile, y = middle.mean, group = 1), 
				size=2,
				stroke=1,
				fill="white", 
				color="black",
				shape=21, 
				alpha = 0.9) +
			geom_abline(intercept=0, slope=0, size=.1, alpha = 0.5) + 
			scale_fill_gradientn(
				colors = rev(brewer.pal(9, "RdGy"))) + 
			scale_color_gradientn(
				colors = rev(brewer.pal(9, "RdGy"))) + 
			scale_x_discrete(limits=seq(1,10),breaks=seq(1,10)) +
			theme_bw() +
			theme() +
			theme(
				panel.grid.major = element_blank(), 
				panel.grid.minor = element_blank(),
				panel.background = element_blank(),
				legend.position="none",
				axis.line = element_line(colour = "black")) +
			xlab(xtit) +
			ylab("Change in Monetized Deaths, 2019 USD") +
			ggtitle(paste0(rcp,"-",ssp, "-", iam, "-", valuation, "-", scn))# + 
			#coord_cartesian(ylim = c(-350, 600))  +

		ggsave(p, file = glue("{output_dir}/damages_deciles_{valuation}_{scn}_{ssp}_{rcp}_{iam}_{covar}{suffix}_test.{ftype}"), width = 6, height = 7)
		
	}
}
