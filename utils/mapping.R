# This script contains 2 functions:

# load.map() loads map and returns a dataframe 
# join.plot.map() joins your impact-region level data to the map & plots the data

# Applicable to any variable (including impact maps, beta maps and spatial scc maps)

# Updated 4 Jun 2019 by Trinetta Chong 

# Packages to install: 
# install.packages(c("rgdal", "rgeos", "raster", "rnaturalearth", 
# "RColorBrewer", "scales")) #packages specific to this mapping code

# library(ggplot2)
# library(dplyr) #left_join, filter
# library(magrittr) #%>%
# library(rgdal) #readOGR, spTransform
# library(rgeos) #gBuffer
# library(raster) #area
# library(rnaturalearth) #lakes
# library(RColorBrewer) #hex color codes from color palettes

#Arguments

#load.map()
# Optional Arguments
# shploc: the directory on Sacagawea which contains the shapefile, if you're 
# running it from your local system, you need to put in your own path 
# 
# shpname: the name of the shapefile (default: "new_shapefile")

#join.plot.map()

#Essential Argurments
##*map.df: the map dataframe obtained from running load.map() 
##*df: your data, it should have only one observation per impact region 
##(dataframe with <=24378 rows)
##*df.key: variable in your dataframe that identifies each spatial 
##unit (string character, default: "hierid")
##*map.key: variable in shapefile df that identifies each spatial unit 
##(string character, default: "id")
##*plot.var: variable to be plotted in map (string character)
##*topcode: limit color bar and mapping to a specified range of values (default: F)
##*topcode.ub: value of upper limit on color bar 
##(numeric,e.g. 0.005 default: NULL)
##*round.minmax: number of digits to round your minimum/maximum value 
##to (in the caption) (default: 4)
##*color.scheme: 
    #* "div" - diverging e.g. negative values in blue to lightgrey for zero to 
    ##  positive values in red  (string character, default: blue to grey to red) 
    #* "seq" - sequential, e.g. minimum value in light blue to maximum value in
    ## dark blue (string character, default: blues)
    #* "cat" - categorical e.g. blue for category 1, red for category 2
    ## (string character, default: 2 categories, one in blue, one in red )
##*colorbar.title: title of colorbar (string character)
##*map.title: title of map (string character)

# Optional Arguments
# barwidth: how wide the color bar will be (default: 100mm)
#*topcode.lb: value of lower limit on color bar (numeric, default: -topcode.ub)
#*rescale_val: scale values for color bar (numeric vector)
#* "div" - default: `c(topcode.lb, 0, topcode.ub)` middle color takes on the 
##value of zero 
#* "seq" or "cat" - default: NULL
#*breaks_labels_val (only for "div" or "seq"): set frequency of ticks on color 
##bar (numeric vector, default: `seq(topcode.lb, topcode.ub, topcode.ub/5)``
#*breaks_labels_val_cat (only for "cat"): label of each factor on color legend 
##(string vector, e.g. `c("Group1", "Group2", Group3")` 
##default: `levels(shp_plot$mainvar_lim)`
#*color.values: colors on color bar
#* "div" - string vector, default: 
##rev(c("#d7191c", "#fec980", "#ffedaa","grey95", "#e7f8f8", "#9dcfe4", "#2c7bb6"))
#* "seq" - string vector, default: `c("#2c7bb6", "#d7191c")` ()
#* "cat" - string vector default: `c("#2c7bb6", "purple4") because Barney
#*na.color: color of IRs with NA values (string character, default: "grey85")
#*lakes.color: color of waterbodies on map (string character, default: "white")


DEFAULT_CRS = glue("+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84",
    " +datum=WGS84 +units=m +no_defs")

DEFAULT_SHPLOC = glue("{DB}/2_projection/1_regions/ir_shp")
DEFAULT_SHPNAME = "impact-region"


load.map = function(
    shploc = DEFAULT_SHPLOC, 
    shpname = DEFAULT_SHPNAME,
    map.crs = DEFAULT_CRS) {

    message("Loading world shapefile...")
    
    #list of water bodies to exclude from map
    lakeslist = list("CA-","ATA")
    
    #load CIL impact-region map
    shp_master = readOGR(
            dsn = shploc,
            layer = shpname,
            stringsAsFactors = FALSE) %>% 
        spTransform(CRS(map.crs)) %>%
        gBuffer(byid=TRUE, width=0) 

    area = data.frame(
        id = shp_master$hierid, 
        area_sqkm = (raster::area(shp_master) / 1000000))

    shp_master = ggplot2::fortify(shp_master,region="hierid")  %>% #
        dplyr::left_join(area, by = c("id")) %>% 
        dplyr::filter(!(id %in% lakeslist))

    message("Map loaded.")
    return(shp_master)
}

load.saved.map <- function(){

    read_fst('/shares/gcp/estimation/mortality/release_2020/data/2_projection/1_regions/ir_shp/impact-region-processed.fst')
}

join.plot.map = function(
    map.df = NULL, df = NULL, df.key = "hierid", map.key = "id",  
    plot.var = NULL, topcode = F, topcode.ub = NULL, topcode.lb = NULL, 
    round.minmax = 4,  color.scheme = NULL, rescale_val = NULL,
    limits_val = NULL, breaks_labels_val = NULL, cities.plot = NULL,
    breaks_labels_val_cat = levels(shp_plot$mainvar_lim), 
    bar.width = unit(100, units = "mm"), lakes.color = "white",
    colorbar.title = NULL, map.title = NULL, na.color = "grey85",
    color.values = NULL, minval = NULL, maxval = NULL, plot.lakes = T, 
    crosshatch = F, map.crs = DEFAULT_CRS){
        
    message(glue("Joining data to world shapefile by: {map.key} and {df.key}."))
    shp_plot = left_join(map.df, df, by = setNames(nm = map.key, df.key))
    
    shp_plot['mainvar'] = shp_plot[plot.var]
    
    #identify IRs that don't have values
    na.df = dplyr::filter(shp_plot, is.na(mainvar))

    #identify IRs with negative values
    neg.df = dplyr::filter(shp_plot, mainvar < 0)
    neg.df = dplyr::filter(neg.df, hole==FALSE)
    
    message("setting parameters for plotting...")
    
    #recode limits so it takes max color if it exceeds +-value
    if (topcode) { 

        message(glue("plotting topcoded map... Remember to also look at a",
            "non-topcoded version! Just set topcode=FALSE to do so."))

        #if user didn't specify topcode.lb value, set default
        if (is.null(topcode.lb))
            topcode.lb = -topcode.ub

        shp_plot$mainvar_lim = squish(
            shp_plot$mainvar, c(topcode.lb, topcode.ub))

        limits_val = c(topcode.lb, topcode.ub)

        if (is.null(breaks_labels_val))
            breaks_labels_val = seq(
                topcode.lb,
                topcode.ub,
                abs(topcode.ub-topcode.lb)/5)

    } else { 

        shp_plot$mainvar_lim = shp_plot$mainvar
        
        maxi = max(max(shp_plot$mainvar, na.rm=TRUE))
        mini = min(min(shp_plot$mainvar, na.rm=TRUE))

        topcode.ub = ifelse(maxi >= 1, ceiling(maxi), maxi)
        topcode.lb = ifelse(mini <= -1, floor(mini), mini)
        
        bound = max(abs(topcode.ub), abs(topcode.lb))

        if (sign(topcode.ub) == sign(topcode.lb) |
            topcode.ub == 0 |
            topcode.lb == 0) {

            limits_val = ifelse(
                topcode.ub > 0,
                yes=list(c(0, bound)),
                no=list(c(-bound, 0)))[[1]]

            if(is.null(breaks_labels_val))
                breaks_labels_val = ifelse(
                    topcode.ub > 0,
                    list(seq(0, bound, bound/5)),
                    list(seq(-bound, 0, bound/5)))[[1]]

        } else {
            limits_val = round(c(-bound, bound), round.minmax)

            if (is.null(breaks_labels_val))
                breaks_labels_val = round(
                    seq(-bound, bound, 2*bound/5),
                    round.minmax)
            
        }     
    }
    
    #set min and max value for caption
    if (is.null(minval))
        minval = round(min(shp_plot$mainvar, na.rm = T), digits = round.minmax) 
    
    if (is.null(maxval))
        maxval = round(max(shp_plot$mainvar, na.rm = T), digits = round.minmax) 
    
    caption_val = glue("Min: {minval}    Max: {maxval}")
    
    if (color.scheme=="div") {

        #scale value for color bar, middle color "grey95" takes on value ~0  
        if (is.null(color.values))
        color.values = rev(c("#d7191c", "#fec980", "#ffedaa",
            "grey95", "#e7f8f8", "#9dcfe4", "#2c7bb6"))
        
    } else if (color.scheme=="seq") {

        if (is.null(color.values))
        color.values = rev(c("#c92116", "#ec603f", "#fd9b64",
            "#fdc370", "#fee69b","#fef7d1", "#f0f7d9"))
        
    } else {

        if (is.null(color.values))
            color.values = brewer.pal(6, "Set1")
        
        shp_plot$mainvar_lim = as.factor(shp_plot$mainvar_lim)
    }
    
    if (is.null(limits_val))
        limits_val = round(c(minval, maxval), round.minmax)
    
    if (is.null(breaks_labels_val))
        breaks_labels_val = round(
            seq(minval, maxval, abs(maxval)/10),
            round.minmax)
    
    message("Plotting map...")
    
    # Plot map.
    p.map = ggplot(data = shp_plot, aes(x=long, y=lat)) +
        geom_polygon(aes(group=group, fill=mainvar_lim)) + 
        geom_polygon(data = na.df, aes(group=group), fill = na.color) + 
        coord_equal() +
        theme_bw() +     
        theme(plot.title = element_text(hjust=0.5, size = 10), 
            plot.caption = element_text(hjust=0.5, size = 7), 
            legend.title = element_text(hjust=0.5, size = 10), 
            legend.position = "bottom",
            legend.text = element_text(size = 7),
            axis.title= element_blank(), 
            axis.text = element_blank(),
            axis.ticks = element_blank(),
            panel.grid = element_blank(),
            panel.border = element_blank()) +   
        labs(title = map.title, caption = caption_val) 
    
    
    if (crosshatch){

        p.map = p.map +
            geom_polygon_pattern(data=neg.df, aes(group=group), pattern='stripe', fill=NA, color=NA,
                pattern_fill=NA, pattern_color="black", size=.01, pattern_density=.01, pattern_spacing=.025, alpha=.2)
    }

    if (plot.lakes){
        
        #load lakes
        lakes10 = ne_download(
                scale = 110,
                type = 'lakes',
                category = 'physical') %>%
            spTransform(CRS(map.crs)) %>% 
            fortify(lakes10, region = "name")

        lakes = dplyr::filter(lakes10, 
            lakes10$lat <= max(map.df$lat) &
            lakes10$lat >= min(map.df$lat) &
            lakes10$long <= max(map.df$long) &
            lakes10$long >= min(map.df$long))
        
        p.map = p.map + 
            geom_polygon(data = lakes,
                aes(x=long, y=lat, group=group), fill=lakes.color)
    }
    
    if(color.scheme=="div" | color.scheme=="seq"){ 
        
        p.map = p.map + scale_fill_gradientn(
            colors = color.values,
            values=rescale(rescale_val),
            na.value = na.color,
            limits = limits_val, #center color scale so white is at 0
            breaks = breaks_labels_val, 
            labels = breaks_labels_val, #set freq of tick labels
            guide = guide_colorbar(title = colorbar.title,
                 direction = "horizontal",
                 barheight = unit(4, units = "mm"),
                 barwidth = bar.width,
                 draw.ulim = F,
                 title.position = 'top',
                 title.hjust = 0.5,
                 label.hjust = 0.5))
        
    } else { #color.scheme=="cat"
        
        p.map = p.map + scale_fill_manual( 
            values = color.values,
            name = colorbar.title,
            na.value = na.color, 
            breaks = levels(shp_plot$mainvar_lim), 
            labels = breaks_labels_val_cat) +   
            labs(caption = NULL)  
        
    } 

    if (!is.null(cities.plot)) {
            
            # crs of lat long coordinates in world.cities database
            cities.crs = '+proj=longlat +datum=WGS84 +no_defs'

            # loading and cleaning city data for plotting
            cities = filter(world.cities, name %in% cities.plot)
            coordinates(cities) = c("long", "lat")
            proj4string(cities) = CRS(cities.crs)
            cities.projected = spTransform(cities, CRS(map.crs))
            plot.cities = as.data.frame(cities.projected)

            # add cities to plot
            p.map = p.map + 
                geom_point(
                    data= plot.cities,
                    aes(group= name), shape=18, colour = "black", size = 3)
    }
    
    rm(shp_plot)
    return(p.map)
    
}
    
    
