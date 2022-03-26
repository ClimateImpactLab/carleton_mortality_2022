'''
This script contains the functions that compute the life expectancies of 
each age group in each impact region in each year. This feeds into the calculation
of value of a life-year ('VLY') and the Murphy-Topel valuations, which are a modified VLY 
in which each life-year gets a different value based on age.
'''

import os
import numpy as np
import pandas as pd

DB = os.getenv('DB')


def life_expectancy_mt(data_path=DB):

	df = pd.read_csv(f'{data_path}/3_valuation/inputs/exp/raw/survival_ratio.csv')
	pop = pd.read_csv(f'{data_path}/3_valuation/inputs/exp/raw/population_agegroup_reshape.csv') 
	mt = pd.read_csv(f'{data_path}/3_valuation/inputs/exp/raw/Murphy_Topel.csv')

	# ---- Life Expectancy ---- #

	# Calculate expectancies from survival ratios
	df['expectancy_100plus'] = df.ratio100plus*5
	df['expectancy_95_99'] = df.ratio95_99*5+df.ratio95_99*df.expectancy_100plus
	df['expectancy_90_94'] = df.ratio90_94*5+df.ratio90_94*df.expectancy_95_99
	df['expectancy_85_89'] = df.ratio85_89*5+df.ratio85_89*df.expectancy_90_94
	df['expectancy_80_84'] = df.ratio80_84*5+df.ratio80_84*df.expectancy_85_89
	df['expectancy_75_79'] = df.ratio75_79*5+df.ratio75_79*df.expectancy_80_84
	df['expectancy_70_74'] = df.ratio70_74*5+df.ratio70_74*df.expectancy_75_79
	df['expectancy_65_69'] = df.ratio65_69*5+df.ratio65_69*df.expectancy_70_74
	df['expectancy_60_64'] = df.ratio60_64*5+df.ratio60_64*df.expectancy_65_69
	df['expectancy_55_59'] = df.ratio55_59*5+df.ratio55_59*df.expectancy_60_64
	df['expectancy_50_54'] = df.ratio50_54*5+df.ratio50_54*df.expectancy_55_59
	df['expectancy_45_49'] = df.ratio45_49*5+df.ratio45_49*df.expectancy_50_54
	df['expectancy_40_44'] = df.ratio40_44*5+df.ratio40_44*df.expectancy_45_49
	df['expectancy_35_39'] = df.ratio35_39*5+df.ratio35_39*df.expectancy_40_44
	df['expectancy_30_34'] = df.ratio30_34*5+df.ratio30_34*df.expectancy_35_39
	df['expectancy_25_29'] = df.ratio25_29*5+df.ratio25_29*df.expectancy_30_34
	df['expectancy_20_24'] = df.ratio20_24*5+df.ratio20_24*df.expectancy_25_29
	df['expectancy_15_19'] = df.ratio15_19*5+df.ratio15_19*df.expectancy_20_24
	df['expectancy_10_14'] = df.ratio10_14*5+df.ratio10_14*df.expectancy_15_19
	df['expectancy_5_9'] = df.ratio5_9*5+df.ratio5_9*df.expectancy_10_14
	df['expectancy_0_4'] = df.ratio0_4*5+df.ratio0_4*df.expectancy_5_9

	# Average expectancy over men and women
	df = df.groupby(['area','scenario','year','region'], as_index=False).mean()

	# Total pop within 5-year-age-bin
	pop = pop.groupby(['scenario', 'region', 'year'], as_index=False).sum()

	# Calculate total pop in each broad age group
	cols5_64 = ['Population5_9', 'Population10_14', 'Population15_19', 
		'Population20_24', 'Population25_29', 'Population30_34', 'Population35_39', 
		'Population40_44', 'Population45_49', 'Population50_54', 'Population55_59', 
		'Population60_64']
	pop['total5_64'] = pop[cols5_64].sum(axis=1)

	cols65plus = ['Population65_69', 'Population70_74', 'Population75_79', 
		'Population80_84', 'Population85_89', 'Population90_94', 'Population95_99', 
		'Population100plus']
	pop['total65plus'] = pop[cols65plus].sum(axis=1)

	# Calculate proportions
	pop['Proportion5_9'] = pop.Population5_9/pop.total5_64
	pop['Proportion10_14'] = pop.Population10_14/pop.total5_64
	pop['Proportion15_19'] = pop.Population15_19/pop.total5_64
	pop['Proportion20_24'] = pop.Population20_24/pop.total5_64
	pop['Proportion25_29'] = pop.Population25_29/pop.total5_64
	pop['Proportion30_34'] = pop.Population30_34/pop.total5_64
	pop['Proportion35_39'] = pop.Population35_39/pop.total5_64
	pop['Proportion40_44'] = pop.Population40_44/pop.total5_64
	pop['Proportion45_49'] = pop.Population45_49/pop.total5_64
	pop['Proportion50_54'] = pop.Population50_54/pop.total5_64
	pop['Proportion55_59'] = pop.Population55_59/pop.total5_64
	pop['Proportion60_64'] = pop.Population60_64/pop.total5_64

	pop['Proportion65_69'] = pop.Population65_69/pop.total65plus
	pop['Proportion70_74'] = pop.Population70_74/pop.total65plus
	pop['Proportion75_79'] = pop.Population75_79/pop.total65plus
	pop['Proportion80_84'] = pop.Population80_84/pop.total65plus
	pop['Proportion85_89'] = pop.Population85_89/pop.total65plus
	pop['Proportion90_94'] = pop.Population90_94/pop.total65plus
	pop['Proportion95_99'] = pop.Population95_99/pop.total65plus
	pop['Proportion100plus'] = pop.Population100plus/pop.total65plus

	# Merge
	df2 = df.merge(pop, how = 'inner', on = ['scenario','year','region'], validate = "1:m" )

	# Take weighted average & set final vars
	df2['Weighted5_9'] = df2.expectancy_5_9*df2.Proportion5_9
	df2['Weighted10_14'] = df2.expectancy_10_14*df2.Proportion10_14
	df2['Weighted15_19'] = df2.expectancy_15_19*df2.Proportion15_19
	df2['Weighted20_24'] = df2.expectancy_20_24*df2.Proportion20_24
	df2['Weighted25_29'] = df2.expectancy_25_29*df2.Proportion25_29
	df2['Weighted30_34'] = df2.expectancy_30_34*df2.Proportion30_34
	df2['Weighted35_39'] = df2.expectancy_35_39*df2.Proportion35_39
	df2['Weighted40_44'] = df2.expectancy_40_44*df2.Proportion40_44
	df2['Weighted45_49'] = df2.expectancy_45_49*df2.Proportion45_49
	df2['Weighted50_54'] = df2.expectancy_50_54*df2.Proportion50_54
	df2['Weighted55_59'] = df2.expectancy_55_59*df2.Proportion55_59
	df2['Weighted60_64'] = df2.expectancy_60_64*df2.Proportion60_64

	df2['Weighted65_69'] = df2.expectancy_65_69*df2.Proportion65_69
	df2['Weighted70_74'] = df2.expectancy_70_74*df2.Proportion70_74
	df2['Weighted75_79'] = df2.expectancy_75_79*df2.Proportion75_79
	df2['Weighted80_84'] = df2.expectancy_80_84*df2.Proportion80_84
	df2['Weighted85_89'] = df2.expectancy_85_89*df2.Proportion85_89
	df2['Weighted90_94'] = df2.expectancy_90_94*df2.Proportion90_94
	df2['Weighted95_99'] = df2.expectancy_95_99*df2.Proportion95_99
	df2['Weighted100plus'] = df2.expectancy_100plus*df2.Proportion100plus

	wcols5_64 = ['Weighted5_9', 'Weighted10_14', 'Weighted15_19', 
		'Weighted20_24', 'Weighted25_29', 'Weighted30_34', 'Weighted35_39', 
		'Weighted40_44', 'Weighted45_49', 'Weighted50_54', 'Weighted55_59', 
		'Weighted60_64']

	wcols65plus = ['Weighted65_69', 'Weighted70_74', 'Weighted75_79', 
		'Weighted80_84', 'Weighted85_89', 'Weighted90_94', 'Weighted95_99', 
		'Weighted100plus']

	df2['expectancy_older'] = df2[wcols5_64].sum(axis=1)+2.5
	df2['expectancy_oldest'] = df2[wcols65plus].sum(axis=1)+2.5
	df2['expectancy_young'] = df2['expectancy_0_4']+2.5
	df2['expectancy_25_29_mt'] = df2['expectancy_25_29'] + 2.5

	# ---- Murphy-Topel ---- #

	# Set age groups
	mt['agegroup'] = 1
	mt.loc[mt['Age']>4,'agegroup'] = 2
	mt.loc[mt['Age']>64,'agegroup'] = 3

	# Avr. males & females
	mt['avg'] = mt[['Males','Females']].mean(axis=1)

	# collapse to 5-year-age-bin
	xs = np.arange(0,105,5)
	for x in xs:
		mt.loc[mt['Age']>=x, 'agebin' ] = x

	mt = mt[['Age','agegroup','agebin','avg']]

	# Generate adj. factors relative to max value @ 25_29 bin.
	mt_bin = mt.groupby(['agebin'], as_index = False).mean()
	mt_bin['factor'] = mt_bin.avg/np.max(mt_bin.avg) 

	# weighted averages
	mt_mat_age2 = mt_bin.loc[mt_bin['agegroup']==2,'factor'].as_matrix()
	mcols5_64 = ['Proportion5_9', 'Proportion10_14', 'Proportion15_19', 'Proportion20_24',
		'Proportion25_29', 'Proportion30_34', 'Proportion35_39', 'Proportion40_44', 
		'Proportion45_49', 'Proportion50_54', 'Proportion55_59', 'Proportion60_64']
	df2['mt_older'] = df2[mcols5_64].multiply(mt_mat_age2, axis=1).sum(axis=1)

	mt_mat_age3 = mt_bin.loc[mt_bin['agegroup']==3,'factor'].as_matrix()
	mcols65plus = ['Proportion65_69', 'Proportion70_74', 'Proportion75_79', 
		'Proportion80_84', 'Proportion85_89', 'Proportion90_94', 
		'Proportion95_99', 'Proportion100plus']
	df2['mt_oldest'] = df2[mcols65plus].multiply(mt_mat_age3, axis=1).sum(axis=1)

	df2['mt_young'] = mt_bin.loc[mt_bin['agegroup']==1,'factor'].as_matrix()[0]

	# export
	export_cols = ['region', 'year', 'scenario',
		'expectancy_young','expectancy_older','expectancy_oldest',
		'expectancy_25_29_mt', 'mt_young','mt_older','mt_oldest']

	df2[export_cols].to_csv(os.path.join(data_path, '3_valuation/inputs/exp/raw/life_expectancy_mt.csv'), index = False)
