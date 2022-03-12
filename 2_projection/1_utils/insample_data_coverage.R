# Purpose: Generates Figure B1 in Carleton et al. (2022), 
# which shows the geographic and temporal coverage of subnational mortality records used throughout the analysis. 

INSAMPLE_DAT_OUTPUT = glue('{OUTPUT}/2_projection/figures/Figure_B1_data_coverage')

insample_data_coverage = function(output_dir=INSAMPLE_DAT_OUTPUT) {

    SHP_INSAMPLE = list(
        dir=glue("{DB}/1_estimation/3_regions/insample_shp"),
        name="mortality_insample_world")

    SHP_WORLD = list(
        dir=glue("{DB}/1_estimation/3_regions/world_shp"),
        name="world_countries_2017_simplified")

    df = read.csv(glue("{DB}/1_estimation/3_regions/mortality_datacoverage.csv")) %>%
        arrange(desc(start))

    df$iso_factor = factor(
        df$iso,
        ordered = TRUE,
        levels = c("IND", "USA", "JPN", "MEX", "EU", "CHN", "CHL", "BRA", "FRA"))

    # load insample shapefile
    crs_str = "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"
    shp_cov = readOGR(
            dsn = SHP_INSAMPLE[['dir']],
            layer = SHP_INSAMPLE[['name']],
            stringsAsFactors = FALSE) %>%
        spTransform(CRS(crs_str)) %>%
        gBuffer(byid=TRUE, width=0) %>%
        subset(id > 14904 | id < 14884) 
    iso = data.frame(id = shp_cov$id, adm2_id = seq.int(nrow(shp_cov)), iso = shp_cov$iso)
    shp_cov = fortify(shp_cov, region="id") %>% 
        left_join(iso, by = c("id")) 

    shp_world = readOGR(
            dsn=SHP_WORLD[['dir']], 
            layer=SHP_WORLD[['name']]) %>%
        spTransform(CRS(crs_str)) %>%
        gBuffer(byid=TRUE, width=0) %>%
        fortify(region="CNTRY_CODE")

    color.values = brewer.pal(11, "Spectral") 
    color.values = color.values[!color.values %in% c("#FFFFBF", "#E6F598")]
    color.values = rev(color.values) 

    # map of coverage
    p = ggplot() +
        geom_polygon(
            data=shp_world, 
            aes(x=long, y=lat, group=group), 
            fill="grey85") +
        geom_polygon(
            data=shp_cov,
            aes(x=long, y=lat, group=group, fill = iso),
            alpha = 0.7) + 
        geom_path(
            data = shp_cov,
            aes(x = long, y = lat, group = group),
            color = "white",
            size=0.03) +  
        coord_equal() + 
        theme_bw() + 
        theme(
            plot.title = element_text(hjust=0.5, size = 10),
            plot.caption = element_text(hjust=0.5, size = 7), 
            legend.position="none", 
            axis.title= element_blank(), 
            axis.text = element_blank(),
            axis.ticks = element_blank(), 
            panel.grid = element_blank(),
            panel.border = element_blank()) +
        labs(
            title = paste0("Spatial and temporal coverage of the mortality statistics",
                " used in estimation of temperature-mortality relationships.")) +
        scale_fill_manual(values = color.values) +
        scale_color_manual(values = color.values)

    ggsave(p, filename = glue("{output_dir}/country_spacecoverage_map.png"),
        dpi = 2000, width = 8, height = 6)

    # line chart of time series coverage
    df = df %>%
        tidyr::gather(key=ts, value=year, c(start, end)) %>% 
        arrange(desc(name), year) %>%
        mutate(name = factor(name, ordered=TRUE)) 

    EU = data.frame(
        iso_factor = c("EU", "EU"), 
        year = c(1990, 2000))

    b2 = ggplot(data = df) + 
        geom_line(
            aes(x=year, y=iso_factor),
            size = 0.8) +
        geom_point(
            shape = "circle",
            aes(x=year, y=iso_factor)) +
        geom_line(
            data = EU,
            linetype = "dashed",
            aes(x=year, y=iso_factor),
            size =0.8) + 
        geom_point(
            data = EU,
            shape = "circle",
            aes(x=year, y=iso_factor)) +
        expand_limits(x = c(1950, 2020)) + 
        scale_x_continuous(breaks = seq(1950, 2020, by=10)) +
        geom_dl(
            aes(x=year, y=iso_factor, label=name),
            method = list(dl.trans(x = x + 0.2), "last.points", cex = 0.8)) + 
        theme_bw() + 
        theme(
            panel.border = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.title.y = element_blank(),
            axis.ticks.y = element_blank(),
            axis.text.y = element_blank(),
            axis.title.x = element_blank(),
            axis.line.x = element_line(color = "black"),
            legend.position = "none") +
        scale_fill_manual(values = color.values) +
        scale_color_manual(values = color.values)

    ggsave(b2, filename = glue("{output_dir}/country_timecoverage_lineplot.pdf"),
        width = 10, height = 2)
}
