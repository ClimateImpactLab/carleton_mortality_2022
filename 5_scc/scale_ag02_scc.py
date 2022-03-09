"""
This script takes SCC output from `pFAIR` based upon an EPA VSL and converts to
an estimate of SCC based upon Ashenfelter and Greenstone (2002). This conversion
is possible because the analysis income-scales VSLs using an income elasticity
of 1. 

To operate, simply pass the path to a csv file output from `pFAIR` as an
argument to this function. It will perform the scaling and save a file in the
same directory with the suffix "_ag02". The file will append the scaled SCC
values to the original file before saving the new one.
"""

import os
import sys
import pandas as pd
import numpy as np

path = sys.argv[1]
df = pd.read_csv(path)

ftype = path[-4:]

if ftype != '.csv':
	print("File specified is not a csv")
	raise ValueError

path_out = path[:-4] + '_ag02.csv'

exclude = ['Unnamed: 0', 'discrate', 'rcp', 'age_adjustment', 'vsl_value',
	'heterogeneity', 'time_cut']

# Ratio of AG02 VSl to EPA VSL:
vsl_adjust = .2613994

# GDPpc data from Fed (data/3_valuation/inputs/adjustments/fed_income_inflation.csv)
# GDPpc in 2019 (2005$) (Consistent with EPA VSL)
gdppc_2019 = 50286.84
# GDPpc in 1984 (2005$) (Consistent with AG02 VSL)
gdppc_1984 = 28224.61

# Generate adjustment factor for converting denominator in income-scaling ratio
# to the relevant year for AG02 VSL
income_adjust = gdppc_2019 / gdppc_1984

is_numeric = lambda x: np.issubdtype(x.dtype, np.number)
include = [x for x in list(df) if x not in exclude and is_numeric(df[x])]
df_ag = df.loc[df.vsl_value=='epa'].copy()
for var in include:
	df_ag[var] = df_ag[var] * income_adjust * vsl_adjust
df_ag['vsl_value'] = 'ag02'

df = df.append(df_ag)

df.to_csv(path_out, index=False)
print("Appended AG SCC")
print(f"Saved: {path_out}")
