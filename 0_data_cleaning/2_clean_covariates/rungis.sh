#!/bin/bash

for f in $DB/0_data_cleaning/1_raw/Countries/USA/Shapefile/aggregation_inputs/gis*.txt 
do
	echo "$f"
	python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
	sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/BRA/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/CHL/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/CHN/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/EU/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/FRA/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/JPN/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/MEX/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

for f in $DB/0_data_cleaning/1_raw/Countries/IND/Shapefile/aggregation_inputs/gis*.txt
do
        echo "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/UDEL/GMFD/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/GMFD/BEST/g" "$f"
        python ~/climate_data_aggregation/gis/intersect_zonalstats_par.py "$f"
        sed -i "s/BEST/UDEL/g" "$f"

done

