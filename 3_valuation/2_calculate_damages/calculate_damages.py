'''
bundle of tools to convert mortality death-impacts into dollar impacts (i.e damages), i.e to do mortality valuation. 

Essentially the idea is to multiply the number of deaths or lifes saved due to climate change by an appropriate measure of the statistical value of a life, that may be 
varying across time and space. 

There are two master functions, `concatenate_IR_damages` to run damages for all the montecarlo output and save to netfcdf files for integration purposes,
and `generate*` functions that compute damages quantiles saved to csvs. 
'''

import os
import glob
import numpy as np
import pandas as pd
import glob
import parse
import xarray as xr
import re
from joblib import Parallel, delayed
import dask
from statsmodels.stats.weightstats import DescrStatsW
from itertools import product
import functools
import random 
import gc 
import time

def load_inputs(vsl_dir, ssp, iso_income=False): 
    """Loads VSL and remaining life expectancy inputs for valuation

    Parameters
    ----------
    vsl_dir: Location of VSL-related valuation inputs, including both the VSLs
        themselves (VSL, VLY, and Murphy-Topel) and the remaining life expectancy
        adjustments that are required for VLY and Murphy-Topel.
    ssp: SSP scenario. SSP1 - SSP5
    iso_income: boolean
        return both IR and country level VSL

    
    Returns
    -------
    list of one or two xarray Datasets. If `iso_income`, only the VSL data for country level income VSL. If not, the VSL data for IR level income VSL and the life expectancy data. 
    """
    vsl_ds = xr.open_dataset(f'{vsl_dir}/vsl/{ssp}.nc4')        
    exp_ds = xr.open_dataset(f'{vsl_dir}/exp/{ssp}.nc4')

    if iso_income:
        vsl_ds_iso_income = xr.open_dataset(f'{vsl_dir}/vsl/{ssp}_iso_income.nc4')
        return vsl_ds_iso_income
    else:
        return vsl_ds, exp_ds



def open_impacts_nc4(scn, age, indir):
    """Loads projected impacts from the raw NetCDF4 projection output.

    This opens a raw impact region-level projection output file for a given
    adaptation scenario and age group. Returns an xarray dataset containing
    projection results from one Monte Carlo batch/GCM/SSP/RCP/economic modeling
    scenario.

    Currently this only supports rebased impacts from the projection model in
    Carleton et al. (2019). `base` and `col` should be made parameters in this
    function if other functional forms or projection objects are valued.

    Parameters
    ----------
    scn: Adaptation scenario. 
        - 'fulladapt' - Full adaptation
        - 'incadapt' - Income only adaptation
        - 'histclim' - historical climate counterfactual
        - 'costs' - Adaptation costs.
    age: Age group. young, older or oldest.
    indir: Directory containing the raw projection output.

    Returns 
    ------- 
    xarray Dataset with impact values. 
    """

    base='Agespec_interaction_GMFD_POLY-4_TINV_CYA_NW_w1'
    col = 'rebased'
    scale = 1

    if scn=='fulladapt':
        suff = '-levels'
    elif scn=='incadapt':
        suff = '-incadapt-levels'
    elif scn == 'histclim':
        suff = '-histclim-levels'
    elif scn == 'costs':
        suff = '-costs-levels'
        scale = 1/100000.
        col = 'costs_ub'

    ds = (xr.open_dataset(f'{indir}/{base}-{age}{suff}.nc4')
        .sel(year=slice(2010,2099)))

    ds['region'] = ds.regions
    ds[col] = ds[col] * scale

    return ds


def value_mortality_damages(
    inputdir, 
    parser, 
    vsl_ds, 
    exp_ds=None, 
    moddict={'high' : 'OECD Env-Growth', 'low' : 'IIASA GDP'},
    export_IR=False,
    export_IR_netcdf4=False,
    ir_model='vsl_epa_scaled',
    do_deryugina=False,
    only_variables=None,
    scenario='fulladapt',
    iso_income=False):

    """Calculates monetized damages from formatted projection output.

    Values the mortality impacts of climate change for a given adaptation
    scenario as well as its associated adaptation costs. Computes values for
    each age group, exporting the total across all three. Can produce output for
    all valuation methodologies.

    Parameters
    ----------
    inputdir: str. 
        Full path to a raw projection output target directory. It should contain the impact netcdf files. Example: 
        '/data/2_projection/3_impacts/main_specification/raw/montecarlo/batch7/rcp45/surrogate_CanESM2_89/high/SSP1'
    parser: str. 
        used to extract data from the `inputdir`, essentially doing the
        opposite of a standard f-string. Example of value: "/batch{}/{}/{}/{}/{}". If applied to 
        "/batch2/rcp85/CCSM4/low/SSP3" it would return the list (2, 'rcp85', 'CCSM4', 'low', 'SSP3').
    vsl_ds: xarray Dataset or str. 
        if xarray Dataset, should containing VSL data (see `load_inputs`), or if a str, should point to the directiry necessary to run
        `load_inputs`.  
    exp_ds: xarray Dataset or None
        ignored if `vsl_ds` is a str (See `vsl_ds`), otherwise Dataset containing remaining life expectancy data (see
        `load_inputs`).
    moddict: dict. 
        a dictionary that converts economic modeling scenarios to key-words.
    export_IR: boolean
        if True returns impact-region output while False returns Global output
    export_IR_netcdf4 : boolean
        ignored if export_IR is False. Otherwise and if True, an xarray Dataset with (batch,rcp,gcm,iam,ssp,region,year) dimensions
        is returned, and the dimensions and variables are properly documented with meta information. 
    ir_model: str. 
        Considered only of export_IR True and export_IR_netcdf4 False. One of ['vsl_epa_scaled', 'vsl_epa_popavg', 'vly_epa_scaled', 'vly_epa_popavg', 'mt_epa_popavg', 'mt_epa_scaled']. Identifies 
        a valuation methodology to export if export_IR is True. Can be None in which case all methodologies are stored. For detailed explanation
        of each valuation methodology refer to `3_valuation/1_calculate_vsl/calculate_vsl.py`. 
    do_deryugina: boolean
        Allows to do life-year valuation using a rescaled life expectancy for the oldest,
        based on results from Deryugina et al (2019).
    only_variable : list of str or None
        if None or `export_IR_netcdf4` is False, ignored, otherwise, overrides `ir_model` and the code returns in the dataset only the calculation(s) indicated. `only_variable` allows to select variables with their
        full name while `ir_model` allows to filter variables based on a valuation methodology prefix in their names. Example : ['monetized_damages_vly_epa_scaled'] or
        ['monetized_damages_vly_epa_scaled','monetized_damages_vsl_epa_scaled'].
    scenario: str
        adaptation scenario. see open_impacts_nc4()
    iso_income : boolean
        deaths are monetized with iso-level-income-VSL while costs are still monetized with ir-level-income-VSL. This difference will appear in the variable attributes. 


    Returns 
    -------

    an xarray Dataset containing mortality valuation output. Dimensions will be at least region, year, gcm and batch, and more depending on `export_IR` and `export_IR_netcdf4`,
    and the number of data variables will depend on how many valuation methodologies the user wants to get results for, see `ir_model`, and `only_variable`. 

    """

    age_groups=['young','older','oldest']

    # Parse input directory for the projection specifications.
    (batch, rcp, gcm, model, ssp) = list(
        parse.parse(parser.replace('*','{}'),inputdir))

    if isinstance(vsl_ds, str):
        vsl_dir = vsl_ds
        vsl_ds, exp_ds = load_inputs(vsl_dir=vsl_dir, ssp=ssp, iso_income=False)
        if iso_income:
            vsl_ds_iso_income = load_inputs(vsl_dir=vsl_dir, ssp=ssp, iso_income=True)
    else:
        if iso_income:
            raise ValueError('cant have vsl_ds passed as dataset and requesting iso_income vsl data')
    
    vsl_ds = ( vsl_ds.where(vsl_ds.ssp == ssp, drop=True)
        .where(vsl_ds.model == moddict[model], drop=True)
        .squeeze() ) 

    vsl_dict = {} # allowing for different vsl data for deaths and costs monetization 
    vsl_geog_level_info = {} # same but to document in attributes

    if iso_income:

        vsl_ds_iso_income = ( vsl_ds_iso_income.where(vsl_ds_iso_income.ssp == ssp, drop=True)
            .where(vsl_ds_iso_income.model == moddict[model], drop=True)
            .squeeze() )

        vsl_dict['deaths'] = vsl_ds_iso_income 
        vsl_geog_level_info['deaths'] = 'country-year'
        vsl_dict['costs'] = vsl_ds # costs always monetized with ir level income vsl. 
        vsl_geog_level_info['costs'] = 'IR-year'

    else : 

        vsl_dict['deaths'] = vsl_ds 
        vsl_geog_level_info['deaths'] = 'IR-year'
        vsl_dict['costs'] = vsl_ds 
        vsl_geog_level_info['costs'] = 'IR-year'

    exp_ds = ( exp_ds.where(exp_ds.ssp == ssp, drop=True)
        .where(exp_ds.model == moddict[model], drop=True)
        .squeeze() ) 

    datasets = []
    for age in age_groups:

        # Load data.
        ds_f = open_impacts_nc4(scenario, age, inputdir)
        ds_h = open_impacts_nc4('histclim', age, inputdir)
        ds_c = open_impacts_nc4('costs', age, inputdir)

        # Construct dataset.


        # initiate a list containing future attributes of damages variables
        varattrs = {}

        impacts = xr.Dataset(
            data_vars = { 
                'deaths': (('year','region'), ds_f.rebased - ds_h.rebased ) ,
                'costs': (('year','region'), ds_c.costs_ub )} ,
            coords = {'year': ds_f.year, 'region': ds_f.region} )

        for var in ['deaths', 'costs']:


            if age=="oldest" and do_deryugina:
                scalar = 3.901/9.657
            else:
                scalar = 1

            impacts[f'ly_{var}'] = impacts[var] * exp_ds[f'expectancy_{age}'] * scalar
            impacts[f'mt_{var}'] = impacts[var] * exp_ds['expectancy_25_29_mt']

            for scl in ['popavg', 'scaled']:

                # VSL
                impacts[f'monetized_{var}_vsl_epa_{scl}'] = (
                    impacts[var] * vsl_dict[var][f'vsl_epa_{scl}'] )

                # VLY
                impacts[f'monetized_{var}_vly_epa_{scl}'] = (
                    impacts[f'ly_{var}'] * vsl_dict[var][f'vly_epa_{scl}'] )


                # M-T
                impacts[f'monetized_{var}_mt_epa_{scl}'] = ( 
                    impacts[f'mt_{var}'] 
                    * vsl_dict[var][f'mt_{age}'] 
                    * vsl_dict[var][f'vly_epa_{scl}'] )


                varattrs[f'monetized_{var}_vsl_epa_{scl}'] = {'long_title': f'monetized mortality {var} using value of statistical life and {vsl_geog_level_info[var]}-{scl}-income mortality valuation methodology',
                'units': '2019 USD', 'source': 'montecarlo simulation of impacts, VSL and life expectancy data'}

                varattrs[f'monetized_{var}_vly_epa_{scl}'] = {'long_title': f'monetized mortality {var} using value-of-life-year and {vsl_geog_level_info[var]}-{scl}-income mortality valuation methodology',
                'units': '2019 USD', 'source': 'montecarlo simulation of impacts, VSL and life expectancy data'}

                varattrs[f'monetized_{var}_mt_epa_{scl}'] = {'long_title': f'monetized mortality {var} using murphy-topel heterogeneous valuation of life year and {vsl_geog_level_info[var]}-{scl}-income mortality valuation methodology',
                'units': '2019 USD', 'source': 'montecarlo simulation of impacts, VSL and life expectancy data'}

        for scl, var in product(["popavg", "scaled"], ["vsl", "vly"]):

            impacts[f"monetized_damages_{var}_epa_{scl}"] = (impacts[f"monetized_deaths_{var}_epa_{scl}"] + impacts[f"monetized_costs_{var}_epa_{scl}"]) / vsl_ds["pop"] # notes (1) per capita for integration and (2) using either of vsl_dict element is same for the 'pop' variable. 
            costinfo=vsl_geog_level_info['costs']
            deathsinfo=vsl_geog_level_info['deaths']
            varattrs[f'monetized_damages_{var}_epa_{scl}'] = {'long_title': f'monetized mortality damages (monetized deaths + costs) using {var} {scl}-income mortality valuation methodology, {var} based on {costinfo} income for costs and on {deathsinfo} income for deaths',
            'units': '2019 USD per capita', 'source': 'montecarlo simulation of impacts, VSL, pop and life expectancy data'}


        datasets.append(impacts)

    out = xr.concat(datasets, dim='age')
    out['age'] = age_groups

    (out.coords['gcm'], out.coords['rcp'], out.coords['batch'], 
        out.coords['iam']) = (gcm, rcp, batch, model)

    # Output format depends on impact-region vs global resolution.
    if export_IR:
        if export_IR_netcdf4:
            out = out.expand_dims(['gcm','batch','ssp', 'rcp', 'model'])
            out = out.sum(dim='age')
            if only_variables:
                out = out[[c for c in out.data_vars.keys() if c in only_variables]]  
            else:
                out = out[[c for c in out.data_vars.keys() if c in varattrs]]
            for k in out.data_vars.keys():
                out[k].attrs = varattrs[k]

            out = out.drop('iam', errors='ignore') # this tends to stick around and is a duplicate of 'model' 
            
            out['batch'].attrs = {'long_title': f'batch of projected impacts (per the projection system definition)'}
            out['rcp'].attrs = {'long_title': f'representative concentration pathway (rcp) scenario'}
            out['gcm'].attrs = {'long_title': f'climate model'}
            out['model'].attrs = {'long_title': f'economic model (OECD or IIASA)'}
            out['ssp'].attrs = {'long_title': f'socio-economic pathway scenario '}

        else: 
            out = out.expand_dims(['gcm', 'batch'])
            out = out.sum(dim='age')
            out = out[[c for c in out.data_vars.keys() if ir_model in c]]
    else:
        out = out.groupby('year').sum(...)
        out['gdp'] = vsl_ds.gdp.groupby('year').sum(...)
        out = out.expand_dims(['batch', 'rcp', 'gcm', 'iam'])

    return out


def try_value_mortality_damages(logger, inputdir, **kwargs):

    """Accept any exception from value_mortality_damages() but inform about which one failed and write the target dir path to a logger file

    Parameters 
    ---------
    logger : None or str
        if str, path to log file to create.
    inputdir : str
    **kwargs : dict
        other arguments passed to value_mortality_damages()

    Returns 
    -------- 
    value_mortality_damages return type or None. 
    """

    print('running valuation for target directory : ' + inputdir)

    try:
        out =  value_mortality_damages(inputdir=inputdir, **kwargs)
    except Exception as e: 
        print('encountered an exception when running value_mortality_damages for target directory : ' + inputdir)
        if logger:
            print('logging')
            with open(logger, 'a') as log:
                log.write(inputdir + "\n")  
            with open(logger.replace('.log','') + "_exceptions.log", 'a') as log:
                log.write(inputdir + "\n" + str(e) + "\n")        
        print('passing...')
        out = None
        pass

    return out 

def concatenate_IR_damages(
    mc_root,
    vsl_dir,
    outputdir=None,
    only_variables='monetized_damages_vly_epa_scaled',
    n_jobs=30,
    moddict={'high' : 'OECD Env-Growth', 'low' : 'IIASA GDP'}, 
    test=0,
    debug=False,
    metainfo= { 'description' : 'complete montecarlo mortality damages due to climate change, accounting for adaptation and its costs, using value-of-life-year scaled-income mortality valuation methodology',
    'dependencies' : '3_valuation/2_calculate_damages/value_mortality_damages.py in mortality repository',
    'author' : 'Emile Tenezakis, etenezakis@uchicago.edu'     
    }, 
    iso_income=False):

    """Concatenates all impact-region level damages of a montecarlo simulation and can save to a netcdf4 file. 

    This function essentially does the job of iterating over target directories in a montecarlo output and calling value_mortality_damages() on it to compute (net of full costly adaptation) damages 
    for a given monetization approach, and concatenates all this into batch files.  

    It can take benefit from multiple CPUs and exceptions handling and reporting can be done through try_value_mortality_damages(). There are also test/debugging options. 

    Parameters
    ----------
    mc_root: str
        Root folder of raw Monte Carlo simulation output.
    vsl_dir:  str
        Location of VSL-related valuation inputs, including both the VSLs
        themselves (VSL, VLY, and Murphy-Topel) and the remaining life expectancy
        adjustments that are required for VLY and Murphy-Topel.
    outputdir: str or None 
        Directory in which to save output CSV file. Also used for the logging directory. If None, doesn't save the final data, and doesn't log, so no side
        effects.
    only_variables: str
        see value_mortality_damages() for options. 
    n_jobs: int
        Number of cores over which to parallelize damages calculation.
    test: int
        Should be a positive integer. If 0, the run is not a test and all files are processed. If>0, the looks at one random batch and stops at `test` random impact files among the set of existing files in that batch.
    debug: boolean 
        if True, `n_jobs` is ignored, and the codes runs a simple loop instead of parallelizing, of which the length is possibly minimized through `test`. 
    metainfo : dict
        meta data that will be passed as global attributes to the netcdf.
    iso_income : boolean
        should we use country level VSLs to compute damages? See 3_valuation/1_calculate_vsl/calculate_vsl.py. 
    """

    # create a log file path identified by time string 

    if outputdir:
        logger  = os.path.join(outputdir, "failed_targetdirs_" + str(time.time()).replace('.','') + ".log")
    else:
        logger = None

    if test:
        batches = random.sample(range(0,15), 1)
    else:
        batches = range(0,15)

    for i in batches:

        print('concatenating batch ' + str(i) + ' ...')
        wpath = f"{mc_root}/batch{i}/*/*/*/*"
        paths = sorted(glob.glob(wpath))
        parser = f"{mc_root}/batch*/*/*/*/*"

        if test:
            paths=random.sample(paths,test)

        if debug: 
            dslist = []
            for p in paths:
                dslist.append(value_mortality_damages(inputdir=p, parser=parser, vsl_ds=vsl_dir, moddict=moddict,
                    export_IR=True, export_IR_netcdf4=True, only_variables=only_variables,scenario='fulladapt', iso_income=iso_income))
        else: 
            with Parallel(n_jobs=n_jobs) as parallelize:
                dslist = parallelize(
                    delayed(try_value_mortality_damages)(
                        logger=logger, inputdir=inputdir, parser=parser, vsl_ds=vsl_dir, moddict=moddict,
                        export_IR=True, export_IR_netcdf4=True, only_variables=only_variables,scenario='fulladapt', iso_income=iso_income) for inputdir in paths)

        dslist = list(filter((None).__ne__, dslist))

        ds = (xr.combine_by_coords(dslist))

        ds.attrs['description'] = metainfo['description']
        ds.attrs['dependencies'] = metainfo['dependencies']
        ds.attrs['author'] = metainfo['author']

        if outputdir: 
            if iso_income:
                ds.to_netcdf(os.path.join(outputdir, "mortality_damages_IR_"+"batch"+str(i)+"_iso_income.nc4"))
            else: 
                ds.to_netcdf(os.path.join(outputdir, "mortality_damages_IR_"+"batch"+str(i)+".nc4"))

        del ds 
        gc.collect() # people here https://stackoverflow.com/questions/1316767/how-can-i-explicitly-free-memory-in-python say it can be useful in loops after `del`

def generate_global_damages(
    mc_root,
    ssp,
    vsl_dir,
    outputdir,
    suffix='',
    n_jobs=30,
    moddict={'high' : 'OECD Env-Growth', 'low' : 'IIASA GDP'},
    scenario='fulladapt'):
    """Generated global damages values for all monte carlo simulations.

    This function generates total monetized damages from climate change for
    purposes of estimating damage functions.

    Parameters
    ----------
    mc_root: Root folder of raw Monte Carlo simulation output.
    ssp: SSP scenario. SSP1 - SSP5
    vsl_dir:  Location of VSL-related valuation inputs, including both the VSLs
        themselves (VSL, VLY, and Murphy-Topel) and the remaining life expectancy
        adjustments that are required for VLY and Murphy-Topel.
    outputdir: Directory in which to save output CSV file.
    suffix: Adds suffix to output file name.
    n_jobs: Number of cores over which to parallelize.
    moddict: dictionary converting economic modeling scenarios to key-words.
    scenario: Scenario for which to calculate monetized damages.

    """

    wpath = f"{mc_root}/batch*/*/*/*/{ssp}"
    paths = sorted(glob.glob(wpath))
    parser = f"{mc_root}/batch*/*/*/*/*"

    vsl_ds, exp_ds = load_inputs(vsl_dir, ssp)

    with Parallel(n_jobs=n_jobs) as parallelize:
        dslist = parallelize(
            delayed(value_mortality_damages)(
                inputdir, parser, vsl_ds, exp_ds,
                moddict=moddict, scenario=scenario) for inputdir in paths)

    print('Combining coords...')
    ds = xr.combine_by_coords(dslist)

    if scenario != 'fulladapt':
        suffix = f'_{scenario}{suffix}'

    base = "mortality_global_damages_MC_poly4_uclip_sharecombo"
    (ds.to_dataframe()
        .to_csv(f'{outputdir}/{base}_{ssp}{suffix}.csv'))

    return ds



def generate_IR_damages(
    mc_root,
    vsl_dir,
    gcm_weights_dir,
    qtile,
    outputdir,
    ssp='SSP3',
    iam='low',
    rcp='rcp85',
    ir_model='vsl_epa_scaled',
    n_jobs=30,
    q_jobs=40,
    moddict={'high' : 'OECD Env-Growth', 'low' : 'IIASA GDP'},
    do_deryugina=False):
    """Generated impact-region level damages values for a subset of monte carlo
    simulations.

    This function generates impact region level monetized damages from climate
    change for diagnostic and communications purposes. For a single RCP,
    economic modeling scenario, RCP combination, it collapses across climate
    models and draws from statistcal uncertainty at one or more quantile or
    mean.

    Parameters
    ----------
    mc_root: Root folder of raw Monte Carlo simulation output.
    vsl_dir:  Location of VSL-related valuation inputs, including both the VSLs
        themselves (VSL, VLY, and Murphy-Topel) and the remaining life expectancy
        adjustments that are required for VLY and Murphy-Topel.
    gcm_weights_dir: directory containing climate model weights, which are used
        to compute the mean or quantile across the distribution of GCMs and
        monte carlo draws.
    outputdir: Directory in which to save output CSV file.
    ssp: SSP scenario. SSP1 - SSP5
    iam: economics modeling scenario. 'low' or 'high'
    rcp: RCP scenario. 'rcp45' or 'rcp85'
    n_jobs: Number of cores over which to parallelize damages calculation.
    q_jobs: Number of cores over which to parallelize quantile calculation (note
        that this is a separate paremeter because the quantile calculation step 
        is much less memory intensive.)
    moddict: dictionary converting economic modeling scenarios to key-words.
    do_deryugina : boolean 
        Allows to do life-year valuation using a rescaled life expectancy for the oldest,
        based on results from Deryugina et al (2019)
    """


    wpath = f"{mc_root}/batch*/{rcp}/*/{iam}/{ssp}"
    paths = sorted(glob.glob(wpath))
    parser = f"{mc_root}/batch*/*/*/*/*"

    vsl_ds, exp_ds = load_inputs(vsl_dir, ssp)

    with Parallel(n_jobs=n_jobs) as parallelize:
        dslist = parallelize(
            delayed(value_mortality_damages)(
                inputdir, parser, vsl_ds, exp_ds, moddict=moddict,
                export_IR=True, ir_model=ir_model, do_deryugina=do_deryugina) for inputdir in paths)

    weights = pd.read_csv(gcm_weights_dir)
    weights = xr.Dataset.from_dataframe(weights.set_index('gcm'))['weight']

    print('Combining coords...')
    ds = (xr.combine_by_coords(dslist))
    del dslist

    print('Calculating quantiles...')
    df = xr_weighted_quantile(
        ds, weights, qtile, q_jobs)

    gdp = vsl_ds.sel(model=moddict[iam]).gdp.to_dataframe()
    df = pd.merge(df, gdp, left_index=True, right_index=True)

    if not do_deryugina:
        suffix=""
    else:
        suffix="_deryugina_scalar"

    df.to_csv(f'{outputdir}/damages_IR_{ir_model}_{rcp}_{iam}_{ssp}{suffix}.csv')    

    return df


def xr_weighted_quantile(ds, weights, qtile, q_jobs):
    ''' Collapses xarray dataset containing monetized damages to weighted
    quantile.

    Parameters
    ----------
    ds: xarray dataset containing damages for each GCM & monte carlo batch.
    weights: GCM weights
    qtile: List of quantiles (and mean) over which to collapse damages, e.g.,
        ['mean', 'q25', 'q50', 'q75']
    q_jobs: Number of cores over which to parallelize quantile calculation
    
    '''
    ex = ds.sel(region = ds.region[0], year=ds.year[0]).squeeze()
    weights = weights.sel(gcm=ex.gcm)
    varn = [x for x in ex.data_vars.keys()]
    w = weights.broadcast_like(ex)
    w = w.transpose().values.flatten()

    dflist = []
    for k in varn:
        array = ds[k].values
        print(k)
        with Parallel(n_jobs=q_jobs) as parallelize:
            dslist = parallelize(
                delayed(weighted_quantile)(
                    array[:, :, j, i], w, qtile, (k,l)) for
                    ((i,k),(j,l)) in product(
                        enumerate(ds.region.values), enumerate(ds.year.values)))

        df = pd.DataFrame(dslist, columns = ['qtiles','key'])    

        dflist.append(pd.DataFrame(
            df.qtiles.to_list(), 
            columns=[f'{k}_{q}' for q in qtile],
            index=pd.MultiIndex.from_tuples(df.key, names=['region', 'year'])))

    return functools.reduce(
        lambda x, y: pd.merge(x, y, left_index=True, right_index=True), dflist)


def weighted_quantile(array, weights, qtile, in_tuple):
    ''' Collapses array for a single region, year combination over weighted GCMs
    and monte carlo draws.

    Parameters
    ----------
    ds: xarray dataset containing damages for each GCM & monte carlo batch.
    weights: GCM weights
    qtile: List of quantiles (and mean) over which to collapse damages, e.g.,
        ['mean', 'q25', 'q50', 'q75']
    q_jobs: Number of cores over which to parallelize quantile calculation
    
    '''


    statdict = {q: np.nan for q in qtile}
    stats = DescrStatsW(array.flatten(), weights)

    if 'mean' in qtile:
        statdict.update({'mean': stats.mean})

    qt = [x for x in qtile if 'mean' not in x]

    if qt:
        qout = stats.quantile([float(x.replace('q', '.')) for x in qt],
            return_pandas=False)

        statdict.update(dict(zip(qt, qout)))

    return list(statdict.values()), in_tuple
