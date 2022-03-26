# Produces box-and-whisker plots of future mortality impacts of climate change
# by deciles of today's income and climate distributions (Figure VI).

DECILES_OUTPUT = glue("{OUTPUT}/figures/Figure_6_deciles")


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
	ftype='pdf',
	trimclim=TRUE) {
	
	# create output directory
	dir.create(output_dir, showWarnings = FALSE)

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



	quantiles.df = c()

	#Create boxplots for each decile		
	for (q in 1:10) { #loop over quantiles
		
		print(paste("subsetting to quantile", q))
					
		#subset to decile
		impacts_quantile = dplyr::filter(impacts_fin, quantile == q)
		
		length(unique(impacts_quantile$region))
		

		# Calculate 2099 pop-weighted median and quantiles.
		impacts_quantile_year = impacts_quantile %>%
			dplyr::select(-pop) %>%
			left_join(pop.EOC, by = c("region")) 
		impacts_quantile_year$pop = impacts_quantile_year$pop/sum(impacts_quantile_year$pop) 
		quantile_box = data.frame(value = rep(impacts_quantile_year$fulladaptcosts, times = impacts_quantile_year$pop*100000000)) 
		quantiles = quantile(quantile_box$value, probs = c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99), na.rm = T)
		
		# each row has decile name, FAC quantiles, and popweighted-means
		row = data.frame(
			decile = q, #set position 
			minerrorbar = quantiles['25%'],
			maxerrorbar = quantiles['75%'],
			fulladaptcosts = weighted.mean(impacts_quantile_year$fulladaptcosts, impacts_quantile_year$pop),
			fulladapt = weighted.mean(impacts_quantile_year$fulladapt, impacts_quantile_year$pop),
			costs = weighted.mean(impacts_quantile_year$costs, impacts_quantile_year$pop))

		 quantiles.df = rbind(quantiles.df, row) #combine into one df		 
	}

	hline_data <- data.frame(value = c(0))

	# reshape data
	quantiles.rs = melt(quantiles.df, id.vars=c("decile", "minerrorbar", "maxerrorbar", "fulladaptcosts"),
            measure.vars=c("costs", "fulladapt"))

    # aesthetic change for paper version to limit yaxis for decile 10
    
    # set chart titles and colors
    if (covar == "loggdppc"){
    	xtit = "2015 Income decile"
    	clist = c("powderblue", "#01838C")
    } else if (covar == "climtas"){
    	# aesthetic change for paper version to limit yaxis for decile 10
    	if (trimclim){
    		quantiles.rs <- quantiles.rs %>% mutate(maxerrorbar = ifelse(decile == 10, 300, maxerrorbar))
    	}
    	xtit = "2015 Average temperature decile"
    	clist = c("#F3D1CD", "#CF3E57")
    }

    # plot
    p <- ggplot(quantiles.rs, aes(x=decile, y=value, fill=variable)) +
	  theme_bw() + geom_bar(position="stack", stat="identity") + 
	  scale_fill_manual(values=clist, 
	                    labels=c("Adaptation costs \n(death equivalents)", "Deaths")) +
	  geom_linerange(aes(ymax = maxerrorbar, ymin=minerrorbar, 
	                     colour = "Interquartile range"), 
	                 position = "identity") + 
	  geom_point(aes(y=fulladaptcosts, colour = "Full mortality risk of \nclimate change (mean)"), shape = 21, 
	             size = 2, stroke = 1, fill = "white") + 
	  scale_colour_manual(name = "", values = c("Interquartile range" = "black" ,
	                                            "Full mortality risk of \nclimate change (mean)" = "black" )) +
	  guides(colour = guide_legend(override.aes = list(linetype = c("blank", "solid"), 
	                                                   shape = c(21, NA)))) + 
	  geom_hline(aes(yintercept = value), hline_data, size = 0.4) + 
	  theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank(),
	        panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank(), 
	        axis.title=element_text(size=16), axis.text=element_text(size=14),
	        legend.text=element_text(size=14), legend.key.size = unit(2,"line")) + 
	  labs(x = xtit, 
	       y = "Impact of climate change in 2100 \n(deaths per 100,000 population)", 
	       fill = "") + ylim(c(-151, 300)) + scale_x_continuous(breaks=1:10)

	p

	ggsave(p, file=glue("{output_dir}/deciles_{ssp}_{rcp}_{iam}_{covar}{suffix}.{ftype}"), width = 9, height = 7)
 }


