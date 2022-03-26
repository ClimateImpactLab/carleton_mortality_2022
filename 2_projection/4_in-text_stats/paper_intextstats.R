# Purpose: Generates in-text summary statistics for  Valuing the Global
# Mortality Consequences of Climate Change Accounting for Adaptation Costs
# and Benefits, Carleton et al. 2022
# 
# Outputs a text file containing each statisitic in the structure outlined below.
# 
# Organization of script:
# ----------------------
# 
# Section 1: Global mortality impacts
# Section 2: Impact-region level impacts
# Section 3: Marginal effect of a hot day (35C) for each age group
# Section 4: Monetized mortality damages as percent of GDP.
# Section 5: CPU-hours required for Monte Carlo simulations


rm(list = ls())

# Initialize paths, packages, and user functions.
REPO <- Sys.getenv(c("REPO"))
DATA <- Sys.getenv(c("DATA"))
OUTPUT <- Sys.getenv(c("OUTPUT"))

source(paste0(REPO, "/carleton_mortality_2022/2_projection/1_utils/load_utils.R"))

output_dir = glue("{OUTPUT}/tables/Table_2_impacts")
# create output directory
dir.create(output_dir, showWarnings = FALSE)

output.file = glue("{output_dir}/Table_2_stats_in-text.txt")

write_stats = function(id, description, value, output_file) {
    if (is.numeric(value))
        value = round(value, digits=3)
    print(glue('{id}. {description}: {value}'))
    write_var = glue('{id}. {description}: {value}')
    write(write_var, file=output_file, append=T)
}

# Toggles:
ssp = 'SSP3'
rcp = 'rcp85'
iam = 'low'

# Hiding some stats that are currently out of the paper but might return.
# Must be removed for code-release version.
deprecated = FALSE

# Section 1: Global mortality impacts.

write(glue('Valuing the Global Mortality Consequences of Climate Change, Accounting ',
    'for Adaptation Costs and Benefits: In-text summary statistics'), file=output.file)

# Load impacts from all adaptation scenarios.

# Full adaptation (Income and Climate adaptation).
full = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='fulladapt',
    regions='global',
    ssp=ssp,
    rcp=rcp,
    iam=iam)

# No adaptation.
noadapt = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='noadapt',
    regions='global',
    ssp=ssp,
    rcp=rcp,
    iam=iam)

# Income benefits.
incben = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='incbenefits',
    regions='global',
    ssp=ssp,
    rcp=rcp,
    iam=iam)

# Income adaptation only.
climben = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='climbenefits',
    regions='global',
    ssp=ssp,
    rcp=rcp,
    iam=iam)

# Income adaptation only.
costs = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='climbenefits',
    regions='global',
    ssp=ssp,
    rcp=rcp,
    iam=iam)

# Full adaptation (Income and Climate adaptation) plus adaptation costs.
fullcosts = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='fulladaptcosts',
    regions='global',
    ssp=ssp,
    rcp=rcp,
    iam=iam)

# Full adaptation (Income and Climate adaptation).
full.45 = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='fulladapt',
    regions='global',
    ssp=ssp,
    rcp='rcp45',
    iam=iam)

# No adaptation.
noadapt.45 = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='noadapt',
    regions='global',
    ssp=ssp,
    rcp='rcp45',
    iam=iam)

# Income benefits.
incben.45 = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='incbenefits',
    regions='global',
    ssp=ssp,
    rcp='rcp45',
    iam=iam)

# Income adaptation only.
climben.45 = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='climbenefits',
    regions='global',
    ssp=ssp,
    rcp='rcp45',
    iam=iam)

# Income adaptation only.
costs.45 = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='climbenefits',
    regions='global',
    ssp=ssp,
    rcp='rcp45',
    iam=iam)

# Full adaptation (Income and Climate adaptation) plus adaptation costs.
fullcosts.45 = get_mortality_impacts(
    qtile=c('mean', 'q25', 'q75'),
    scn='fulladaptcosts',
    regions='global',
    ssp=ssp,
    rcp='rcp45',
    iam=iam)


# Calculate summary statistics:

write('\n1. Global Mortality Impacts', file=output.file, append=T)

write('\n1.1.1. Global impact full adapt + cost in 2100, (RCP8.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 
# 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.1.1.{i}'),
    qt,
    fullcosts[fullcosts$year==2099, qt],
    output.file
    )
    i = i + 1
}

write('\n1.1.2/ Global impact full adapt in 2100, (RCP8.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 
# 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.1.2.{i}'),
    qt,
    full[full$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.1.3/ Global impact without adaptation in 2100, (RCP8.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.1.3.{i}'),
    qt,
    noadapt[noadapt$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.1.4/ Global benefits from income growth in 2100, (RCP8.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.1.4.{i}'),
    qt,
    incben[incben$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.1.5/ Global benefits from climate adaptation in 2100, (RCP8.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.1.5.{i}'),
    qt,
    climben[climben$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.1.6/ Global adaptation costs in 2100, (RCP8.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.1.6.{i}'),
    qt,
    costs[costs$year==2099, qt],
    output.file
    )
    i = i + 1
}


# Same as above but for rcp45


write('\n1.2.1. Global impact full adapt + cost in 2100, (RCP84.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 
# 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.2.1.{i}'),
    qt,
    fullcosts.45[fullcosts.45$year==2099, qt],
    output.file
    )
    i = i + 1
}

write('\n1.2.2/ Global impact full adapt in 2100, (RCP4.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 
# 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.2.2.{i}'),
    qt,
    full.45[full.45$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.2.3/ Global impact without adaptation in 2100, (RCP4.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.2.3.{i}'),
    qt,
    noadapt.45[noadapt.45$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.2.4/ Global benefits from income growth in 2100, (RCP4.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.2.4.{i}'),
    qt,
    incben.45[incben.45$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.2.5/ Global benefits from climate adaptation in 2100, (RCP4.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.2.5.{i}'),
    qt,
    climben.45[climben.45$year==2099, qt],
    output.file
    )
    i = i + 1
}


write('\n1.2.6/ Global adaptation costs in 2100, (RCP4.5, SSP3, IIASA-GDP)', 
    file=output.file, append=T)

# Note: we use 2099 rather than 2100 because some GCMs do not have data in 2100.
i = 1
for (qt in c('mean', 'q25', 'q75')) {
    write_stats(glue('1.2.6.{i}'),
    qt,
    costs.45[costs.45$year==2099, qt],
    output.file
    )
    i = i + 1
}






write_stats('1.3',
    "Share of total death equivalents atttributable to adaptation costs in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    (fullcosts$mean[fullcosts$year == 2099] - full$mean[full$year == 2099]) / 
        fullcosts$mean[fullcosts$year == 2099],
    output.file
    )

write_stats('1.4.1',
    "Ratio of no adaptation impacts to full adaptation impacts plus adaptation costs in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    noadapt$mean[noadapt$year == 2099]/fullcosts$mean[fullcosts$year == 2099],
    output.file
    )


write_stats('1.4.2',
    "Ratio of no adaptation impacts to full adaptation impacts without adaptation costs in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    noadapt$mean[noadapt$year == 2099]/full$mean[full$year == 2099],
    output.file
    )



# Section 2: Country level impacts

write('\n2. Country-level Mortality Impacts\n', file=output.file, append=T)

isos = c('CHN', 'USA', 'IND', 'PAK', 'BGD')
qtile = c('q25', 'mean', 'q75')

# RCP8.5
i = 1
for (scn in c('noadapt', 'incbenefits', 'climbenefits', 'fulladapt', 'costs', 'fulladaptcosts')) {

    # Load country-level impacts, 
    impacts_fin = get_mortality_impacts(
        qtile=qtile,
        scn=scn,
        regions=isos,
        year_list=c(2099),
        ssp=ssp,
        rcp='rcp85',
        iam=iam)

    j = 1
    for (iso in isos) {
        k = 1
        for (q in qtile) {
            write_stats(glue('2.1.{i}.{j}.{k}'),
                glue("{scn} impacts in 2100 {q} (RCP8.5, SSP3, IIASA-GDP): {iso}"),
                impacts_fin$mean[impacts_fin$region=={iso}],
                output.file
                )
            k = {k}+1           
        }
        j = {j}+1
    }
    i = {i}+1
}

# RCP4.5
i = 1
for (scn in c('noadapt', 'incbenefits', 'climbenefits', 'fulladapt', 'costs', 'fulladaptcosts')) {

    # Load country-level impacts, 
    impacts_fin = get_mortality_impacts(
        qtile=qtile,
        scn=scn,
        regions=isos,
        year_list=c(2099),
        ssp=ssp,
        rcp='rcp45',
        iam=iam)

    j = 1
    for (iso in isos) {
        k = 1
        for (q in qtile) {
            write_stats(glue('2.1.{i}.{j}.{k}'),
                glue("{scn} impacts in 2100 {q} (RCP4.5, SSP3, IIASA-GDP): {iso}"),
                impacts_fin$mean[impacts_fin$region=={iso}],
                output.file
                )
            k = {k}+1           
        }
        j = {j}+1
    }
    i = {i}+1
}



# Section 2: Impact-region level impacts

write('\n2. Impact Region-level Mortality Impacts\n', file=output.file, append=T)

# Load IR-level impacts, 
impacts_fin = get_mortality_impacts(
    qtile='mean',
    scn='fulladaptcosts',
    regions='all',
    year_list=c(2099),
    ssp=ssp,
    rcp=rcp,
    iam=iam)

# At the end of the century we project an increase of about XX death equivalents 
# annually in Accra, Ghana and a decrease of about YY annually in Berlin, DE (deaths per 100k)

write_stats('2.1',
    "Accra, Ghana fulladapt+costs deathrate impacts in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="GHA.5.70"],
    output.file
    )

write_stats('2.3',
    "Berlin, DE fulladapt+costs deathrate impacts in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="DEU.3.12.141"],
    output.file
    )
    
# Calculate % increase over today's mortality levels in Accra & Berlin (deaths per 100k); 
# Source: https://www.un.org/en/development/desa/population/publications/pdf/mortality/World-Mortality-2017-Data-Booklet.pdf, pages 12 & 15
write_stats('2.4',
    "Accra, Ghana % increase over today's mortality levels (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="GHA.5.70"]/(8.3*100)*100,
    output.file
    )

write_stats('2.6',
    "Berlin, DE % increase over today's mortality levels (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="DEU.3.12.141"]/(9.0*100)*100,
    output.file
    )

# Load IR-level impacts, not accounting for costs.
impacts_fin = get_mortality_impacts(
    qtile='mean',
    scn='fulladapt',
    regions='all',
    year_list=c(2099),
    ssp=ssp,
    rcp=rcp,
    iam=iam)


# At the end of the century we project an increase of about XX death equivalents 
# annually in Accra, Ghana and a decrease of about YY annually in Berlin, DE (deaths per 100k)

write_stats('2.7',
    "Accra, Ghana fulladapt deathrate impacts in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="GHA.5.70"],
    output.file
    )

write_stats('2.9',
    "Berlin, DE fulladapt deathrate impacts in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="DEU.3.12.141"],
    output.file
    )

# Calculate % increase over today's mortality levels in Accra & Berlin (deaths per 100k); 
# Source: https://www.un.org/en/development/desa/population/publications/pdf/mortality/World-Mortality-2017-Data-Booklet.pdf, pages 12 & 15
write_stats('2.10',
    "Accra, Ghana % increase over today's mortality levels without accounting for costs (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="GHA.5.70"]/(8.3*100)*100,
    output.file
    )

write_stats('2.12',
    "Berlin, DE % increase over today's mortality levels without accounting for costs (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="DEU.3.12.141"]/(9.0*100)*100,
    output.file
    )


# Load IR-level impacts, not accounting for costs.
impacts_fin = get_mortality_impacts(
    qtile='mean',
    scn='noadapt',
    regions='all',
    year_list=c(2099),
    ssp=ssp,
    rcp=rcp,
    iam=iam)


# At the end of the century we project an increase of about XX death equivalents 
# annually in Accra, Ghana and a decrease of about YY annually in Berlin, DE (deaths per 100k)

write_stats('2.13',
    "Accra, Ghana noadapt deathrate impacts in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="GHA.5.70"],
    output.file
    )

write_stats('2.15',
    "Berlin, DE noadapt deathrate impacts in 2100 (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="DEU.3.12.141"],
    output.file
    )

# Calculate % increase over today's mortality levels in Accra & Berlin (deaths per 100k); 
# Source: https://www.un.org/en/development/desa/population/publications/pdf/mortality/World-Mortality-2017-Data-Booklet.pdf, pages 12 & 15
write_stats('2.16',
    "Accra, Ghana % increase over today's mortality levels without accounting for costs (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="GHA.5.70"]/(8.3*100)*100,
    output.file
    )

write_stats('2.18',
    "Berlin, DE % increase over today's mortality levels without accounting for costs (RCP8.5, SSP3, IIASA-GDP)",
    impacts_fin$mean[impacts_fin$region=="DEU.3.12.141"]/(9.0*100)*100,
    output.file
    )

# Section 3: Marginal effect of a hot day (35C), with response function clipping 
# (<5, 5-64, >64 & combined)

write('\n3. Marginal effect of a hot day (35C) with response function clipping',
    file=output.file, append=T)

# 3.1 65+ age group
write('\n3.1 65+ Age Group', file=output.file, append=T)


betas = calculate.beta("oldest", summ_temp=35, inc_adapt=T)

write_stats('3.1.1',
    "Percent of IRs for which weak monotonicity binds in 2050 (65+ age group)",
    (nrow(dplyr::filter(betas, clipped==1, year==2050))) /
        (nrow(dplyr::filter(betas, year==2050)))*100,
    output.file
    )

write_stats('3.1.2',
    "Percent of IRs for which weak monotonicity binds in 2100 (65+ age group)",
    (nrow(dplyr::filter(betas, clipped==1, year==2100))) /
        (nrow(dplyr::filter(betas, year==2100)))*100,
    output.file
    )

global = mean(betas$betas_all_clip[betas$year==2015])

write_stats('3.1.3',
    "Global average treatment effect for an additional 35C day (2015, 65+ age group)",
    global,
    output.file
    )

#In-sample average (across IRs) treatment effect for an additional 35C day (65+ age group)
insamplelist = c("BRA", "CHL", "CHN", "FRA", "JPN", "MEX", "USA" , "AUT",
    "BEL", "BGR", "CHE", "CYP", "CZE", "DEU", "DNK", "EST", "GRC", "ESP",
    "FIN", "HRV", "HUN", "IRL", "ISL", "ITA", "LIE", "LTU", "LUX", "LVA",
    "MNE", "MKD", "MLT", "NLD", "NOR", "POL", "PRT", "ROU", "SWE", "SVK", "TUR", "GBR")

insample = mean(betas$betas_all_clip[
    betas$year==2015 & (substr(betas$region, 1,3) %in% insamplelist)])

write_stats('3.1.4',
    "In-sample average (across IRs) treatment effect for an additional 35C day (2015, 65+ age group)",
    insample,
    output.file
    )

outsample = mean(betas$betas_all_clip[
    betas$year==2015 & !(substr(betas$region, 1,3) %in% insamplelist)])

write_stats('3.1.5',
    "In-sample average (across IRs) treatment effect for an additional 35C day (2015, 65+ age group)",
    outsample,
    output.file
    )

write_stats('3.1.6',
    "Ratio of out-of-sample to in-sample treatment effects for an additional 35C day (2015, 65+ age group) ",
    outsample/insample,
    output.file
    )

#Global mortality impact in 2100 for additional 35C day (65+ age group)
write_stats('3.1.7',
    "Global average treatment effect for an additional 35C day (2100, 65+ age group)",
    mean(betas$betas_all_clip[betas$year==2100]),
    output.file
    )

write_stats('3.1.8',
    "Percentage decrease in marginal impacts caused by increasing incomes, 65+ age group",
    betas$decline[1] ,
    output.file
    ) 

# 35C response in 2015 in Houston (Harris County USA.44.2628) and
# Seattle (King County USA.48.2971) relative to location-specific minimum mortality temperature (MMT)
seattle.oldest = betas$seattle[1]
write_stats('3.1.9',
    "35C response in Seattle, (2015, 65+ age group)",
    seattle.oldest,
    output.file
    ) 

houston.oldest = betas$houston[1]
write_stats('3.1.10',
    "35C response in Houston, (2015, 65+ age group)",
    houston.oldest,
    output.file
    ) 

if (deprecated) {

    # 3.1.2 Global and Insample total number of deaths above 35C for +65 age group.
    write('\n3.1.2 Global and Insample total number of deaths above 35C', 
        file=output.file, append=T)

    betas = calculate.beta("oldest", summ_temp=NULL)

    # Get betas for 2015 for each IR at all temperatures above 35C.
    curve = filter(betas, year == 2015 & temp %in% c(seq(35,44,1))) 

    # Load population.
    pop = get_econvar('pop', regions='all', year_list=2015)

    # Load binned temp distribution.
    temp = fread(glue("{DB}/2_projection/5_climate_data/tas_CCSM4_2015_35-44C_bin.csv"), 
            stringsAsFactors = F) %>%
        data.frame() %>%
        dplyr::select(-c(year, model), region=hierid) %>%
        tidyr::gather(temp, days, count_35:count_44)
    temp$temp = as.numeric(substr(temp$temp, 7, 8))
                        
    # Merge pop and temp to df.
    curve = left_join(curve, pop, by = c("region")) %>% 
            left_join(temp, by = c("region", "temp")) 

    # Calculate Global number of deaths.
    curve.agg = aggregate(
        list(ate = curve$betas_all_clip, days = curve$days), 
        by = list(temp = curve$temp), FUN=mean, na.rm = T)
    curve.agg$ate.days = curve.agg$ate * curve.agg$days

    global.total = (sum(pop$pop)/100000)*sum(curve.agg$ate.days)

    write_stats('3.1.2.1',
        "Global deaths above 35C (2015, 65+ age group)",
        global.total,
        output.file
        ) 

    # Calculate in-sample number of deaths.

    curve.in = subset(curve, substr(curve$region, 1,3) %in% insamplelist) 
    curve.agg.in = aggregate(
        list(ate = curve.in$betas_all_clip),
        by = list(temp = curve.in$temp), FUN=mean, na.rm=T) 
    curve.agg.in = left_join(curve.agg.in, curve.agg %>% dplyr::select(temp, days), 
        by = c("temp")) 
    curve.agg.in$ate.days = curve.agg.in$ate*curve.agg.in$days 
    insample.total = (sum(pop$pop)/100000)*sum(curve.agg.in$ate.days) 

    write_stats('3.1.2.2',
        "In-sample deaths above 35C (2015, 65+ age group)",
        insample.total,
        output.file
        ) 

    # Calculate difference between Global and In-sample
    write_stats('3.1.2.3',
        "Difference between Global and Insample",
        global.total - insample.total,
        output.file
        ) 
}

# 3.2 5-64 age group
write('\n3.2 5-64 Age Group\n', file=output.file, append=T)
betas = calculate.beta("older", summ_temp=35, inc_adapt=T)

#Percentage decrease in marginal damages associated with increasing incomes (5-64 age)
write_stats('3.2.1',
    "Percentage decrease in marginal impacts associated with increasing incomes, 5-64 age group",
    betas$decline[1],
    output.file
    ) 

# 35C response function at baseline (2015) in Houston's IR and 
# in Seattle's IR & make both of these relative to MMT (5-64 age)
seattle.older = betas$seattle[1] 
write_stats('3.2.2',
    "35C response in Seattle, (2015, 5-64 age group)",
    seattle.older,
    output.file
    ) 

houston.older = betas$houston[1]
write_stats('3.2.3',
    "35C response in Houston, (2015, 5-64 age group)",
    houston.older,
    output.file
    ) 

# <5 age group
write('\n3.3 <5 Age Group\n', file=output.file, append=T)
betas = calculate.beta("young", summ_temp=35, inc_adapt=T)

#Percentage decrease in marginal damages associated with increasing incomes (<5 age group)
write_stats('3.3.1',
    "Percentage decrease in marginal impacts associated with increasing incomes, <5 age group",
    betas$decline[1],
    output.file
    )  

# 35C response function at baseline (2015) in Houston and Seattle & make both of 
# these relative to MMT (<5 age group)
seattle.young = betas$seattle[1]
write_stats('3.3.2',
    "35C response in Seattle, (2015, <5 age group)",
    seattle.young,
    output.file
    ) 

houston.young = betas$houston[1]
write_stats('3.3.3',
    "35C response in Houston, (2015, <5 age group)",
    houston.young,
    output.file
    ) 


# Combined age group
write('\n3.4 All Age Groups\n', file=output.file, append=T)

# Combined age group 35C response in 2015 in Houston and Seattle relative to MMT
agecomb = data.frame(list(
    region = c("USA.48.2971", "USA.44.2628"),
    year=c(2015, 2015),
    young = c(seattle.young, houston.young),
    older = c(seattle.older, houston.older),
    oldest = c(seattle.oldest, houston.oldest)))

agecomb = popwt_collapse_columns(agecomb, 'young', 'older', 'oldest')

write_stats('3.4.1',
    "35C response in Seattle, (2015, all age groups)",
    agecomb$combined[agecomb$region=="USA.48.2971"],
    output.file
    ) 

houston.young = betas$houston[1]
write_stats('3.4.2',
    "35C response in Houston, (2015, all age groups)",
    agecomb$combined[agecomb$region=="USA.44.2628"],
    output.file
    ) 


# Section 4. Monetized mortality damages as percent of GDP.
write('4. Monetized damages as percent of global GDP.', 
    file=output.file, append=T)

valuation = 'vly_epa_scaled'
qtile = c('mean', 'q25', 'q75')
rcplist = c('rcp45', 'rcp85')

for (r in seq(1, length(rcplist))) {

    write(glue('5.{r} {rcplist[r]}'), file=output.file, append=T)
    damages = get_mortality_damages(
        rcp=rcplist[r], 
        qtile=qtile, 
        regions='global',
        valuation=valuation,
        units='share_gdp',
        year_list='2099',
        scale_variable=100)

    for (q in seq(1, length(qtile))) {
        write_stats(glue('5.{r}.{q}'),
            glue("Damages as percent of global GDP, {rcplist[r]}, {valuation}, {qtile[q]}:"),
            damages[,glue('sharegdp_deathcosts_{valuation}_{qtile[q]}')],
            output.file
            )
    }
    write('', file=output.file, append=T)
}

# Section 5: CPU-hours required for Monte Carlo simulations
write('5. CPU-hours required for Monte Carlo simulations', 
    file=output.file, append=T)

#number of nc4 files generated per cpu-hour
files.per.cpuhr = 1 

#number of unaggregated impact files generated per ssp-rcp-iam-gcm
files.per.ssp.rcp.iam.gcm = 16 
no.of.ssp = 3
no.of.iam = 2
no.of.gcms_rcp = 33 + 32
no.of.batches = 15
total.files = (no.of.ssp * no.of.iam * no.of.gcms_rcp * 
    no.of.batches * files.per.ssp.rcp.iam.gcm * files.per.cpuhr)

write_stats('5.1',
    "Number of Monte Carlo simulations",
    total.files,
    output.file
    )
