'''
"master" script that generates inputs to the valuation of impacts. In particular, it generates:
(1) the time-varying and spatially-varying monetary VSLs that are multiplied by the mortality risk impacts to achieve monetized damages and
(2) the age-adjustment factors that are required for valuation assumptions which heterogeneously value the three age groups.

These intermediate inputs necessary to value MC inputs are currently saved in DB/3_valuation/inputs;
so the user is not required to run this script to proceed to the damage function step.
'''

from life_expectancy_and_mt import life_expectancy_mt
from calculate_vsl import make_iryear_vsl
from joblib import Parallel, delayed
from itertools import product
import os 

DB = os.getenv('DB')

calculate_life_expectancy = True
calculate_vsl_data = True

# Calculate remaining life expectancies and the Murphy-Topel adjustment factors.
if calculate_life_expectancy:
    life_expectancy_mt(DB)

# Calculate income-scaled and population-weighted average VSL/VLY from 
if calculate_vsl_data:
    ssp_list = ['SSP1', 'SSP2', 'SSP3', 'SSP4', 'SSP5']
    with Parallel(n_jobs=5) as parallelize:
        dslist = parallelize(
            delayed(make_iryear_vsl)(
                ssp=ssp, data_path=DB, outputpath='3_valuation/inputs') for ssp in ssp_list)

