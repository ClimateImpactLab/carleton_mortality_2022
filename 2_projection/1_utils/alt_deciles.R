
DECILES_OUTPUT = glue("{OUTPUT}/2_projection/figures/appendix/decile_plots")


alt_deciles_damages = function(
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
      quantiles = quantile(quantile_box$value, probs = c(0.25, 0.5, 0.75), na.rm = T)


      errors = data.frame(
        decile = q, #set position 
        lower = quantiles['25%'], 
        upper = quantiles['75%'],
        middle.median = quantiles['50%'],
        middle.mean = weighted.mean(damages_quantile_year$value, damages_quantile_year$pop)) #popweighted-mean

       quantiles.df = rbind(quantiles.df, errors) #combine into one df
    }

    if (covar == 'loggdppc') {
      xtit = '2015 Income Decile'
    } else if (covar == 'climtas') {
      xtit = '2015 Climate Decile'
    }

    p = ggplot(
        data=quantiles.df,
        aes(x=decile, y=middle.mean)) +
      geom_bar(
        position="stack",
        stat="identity",
        color=color.bar,
        fill=color.bar) +
      geom_errorbar(
        data = quantiles.df,  
        aes(x=decile, ymin = lower, ymax = upper), 
        color = "black",
        lty = "solid",
        width = 0,
        size = .8) +
      geom_abline(
        intercept=0,
        slope=0,
        size=.1,
        alpha = 0.5) +
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
      ggtitle(paste0(rcp,"-",ssp, "-", iam, "-", valuation, "-", scn)) 

    ggsave(p, file = glue("{output_dir}/damages_deciles_{valuation}_{scn}_{ssp}_{rcp}_{iam}_{covar}{suffix}_t2.{ftype}"), width = 6, height = 7)

  }
}




alt_deciles = function(
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
  # # clear environment and load libraries
  # rm(list=ls())

  # library(tidyverse)
  # library(dplyr)
  # library(reshape2)

  #setwd("~/Documents/CIL_server_downloads/mortality/ggplot graphs")

  # read and clean dataframes
  cov15 = read_csv("/home/sklos/charts/ctile_deciles_SSP3_low_rcp85_vly_2099_2015cov.csv") 
  cov99 = read_csv("/home/sklos/charts/ctile_deciles_SSP3_low_rcp85_vly_2099_2099cov.csv")
  hline_data <- data.frame(value = c(0))

  clim_15 = melt(cov15, id.vars=c("ctile", "q25", "q75", "median"),
              measure.vars=c("mean")) 

  clim_99 = melt(cov99, id.vars=c("ctile", "q25", "q75", "median"),
              measure.vars=c("mean")) 

  #clim_15 <- clim_dat %>% mutate(q75 = ifelse(decile == 10, 300, q75))

  #set ylim between -175 to 300

  p_15 <- ggplot(clim_15, aes(x=ctile, y=value, fill=variable)) +
    theme_bw() + geom_bar(position="stack", stat="identity") + 
    scale_fill_manual(values=c("#F3D1CD"), 
                      labels=c("Mean costs \n(VLY, 2019 USD)")) +
    geom_linerange(aes(ymax = q75, ymin=q25, 
                       colour = "Interquartile Range"), 
                   position = "identity") + 
    geom_point(aes(y=median, colour = "Median Value"), shape = 21, 
               size = 2, stroke = 1, fill = "white") + 
    scale_colour_manual(name = "", values = c("Interquartile range" = "black" ,
                                              "Median" = "black" )) +
    guides(colour = guide_legend(override.aes = list(linetype = c("blank", "solid"), 
                                                     shape = c(21, NA)))) + 
    geom_hline(aes(yintercept = value), hline_data, size = 0.4) + 
    theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank(),
          panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank(), 
          axis.title=element_text(size=16), axis.text=element_text(size=14),
          legend.text=element_text(size=14), legend.key.size = unit(2,"line")) + 
    labs(x = "2015 Average temperature decile", 
         y = "Adaptation Costs Impact of climate change in 2100 \n(VLY, 2019 USD)", 
         fill = "") + scale_x_continuous(breaks=1:10) # + ylim(c(-151, 300))

  p_15

  ggsave("/home/sklos/clim_deciles_2015_covs.pdf", plot = p_15, width = 9, height = 7)




  p_99 <- ggplot(clim_99, aes(x=ctile, y=value, fill=variable)) +
    theme_bw() + geom_bar(position="stack", stat="identity") + 
    scale_fill_manual(values=c("#F3D1CD"), 
                      labels=c("Mean costs \n(VLY, 2019 USD)")) +
    geom_linerange(aes(ymax = q75, ymin=q25, 
                       colour = "Interquartile Range"), 
                   position = "identity") + 
    geom_point(aes(y=median, colour = "Median Value"), shape = 21, 
               size = 2, stroke = 1, fill = "white") + 
    scale_colour_manual(name = "", values = c("Interquartile range" = "black" ,
                                              "Median" = "black" )) +
    guides(colour = guide_legend(override.aes = list(linetype = c("blank", "solid"), 
                                                     shape = c(21, NA)))) + 
    geom_hline(aes(yintercept = value), hline_data, size = 0.4) + 
    theme(panel.grid.major.x = element_blank(), panel.grid.minor.x = element_blank(),
          panel.grid.major.y = element_blank(), panel.grid.minor.y = element_blank(), 
          axis.title=element_text(size=16), axis.text=element_text(size=14),
          legend.text=element_text(size=14), legend.key.size = unit(2,"line")) + 
    labs(x = "2100 Average temperature decile", 
         y = "Adaptation Costs Impact of climate change in 2100 \n(VLY, 2019 USD)", 
         fill = "") + scale_x_continuous(breaks=1:10) # + ylim(c(-151, 300))

  p_99

  ggsave("/home/sklos/clim_deciles_2099_covs.pdf", plot = p_99, width = 9, height = 7)
}