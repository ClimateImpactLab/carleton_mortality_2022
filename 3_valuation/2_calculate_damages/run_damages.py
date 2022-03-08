import os
from calculate_damages import generate_IR_damages, generate_global_damages, concatenate_IR_damages

DB = os.getenv('DB')

calculate_global = True
calculate_ir = False
write_all = False 
write_all_iso_income = False

vsl_dir = f'{DB}/3_valuation/inputs'
mc_root = f'{cp.DB}/2_projection/3_impacts/main_specification/raw/montecarlo'
gcm_weights_dir = f'{DB}/2_projection/5_climate_data/gcm_weights.csv'

# Global damages for damage functions.
if calculate_global:
	outputdir=f'{DB}/3_valuation/global'
	for ssp in ['SSP2', 'SSP3', 'SSP4']:
		generate_global_damages(
			mc_root, ssp, vsl_dir, outputdir=outputdir, n_jobs=30)

# Impact-region level damages for diagnostics/communications.
if calculate_ir:
	outputdir=f'{DB}/3_valuation/impact_region'
	qt = ['mean', 'q05', 'q17', 'q25', 'q50', 'q75', 'q83', 'q95']

	generate_IR_damages(
		mc_root, vsl_dir, gcm_weights_dir, outputdir=outputdir,
		rcp='rcp85', n_jobs=45, q_jobs=70, qtile=qt)

	generate_IR_damages(
		mc_root, vsl_dir, gcm_weights_dir, outputdir=outputdir,
		rcp='rcp45', n_jobs=45, q_jobs=70, qtile=qt)

# Impact-region level complete damages concatenated and saved to netcdf4 for integration purposes
if write_all:
	outputdir=f'{DB}/3_valuation/impact_region/complete_damages'
	concatenate_IR_damages(mc_root=mc_root, vsl_dir=vsl_dir, outputdir=outputdir, n_jobs=45)

# Same as above, but with country level income
if write_all_iso_income:
	outputdir=f'{DB}/3_valuation/impact_region/complete_damages/iso_income'
	concatenate_IR_damages(mc_root=mc_root, vsl_dir=vsl_dir, outputdir=outputdir, n_jobs=40, iso_income=True, only_variables=['monetized_damages_vly_epa_scaled','monetized_damages_vsl_epa_scaled'], metainfo={'description' : 'complete montecarlo mortality damages due to climate change, accounting for adaptation and its costs, using value-of-life-year and value-of-statistical-life spatially adjusted with ratio of local income to US income. The VSL is constant at the country level for the valuation of deaths, and at the impact region level for costs.',
    'dependencies' : '3_valuation/2_calculate_damages/value_mortality_damages.py in mortality repository'   
    })
