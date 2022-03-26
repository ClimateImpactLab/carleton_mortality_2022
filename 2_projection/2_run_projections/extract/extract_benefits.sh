#!/bin/bash

# Iterables
ssplist=( SSP3 ) # SSP1, SSP2, SSP3, SSP4, SSP5 [Note: SSPs 2-4 currently available]
rcplist=( rcp85 ) # rcp45, rcp85
iamlist=( low ) # low, high
agelist=( combined )  # young, older, oldest, combined

# Specifications
format="edfcsv" # edfcsv, valuescsv
spatial="aggregated" # aggregated, ir_level
unit="rates" # rates, levels
basename=Agespec_interaction_GMFD_POLY-4_TINV_CYA_NW_w1
default_config=extract_mortality
show_output='TRUE'

DATA="${DB}/2_projection/3_impacts/main_specification" 
results_root="$DATA/raw/montecarlo"

CONFIG=${REPO}/carleton_mortality_2022/2_projection/2_run_projections/extract/extract_mortality.yml
echo $CONFIG

cd ${REPO}/prospectus-tools/gcp/extract
#conda activate risingverse-py27

for ssp in ${ssplist[@]}; do
	for rcp in ${rcplist[@]}; do
		for iam in ${iamlist[@]}; do
			for age in ${agelist[@]}; do

				output=${DATA}/extracted/${rcp}/${iam}/${ssp} # "montecarlo_extracted" if running new
				echo $output
				mkdir -p ${output}

				outsuffix1="-${age}-incbenefits-${iam}-${spatial}-${unit}-${format}"
				outsuffix2="-${age}-climbenefits-${iam}-${spatial}-${unit}-${format}"

				valcol="--column=rebased"

				srcfile_inc="${basename}-${age}-incadapt-aggregated" 
				srcfile_na="${basename}-${age}-noadapt-aggregated"
				srcfile_fa="${basename}-${age}-aggregated"
				srcfile_hc="${basename}-${age}-histclim-aggregated"

				

				incbenefits = ${srcfile_inc} -${srcfile_hc} -${srcfile_na}
				climbenefits = ${srcfile_fa} -${srcfile_hc} -${srcfile_inc} ${srcfile_hc}


				# incbenefits = incadapt - noadapt
				python quantiles.py ${CONFIG} --results_root=${results_root} --output-format=${format} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --suffix=${outsuffix1} ${valcol} --output-dir=${output} ${srcfile_inc} -${srcfile_hc} -${srcfile_na}
				# climbenefits = fulladapt - incadapt
				python quantiles.py ${CONFIG} --results_root=${results_root} --output-format=${format} --only-rcp=${rcp} --only-iam=${iam} --only-ssp=${ssp} --suffix=${outsuffix2} ${valcol} --output-dir=${output} ${srcfile_fa} -${srcfile_hc} -${srcfile_inc} ${srcfile_hc}

			done
		done
	done	
done
