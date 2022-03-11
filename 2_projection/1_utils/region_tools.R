# Handles the regional hierarchy in the analysis, e.g., impact regions, ADM1 
# agglomerations, countries. 


#' Checks spatial resolution of regions as defined by impact region definitions.
#' 
#' Determines whether input region is an impact region or a more aggregated 
#' region. 
#'
#' @param region_list vector of IRs, ISOs, or regional codes in between.
#' @return List containing region codes at ir_level or aggregated resolutions.
check_resolution = function(region_list) {

    out = list()

    check = memo.csv(glue('{DB}/2_projection/1_regions/hierarchy.csv')) %>%
        data.frame()

    list = check %>%
        dplyr::filter(region.key %in% region_list)

    if (nrow(list)==0 & !('' %in% region_list))
        stop('Region not found!')

    if (any(list$is_terminal))
        out[['ir_level']] = dplyr::filter(list, is_terminal)$region.key
    if (any(!(list$is_terminal)))
        out[['aggregated']] = dplyr::filter(list, !(is_terminal))$region.key
    if ('' %in% region_list)
        out[['aggregated']] = c(out[['aggregated']], '')


    return(out)
}


#' Translates key words into list of impact region codes.
#'
#' @param regions Regions, can be IRs or aggregated regions. Also accepts:
#' - all: all ~25k impact regions; 
#' - iso: country-level output; 
#' - global: global outputs; 
#' @return List of IRs or region codes.
return_region_list = function(regions) {

    check = memo.csv(glue('{DB}/2_projection/1_regions/hierarchy.csv')) %>%
        data.frame()

    list = check %>%
        dplyr::filter(is_terminal)

    if (length(regions) > 1)
        return(regions)

    if (regions == 'all')
        return(list$region.key)
    else if (regions == 'iso')
        return(unique(substr(list$region.key, 1, 3)))
    else if (regions == 'states'){
        df = list %>% 
            dplyr::filter(substr(region.key, 1, 3)=="USA") %>%
            dplyr::mutate(region.key = gsub('^([^.]*.[^.]*).*$', '\\1', region.key))
        return(unique(df$region.key))
    }
    else if (regions == 'global')
        return('')
    else
        return(regions)

}

#' Identifies IRs within a more aggregated region code.
#'
#' @param region_list Vect. of aggregated regions.
#' @return List of IRs associated with each aggregated region.
get_children = function(region_list) {

    check = memo.csv(glue('{DB}/2_projection/1_regions/hierarchy.csv')) %>%
        data.frame()

    list = dplyr::filter(check, region.key %in% region_list)$region.key

    if ('' %in% region_list)
        list = c('', list)

    term = check %>%
        dplyr::filter(is_terminal)

    substrRight = function(x, n) (substr(x, nchar(x)-n+1, nchar(x)))

    child = list()
    for (reg in list) {

        regtag = reg

        if (reg == '') {
            child[['global']] = term$region.key
            next
        }

        if (substrRight(reg, 1) != '.')
            reg = paste0(reg, '.')

        child[[regtag]] = dplyr::filter(
            term, grepl(reg, region.key, fixed=T))$region.key
    }

    return(child)
}