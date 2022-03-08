''' 
This is a bundle of tools to essentially retrieve 'VSL's (value of stastical life) for a given impact region and year using a baseline, standard VSL
that is transformed to obtain space and time specific values. This is obtained assuming that changes in income per capita change the VSL. 

The master function is `make_iryear_vsl` and this is the place to look at to understand where the input data and parameters come from. The calculations happen in the sub functions called
with this input data. 
'''

import os
import numpy as np
import pandas as pd
import xarray as xr
from joblib import Parallel, delayed
import itertools
import time



# helper function
def group_wavg(df, valuecol, weightcol, bycols):
    """ Calculates weighted average over multiple group columns in a dataframe.

    Parameters
    ----------
    df: Pandas dataframe containing weights and values to average.
    valuecol: column conatining values to be averaged.
    weightcol: column containing weights.
    bycols: columns to group by before averaging.
    """
    return (
        (df[valuecol] * df[weightcol]).groupby([df[col] for col in bycols]).transform(sum) 
        / df[weightcol].groupby([df[col] for col in bycols]).transform(sum) )

# helper function
def append_2100_lifeexpect(dfe, dfir):
    """ Cleans remaining life expectancy dataframe by year 2100 for
    interpolation.

    Parameters
    ----------
    dfe: Pandas dataframe containing input remaining life expectancies.
    dfir: dataframe containing list of impact regions.

    Returns 
    ------- 
    pandas data frame 

    """
    dfelist = []
    elist = [x for x in list(dfe) if x not in ['iso', 'year', 'ssp']]
    for ssp in dfe.ssp.unique():
        for reg in dfe.iso.unique():
            fdict = dict(ssp = ssp, iso=reg, year=2100)
            for col in elist:
                fdict[col] = dfe[col].loc[(dfe.year == 2095) & (dfe.iso == reg) & (dfe.ssp == ssp)]
            dfetmp = pd.DataFrame(fdict)
            dfelist.append(dfetmp)

    dfe = ( dfe.append(pd.concat(dfelist,sort=False), sort=False)
            .sort_values(['iso', 'ssp', 'year'])
            .reset_index(drop=True) )

    return dfe

# helper function
def get_missing_lifeexpect(dfe, dfir):
    """ Cleans remaining life expectancy dataframe by assigning average values
    to missing countries.

    Parameters
    ----------
    dfe: Pandas dataframe containing input remaining life expectancies.
    dfir: dataframe containing list of impact regions.

    Returns 
    -------
    pandas data frame 

    """
    dfirt = pd.DataFrame({'iso':dfir.iso.unique()})
    tmp = dfirt.merge(dfe.loc[(dfe.year == 2015) & (dfe.ssp == 'SSP3')], how = 'left', on = ['iso'])
    tmp = tmp.loc[np.isnan(tmp['year']),'iso']
    elist = [x for x in list(dfe) if x not in ['iso', 'year', 'ssp']]
    tmplist = []
    yvect = dfe.year.unique()
    for ssp in dfe.ssp.unique():  
        fdict = dict(year=yvect, ssp=np.repeat(ssp, yvect.size))
        for col in elist:
            fdict[col] = dfe.loc[dfe.ssp==ssp].groupby('year')[col].mean()
        for reg in tmp:
            rdict = fdict.copy()            
            rdict['iso'] = np.repeat(reg, yvect.size) 
            tmpdf = pd.DataFrame(rdict)
            tmplist.append(tmpdf)
    dfe = pd.concat(tmplist,sort = False)
    return dfe

# data and input parameter loading 
def load_fed_data(data_path) :
    """ Returns 2019 US GDPpc in 2005$ for income-scaling VSL and inflation
    adjustment term for converting damages to 2019$.

    Parameters
    ----------
    data_path: location of mortality repository data folder.

    Returns
    -------
    list of two floats : the income in 2019 per Fed data, and the 2005-2019 inflation adjustment factor per the Fed data
    """

    # Load Fed gdppc and GDP deflator.
    file_fed = os.path.join(data_path, '3_valuation/inputs/adjustments/fed_income_inflation.csv')
    fed = pd.read_csv(file_fed).set_index('year')
    fed_gdppc = fed['gdppc'].to_dict()
    fed_gdpdef = fed['gdpdef'].to_dict()

    # Fed GDPpc input as constant 2012 dollars. Convert to 2005.
    income_2019 = fed_gdppc[2019] * (fed_gdpdef[2005] / fed_gdpdef[2012])

    inflation_adj_2019 = (fed_gdpdef[2019] / fed_gdpdef[2005])

    return(income_2019, inflation_adj_2019)

def load_income(file, isofiles=None):
   
    """ Load income data by impact region, with the values varying by impact region or iso level. 

    Parameters
    ----------
    file: str
        absolute path to data containing IR level gdppc data. Should be a netcdf file. 
    isofiles: dict or None  
        dict containing absolute paths for each economic model key ('low, 'high') pointing 
        to datasets containing iso level gdppc values. Should have a weird format : [variable ssp iam iso year 0]
        where 0 is the value variable. 

    Returns 
    --------
    pandas data frame : a [model, region, year, ssp, gdppc] pandas data frame where gdppc stands for gdp per capita, 
    region stands for impact region, and model stands for the economic model ('low', 'high'). Gdppc values may be varying by impact region or country depending on `isofile`,
    but the data is returned by impact region in both cases.  
    """

    irdata = xr.open_dataset(file)['gdppc'].to_dataframe().reset_index()        
    if isofiles is None:
        return irdata
    else:
        irdata['iso'] = irdata.region.apply(lambda x: x[:3])
        isodata = pd.concat([pd.read_csv(isofiles['high']),pd.read_csv(isofiles['low'])])
        isodata = isodata.rename(columns={'0':'gdppc', 'iam':'model'})
        isodata = isodata[['gdppc', 'model', 'year', 'iso']]
        iriso = irdata[['model','region','year','ssp','iso']].merge(isodata, how='left', on=('iso', 'year','model')).drop(columns='iso')
        return iriso

def load_population(file):

    '''
    Parameters 
    ---------
    file : str
        absolute path to netcdf file containing total pop and age specific pop data
    Returns 
    ------- 
    a pandas data frame with 'region' (str, indicating impact region), 'year' (int), 'pop', 
    'pop5to64' and 'pop65plus' (float), 'ssp' and  'iso' (str) columns. Except for years multiple of 5, 
    the values are all NaN. 
    '''

    econvar = xr.open_dataset(file)
    pop = econvar[[c for c in econvar.data_vars.keys() if 'pop' in c]]

    # Format population data. (Note pop is the same across Econ. modeling scns.)
    pop = ( pop.where(pop.year % 5 == 0)
            .to_dataframe()
            .reset_index() )
    pop['iso'] = pop.region.apply(lambda x: x[:3])
    pop = pop.loc[pop.model=='low'][[x for x in list(pop) if 'model' not in x]]

    return pop

def load_lifeexp(file, dfir):

    '''
    loads and does various cleanup in life expectancy variables, mostly what append_2100_lifeexpect() and get_missing_lifeexpect() do.

    Parameters 
    ---------
    file : str
        absolute path to csv file containing life expectancy data, as produced by 
        life_expectancy_mt(). 
    dfdir : pandas data frame 
        ir codes matched to their country as returned by load_irlist()

    Returns 
    ------- 
    pandas data frame with ['iso','year','ssp'] and life expectancy variables calulated as produced by life_expectancy_mt(). 
    '''
    dfe = pd.read_csv(file)
    dfe.rename(columns={'region':'iso','scenario':'ssp'}, inplace=True)
    dfe = append_2100_lifeexpect(dfe, dfir)
    dfe = dfe.append(get_missing_lifeexpect(dfe, dfir), sort = False)

    return dfe 

def load_irlist(file):

    '''
    Parameters 
    ---------
    file : str

    Returns 
    ------- 
    pandas data frame with 'region' (impact region) and 'iso' string value columns
    '''
    dfir = pd.read_csv(file)
    dfir = dfir.loc[dfir.is_terminal].reset_index(drop=True)
    dfir.drop(['parent-key', 'name', 'alternatives', 'is_terminal', 'gadmid', 'agglomid', 'notes'],axis=1,inplace=True)
    dfir.rename(columns={'region-key':'region'}, inplace=True)
    dfir['iso'] = dfir.region.apply(lambda x: x[:3])

    return dfir

def load_interpolated_pop_lifeexp(data_path, ssp):

    '''
    population and life expectancy data are provided for chunks of 5 years. This function loads this data source linearly interpolated (that is, year-by-year)
    or does this time consuming operation, saves, and returns if it doesn't exist.

    Parameters 
    ---------
    data_path : str
        absolute path after which there should be '3_valuation/inputs/interpolated_pop_exp' and then the data in netcdf4 if it exist. If doesn't, will be 
        saved there. 
    ssp : str
        socioecon model. 

    Returns 
    ------- 
    pandas data frame with 'region' (impact region) and 'iso' string value columns

    '''

    interpolated_data = os.path.join(data_path,f'3_valuation/inputs/interpolated_pop_exp/interpolated_pop_exp_{ssp}.nc4')
    if os.path.exists(interpolated_data):
        df = xr.open_dataset(interpolated_data).to_dataframe()
        df = df.reset_index()
        return df 
    else:
        # load IR list
        print('loading ir list data...')
        dfir = load_irlist(os.path.join(data_path, f'2_projection/1_regions/hierarchy.csv'))

        # Load pop
        print('loading and concatenating pop data...')
        pop = load_population(os.path.join(data_path, f'2_projection/2_econ_vars/{ssp}.nc4'))
        
        # Load life expectancy
        print('loading life expectancy data...')
        dfe = load_lifeexp(os.path.join(data_path, '3_valuation/inputs/exp/raw/life_expectancy_mt.csv'), dfir)

        # merge age share data
        print('Merging population and life expectancy data...')
        df = pop.merge(dfe, how='left', on=['year', 'iso', 'ssp'])

        # expand and interpolate over years
        print('Interpolating population and life expectancy data over years...')
        df = df.groupby(['region','ssp']).apply(lambda group: group.interpolate())

        print('Saving interpolated data to netcdf format...')
        df.drop(columns=['Unnamed: 0'], errors='ignore')
        dt = df.set_index(['region', 'year', 'ssp'])
        dtnc = dt.to_xarray()
        dtnc.to_netcdf(os.path.join(data_path,f'3_valuation/inputs/interpolated_pop_exp/interpolated_pop_exp_{ssp}.nc4'))

        return df 

# VSL computations functions
def standard_vsl(vsl_epa, life_expectancy, file_cpi, base_year, base_epa):


    '''
    formats baseline, standard VSL values to be applied to a methodology that will retrieve region-year specific VSL values.

    Parameters 
    ---------
    vsl_epa : float
        standard VSL value to use. Typically the US EPA VSL. 
    life_expectancy : int
        number of years by which to divide `vsl_epa` to get a VSL per year of life. 
    file_cpi : str
        where to get the file for inflation adjustment 
    base_year : int
        integer indicating to which year the `vsl_epa` should be converted to. 
    base_epa : int 
        integer indicating the time dollar units of `vsl_epa`. 
    Returns 
    ------- 
    dict with 'epa' entry pointing to the inflation adjusted `vsl_epa` (adjusted from `base_epa` to `base_year` and a 'vly_epa' value pointing to the latter value divided by 
    `life_expectancy` representing the value of a year of life. 
    '''


    vsl = {} 
    cpi = pd.read_csv(file_cpi).set_index('Year')['Annual'].to_dict()
    vsl['epa'] = vsl_epa * cpi[base_year] / cpi[base_epa]
    vsl['vly_epa'] = vsl['epa'] / life_expectancy

    return vsl

def iryear_vsl(socioecon, vsl, baseline_income, inflation_adjustment, moddict):

    """ applies standard VSL and VLY values to region-year-ssp-iam entries in order to retrieve VSL and VLY values that vary over space and time. 

    Six methods in total are used here. We number them in this description and the numbers match the code below, for convenience to understand the code. 

        (1) VSL unique across space and time
        (2) VSL with spatial and temporal variation using regional income scaling (unit income elasticity assumption)
        (3) VSL only with temporal variation, using the (2) collapsed across space through population weighting. 
        (4) (5) (6) equivalent but with VLY

    See Carleton et al. (2019) for a more detailed discussion of these assumptions.

    Parameters
    ----------
    socioecon : pandas data frame
        containing input socio economic data 
    vsl : pandas data frame
        containing vsl related data. 
    inflation_adjustment : 
        float. Inflation adjustment to be used to perform monetary conversion, if needed, otherwise equal to 1. 
    moddict : dict 
        translating economic model keywords. 
    baseline_income : 
        float. The income level to be used for the income scaling methodology. Typically the US country level income. 

    """

    
    df = socioecon
    df['gdp'] = df['gdppc'] * df['pop'] # total GDP to be stored in the final file 
    df['ratio'] = df.gdppc / baseline_income # income ratio for scaling 

    # EPA, deaths
    df['vsl_epa'] = vsl['epa'] # (1) standard, unique VSL across space and time
    df['vsl_epa_scaled'] = df.ratio * vsl['epa'] # (2) VSL varying across space and time, through rescaling with income ratio. Assumption : income elasticity = 1.
    df['vsl_epa_popavg'] = group_wavg(df, 'vsl_epa_scaled', 'pop', ['model', 'ssp', 'year']) # (3) VSL varying across time only, based on(2) and then collapsed at the global level for each model-ssp-year using pop weighting. 

    # EPA, lifeyears. Same comments apply. 
    df['vly_epa'] = vsl['vly_epa'] # (4)
    df['vly_epa_scaled'] = df.ratio * vsl['vly_epa'] # (5)
    df['vly_epa_popavg'] = group_wavg(df, 'vly_epa_scaled', 'pop', ['model', 'ssp', 'year']) # (6)

    df = df.replace({'model': moddict}).set_index(['ssp', 'region', 'model', 'year'])

    vsl_cols = ['vsl_epa_scaled', 'vsl_epa_popavg', 'vly_epa_scaled',
        'vly_epa_popavg', 'mt_young', 'mt_older', 'mt_oldest', 'gdp', 'pop']
    non_mt_cols = [x for x in vsl_cols if 'mt' not in x and x != 'pop']
    vsl_ds = df[vsl_cols].to_xarray()

    for var in non_mt_cols: # we should inflation-adjust only monetary variables. 
        vsl_ds[var] = vsl_ds[var] * inflation_adjustment

    return vsl_ds

def make_iryear_vsl(ssp, data_path, outputpath=None):
    """ Loads necessary input data and parameters to compute VSL values at the region-year level, relying on iryear_vsl(), and can write output to netcdf. 

    Essentially what happens is that we start from a baseline, unique value ('VSL') and apply a methodology to retrieve specific region-year-SSP-iam values, relying on the economic idea
    that different incomes per capita mean different VSLs. As a consequence, the input data required at the region-year-SSP-iam is mostly income and population. The rests are essentially various scalar adjustments. 


        Detailed list of parameters and data loaded : 

            - the value of a statistical life (VSL) to be used as a baseline. The EPA VSL from 2012 U.S. EPA Regulatory Impact Analysis (RIA) for the Clean
            Power Plan Final Rule (2020 income-adjusted, 2011$ USD) is used. 


            - the remaining life expectancy of the median american in 1990 (middle og AG02 sample) to divide the latter and obtain life-years values. 

            - the conversion parameters to convert the VSL from 2011$ USD to 2005$ USD to match the projection system which is in 2005 USD. We use the CPI 
            to do that conversion. 

            - the US income from Fed data in 2005$ and the inflation adjustment parameter to convert VSL variables to 2019$ (TODO : this is inconsistent with the above bullet point. This old comment
            might be useful : 'Note, later we'll convert calculated damages from 2005$ to 2019$, which brings this $9.9m number to the $10.95m value discussed in the paper.')
    )
            - the gdp data per region, year, model, ssp, both at the IR and ISO level. The IR level data is in the data directory in '2_projection/2_econ_vars/{ssp}.nc4' and the country level data is stored
            in the same place in a csv format with names iso_gdppc_low_{ssp}.csv. Both are equivalent to what the projection system use, but where retrieve at different moments, the iso files being the most recent. 
            Those where made by this code : https://gitlab.com/ClimateImpactLab/Impacts/post-projection-tools/-/blob/ssp_data/ssp_data/projection_ssp_to_csv.py which essentially calls the projection system. 

            - the population data per region, year, ssp. 

    Parameters
    ----------
    ssp: SSP scenario for which to calculate VSLs.
    data_path: location of mortality repository data folder.
    outputpath: None or location where to save within the `data_path`

    Returns
    --------
    tuple with three xarray datasets : vsl data, vsl data with country income, life expectancy data. Dimensions are 
    'region', 'model', 'year'. 
    """

    tic = time.time()

    moddict = {'high' : 'OECD Env-Growth', 'low' : 'IIASA GDP'}
    
    # load the two baseline US VSL and VLY values into a dictionary 
    print('loading baseline US VSL and VLY values...')
    vsl = standard_vsl(vsl_epa=9900000., life_expectancy=47.2, file_cpi=os.path.join(data_path, '3_valuation/inputs/adjustments/USA_CPI_1990_2016.csv'), base_year=2005, base_epa=2011)

    # loading interpolated population and life expectancy data 
    print('loading interpolated pop and life exp data')
    df = load_interpolated_pop_lifeexp(data_path, ssp)

    # loading income data
    print('Loading income data...')
    income = load_income(os.path.join(data_path, f'2_projection/2_econ_vars/{ssp}.nc4'))
    income_iso = load_income(os.path.join(data_path, f'2_projection/2_econ_vars/{ssp}.nc4'), isofiles={'low': os.path.join(data_path, f'2_projection/2_econ_vars/iso_gdppc_low_{ssp}.csv'),
     'high' : os.path.join(data_path, f'2_projection/2_econ_vars/iso_gdppc_high_{ssp}.csv')})
    
    # merging with pop and life exp
    print('Merging population, life expectancy and income ...')
    df_ir_income = df.merge(income, how='inner', on=['year', 'region', 'ssp'], validate ='1:m')
    df_iso_income = df.merge(income_iso, how='inner', on=['year', 'region', 'ssp'], validate ='1:m')

    
    print('inputs loaded. Calculating life values per region and year...')
    # performing computations with vsl using downscaled income scaling
    # parameters: 2019 incomes from Fed for income scaling VSL.
    income_2019, inflation_adj_2019 = load_fed_data(data_path)
    print('Calculating VSL for each iryear with IR income ....')
    vsl_ds = iryear_vsl(socioecon=df_ir_income, vsl=vsl, baseline_income=income_2019, inflation_adjustment=inflation_adj_2019, moddict=moddict)
    # performing computations with vsl using country level income scaling 
    print('Calculating VSL for each iryear with country income ....')
    vsl_ds_iso_income = iryear_vsl(socioecon=df_iso_income, vsl=vsl, baseline_income=income_2019, inflation_adjustment=inflation_adj_2019, moddict=moddict)

    exp_cols = ['expectancy_young', 'expectancy_older', 
        'expectancy_oldest', 'expectancy_25_29_mt']
    df_ir_income = df_ir_income.replace({'model': moddict}).set_index(['ssp', 'region', 'model', 'year'])
    exp_ds = df_ir_income[exp_cols].to_xarray() # using whichever of the two

    if outputpath:
        print('writing the data ....')
        # Export values to NetCDF.
        (vsl_ds.squeeze()
            .to_netcdf(
                os.path.join(data_path, outputpath, f'vsl/{ssp}.nc4')))

        (vsl_ds_iso_income.squeeze()
            .to_netcdf(
                os.path.join(data_path, outputpath, f'vsl/{ssp}_iso_income.nc4')))

        (exp_ds.squeeze()
            .to_netcdf(
                os.path.join(data_path, outputpath, f'exp/{ssp}.nc4'))) 


    toc = time.time()
    print('TOTAL TIME: {:.2f}s'.format(toc-tic))

    return tuple((vsl_ds, vsl_ds_iso_income, exp_ds))

