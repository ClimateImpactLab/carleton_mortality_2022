#!/bin/bash

for f in $DB/0_data_cleaning/1_raw/Countries/CHN/Shapefile/aggregation_inputs/aggregate*.txt 
do
	echo "$f"
	python $REPO/climate_data_aggregation/aggregation/merge_transform_average.py "$f"

done
