# GGSpaghetti Plot function

# Grey lines indicate predicted response functions for each impact region 
# The solid black line is the unweighted average across all regions
# Opacity indicates the density of realized temperatures between 2000 - 2009

TEMP_DEFAULT = glue('{DB}/2_projection/5_climate_data/',
    'GMFD_tavg_poly_1_2000_2009_daily_popwt.csv')

ggspaghetti <- function(df = NULL, region = NULL, tempdir=TEMP_DEFAULT, tempdata_lastdecade=TRUE,
    variable = NULL, temp.variable = NULL, estimated.variable = NULL,  get.ave=F,
    key = "hierid", covariate = NULL, x.label = "Temperature", y.label = NULL, 
    y.limits = NULL, x.limits = NULL){
    
    df <- as.data.table(df) #speedup with data table
    setkey(df, hierid) #same

    message('started cooking the spaghetti...')


    message('load daily GMFD temperature for each IR...')

    if(tempdata_lastdecade){
        temp <- fread(input=tempdir) #historical data from the last 10 years
        temp[,annualmean:=NULL] #useless variable

    } else {
        temp <- read_fst("/shares/gcp/climate/_spatial_data/impactregions/weather_data/dta/GMFD_tavg_poly_1_1950_2010_daily_popwt.fst", as.data.table=TRUE) #historical data from the last 50 years 
    }

    setkey(temp, hierid) #speedup
    setnames(df, c(variable, temp.variable, key),c('variable', 'temp.variable', 'key')) #standardize variable names

    if (is.null(x.limits)) 
        x.limits = c(df[,min(temp.variable)],df[,max(temp.variable)]) #set x axis to range of temperatures in df if left NULL

    message('subset GMFD daily tas into relevant IR...')

    if(length(region)==1){
        if (region == "Global" | region == "global") { #no subsetting case
            message('using all IRs...')
        }
        else if (nchar(region) == 3){ # iso subsetting case. we assumes nchar(region)==3 means region is an ISO code.
            temp <- temp[iso == region]
        }
    } else { # IR subsetting case. we assume that if region is vector, it's a vector of IR names
        temp <- temp[hierid %in% region]
    }

    temp[,iso:=NULL] #gaining dozens of GB of RAM
    gc() # clean up memory garbage. Unclear how often R does it automatically.
        
    message('reshape GMFD daily tas...')
    temp <- melt.data.table(temp, id.vars = c("hierid"),
        variable.name = "day_of_sample", 
        value.name = "temperature") #from wide to long => using 10GB more of RAM :/
    temp[,day_of_sample:=NULL] #memory efficiency again...
    gc() # clean up memory garbage
    temp <- temp[!is.na(temperature)] #there were are some NAs in the temperature data.


    message('find historically realized min/max for each IR...')
    setkey(temp, hierid)
    historical_range <- temp[,.(min=min(temperature, na.rm=T), max=max(temperature, na.rm=T)), by=hierid] 
    setkey(historical_range, 'hierid')

    message('computing temperature weights...')
    mymin <- df[,min(temp.variable)]
    mymax <- df[,max(temp.variable)]
    # generating factor variable indicating in which 1C interval (in between the min and max across IRs) a temperature observation is falling
    bins <- temp[,cut(temperature, seq(mymin, mymax+1), include.lowest=T)]
    # generating count of that factor var
    frequencies <- table(bins)
    # using those counts and computing frequency weights
    weights <- frequencies/sum(frequencies)
    # building data compatible with rest of code
    names(weights) <- as.character(seq(mymin, mymax))
    weights <- data.table(count_wt=as.numeric(weights), count=as.numeric(frequencies),temps=as.numeric(names(weights)))
    setkey(weights, temps)
    rm(bins) #memory efficiency
    gc() #clean up memory


    message('subsetting the responses to the historically realized temperatures of each IR...')
    setnames(historical_range, 'hierid', 'key') #here will merge min and max to historical data. data.table speed up. 
    setkey(historical_range, key)
    df <- historical_range[df]
    # 'clipping' happens here (each IR will have its own range for the response)
    df <- df[temp.variable<=max&temp.variable>=min]
    
    message('joining counts to main...')
    setnames(df, 'temp.variable', 'temps')
    setkey(df, temps)
    df <- weights[df]

    message('calculate average response across all IRs...')
    ave <- df[,.(ave=mean(variable, na.rm=TRUE)), by=temps]
    ave <- weights[ave] #merging the weights cause the code might use them after

    ave <- ave[temps %in% seq(x.limits[1], x.limits[2])] # keeping data falling in range for plot
    df <- df[temps %in% seq(x.limits[1], x.limits[2])] # same 

    setnames(df, 'temps', 'temp.variable')  

    df <- as.data.frame(df) #back to dataframe so that below works...
    temp <- as.data.frame(temp) 
    ave <- as.data.frame(ave)
    if (get.ave == T)
        return(ave)

    #base plot
    message('plotting...')
    p <- ggplot(data = df) +
        scale_alpha("count") +
        guides(alpha = FALSE) +
        geom_line(aes(x=temp.variable, y=0), colour = "black", alpha=0.3) +
        scale_colour_gradientn(colours=c("#FBC17D", "#81176D")) +
        theme_bw() +
        theme(
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(),
            panel.background = element_blank(), 
            axis.line = element_line(colour = "black")) +
        labs(color = covariate, x = x.label, y = y.label) +
        coord_cartesian(ylim = y.limits, xlim = x.limits) 
     #theme(legend.position = "None")
    
    #if estimated variable is not NULL, assign variable
    if (!is.null(estimated.variable)){ 
        
        est <- data.frame(
                key = df[,key], 
                est = df[,estimated.variable], 
                temps = df[,temp.variable], 
                count = df[,"count"]) %>%
            unique() #drop duplicates
        
        # Clip estimated response at the Country's historically 
        # realized max and min temp.
        est$est[df$temps > max(temp$temperature)] <- NA
        est$est[df$temps < min(temp$temperature)] <- NA
        
        if (nchar(region) == 3)
            p <- p + geom_line(
                data = est, 
                aes(x=temps, y=est, alpha = count), 
                color = "brown", 
                size = 1, show.legend = FALSE)
        else 
            p <- p + geom_line(
                data = est, 
                aes(x=temps, y=est, alpha = count, group = key), 
                color = "brown", size = 1, show.legend = FALSE)
        
    }
    
    #if covariate variable is not NULL, assign variable
    if (!is.null(covariate)){ 
        df$covariate <- df[,covariate]
        p <- p + geom_line(
            data = df,
            aes(x=temp.variable,
            y=variable, group = key,
            color=covariate, alpha = count), size = 0.05) 
    } else {
        p <- p + geom_line(
            data = df,
            aes(x=temp.variable, y=variable, group = key, alpha = count), #bug
            color= "grey70", size = 0.05)  
    }

    p <- p + geom_line(
        data = ave,
        aes(x=temps, y=ave, alpha = count),
        size = 1, show.legend = FALSE) 


    return(p)
    
}

