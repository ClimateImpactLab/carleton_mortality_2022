import pandas as pd
import xarray as xr
import os

from pkg_resources import parse_version

CURRENT_VERSION = '2.1'

# TODO: add a version history and descriptions

def get_filter_mask(version=CURRENT_VERSION):
    '''
    Parameters
    ----------
    version : str, int, float, Version, optional
        climate parameters version number
    '''
    version = parse_version(str(version))
    
    os.getcwd() 
    if (version == parse_version('3.0')):
        filters_fp = (
            '{}/climate/parameters/latinhypercube/parameter_filters_truncate_ecs_v3.0.nc'.format(os.path.dirname(os.path.realpath(__file__)))) 

        with xr.open_dataset(filters_fp) as filters_ds:
#             import warnings
#             warnings.warn("v3.0 climate parameters do not require additional filters by default.")
#             the_mask = (filters_ds.ipt_time_to_dT_lt_0_passing_mask)
            the_mask = (filters_ds.truncate_at_ecs990symmetric_passing_mask)
            return the_mask
    
    elif (version == parse_version('2.2')):
        # Note, this is v2.1 climate parameters and default masks *with the additional ECS 1-99 truncation mask*
        # There exists another use of v2.2 in our climate data, not implemented in this file (phew).
        #   That other v2.2 is specific to integration and is *unused*. It is a version of the v2.1 climate params
        #   run with FaIR 1.6.0 on CMIP6 emissions pathways using the CIL FAIR fork.
        filters_fp = (
            '{}/climate/parameters/parameter_filters_rwf_tau4_iptcriteria_v2.1_newiptemissions.nc'.format(os.path.dirname(os.path.realpath(__file__)))) 

        ecs_fp = (
            '{}/climate/parameters/parameter_filters_truncate_ecs_postipt_v2.1.nc'.format(os.path.dirname(os.path.realpath(__file__)))) 
        
        with xr.open_dataset(filters_fp) as filters_ds:
            #print(filters_ds)
            
            with xr.open_dataset(ecs_fp) as ecs_ds:
                
                the_mask = (filters_ds.rwf_mask
                                 & filters_ds.tau4_mask
                                 & filters_ds.ipt_time_to_dT_lt_0_passing_mask)
                ecsmask = ecs_ds.truncate_at_ecs990symmetric_passing_mask
                return (the_mask & ecsmask)
    
    elif (version == parse_version('2.1')) or (version == parse_version('2.0')):
        
        filters_fp = (
            '{}/climate/parameters/parameter_filters_rwf_tau4_iptcriteria_v2.1_newiptemissions.nc'.format(os.path.dirname(os.path.realpath(__file__)))) 

        with xr.open_dataset(filters_fp) as filters_ds:
            #print(filters_ds)
            the_mask = (filters_ds.rwf_mask
                             & filters_ds.tau4_mask
                             & filters_ds.ipt_time_to_dT_lt_0_passing_mask)
            return the_mask
    elif (version == parse_version('1.0')):
        # read in old filters:
        filtered_parameter_indices = pd.read_csv(
            'climate/parameters/filtered_parameter_indices.csv', 
            index_col=0)

        with xr.Dataset(filtered_parameter_indices) as filters_ds:
            filters_ds.rename({'dim_0':'simulation'})
            the_mask = filters_ds.ipt_dT_lt_0
            return the_mask
    else:
        raise NotImplementedError('{} is not a valid climate version number'.format(parse_version(version)))
        
def get_parameters(filtered=True, array=True, version=CURRENT_VERSION, droprwf=True):
    '''
    Parameters
    ----------
    filtered : bool, optional
        specifies whether to filter the climate parameters
    array : bool, optional
        specifies whether to return parameters as np.array or as xarray.DataArray
    version : str, int, float, Version, optional
        climate parameters version number
    '''
    version = parse_version(str(version))
    
    if (version == parse_version("3.0")):
        print("These parameters are in beta mode") # @@@
        
        with xr.open_dataset(
            # This file is part of the git repo
            '{}/climate/parameters/latinhypercube/climate_parameters_truncated_latin_hypercube_n3000_seed2070.nc'.format(os.path.dirname(os.path.realpath(__file__)))) as params_ds:

            if droprwf:
                params_ds = params_ds.drop('rwf')

            if filtered:
                climate_params = params_ds.where(get_filter_mask(version = version),drop=True).to_array(dim='parameter')
            else:
                climate_params = params_ds.to_array(dim='parameter')#.T.values
                
            if array:
                return climate_params.sel(parameter=["tcr","ecs","d2","tau4"]).T.values
            else:
                return climate_params
    
    elif (version == parse_version('2.1')) or (version == parse_version('2.0')):


        with xr.open_dataset(
            # This file is part of the git repo
            '{}/climate/parameters/original_parameter_samples_with_rwf_v2_2019-02-01-22-50-59.nc'.format(os.path.dirname(os.path.realpath(__file__)))) as params_ds:

            if droprwf:
                params_ds = params_ds.drop('rwf')
                
            if filtered:
                climate_params = params_ds.where(get_filter_mask(version = version),drop=True).to_array(dim='parameter')#.T.values
            else:
                climate_params = params_ds.to_array(dim='parameter')#.T.values
                
            if array:
                return climate_params.sel(parameter=["tcr","ecs","d2","tau4"]).T.values
            else:
                return climate_params

    elif  (version == parse_version('1.0')):
        with xr.open_dataset('{}/climate/parameters/original_parameter_samples.nc'.format(os.path.dirname(os.path.realpath(__file__)))) as params_ds:
            
            if filtered:
                climate_params = params_ds.where(get_filter_mask(version = version)).to_array(dim='parameter')#.T.values
            else:
                climate_params = params_ds.to_array(dim='parameter')#.T.values
            
            if array:
                return climate_params.T.values
            else:
                return climate_params
    else:
        raise NotImplementedError('{} is not a valid climate version number'.format(parse_version(version)))
        
def get_median_climate_params(version = CURRENT_VERSION, filtered = True):
    # add a filtered arg b/c latin hypercube (v3) params do not have any additional filters.
    cp = get_parameters(filtered=True, 
                        array=False, 
                        version = version)
    
    return cp.quantile(0.5,dim='simulation')
