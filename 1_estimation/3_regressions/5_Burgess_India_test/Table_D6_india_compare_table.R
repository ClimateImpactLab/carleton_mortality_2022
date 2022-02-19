##############################

# purpose : make a latex table with predicted deaths in India from different models and their comparisons. 

# input : response functions and their confidence intervals. stored in /mnt/Global_ACP/MORTALITY/release_2020/output/1_estimation/figures/9_india_test/Agespec_interaction_nointeraction_IND_responses.dta

##############################

REPO <- Sys.getenv(c("REPO"))
DB <- Sys.getenv(c("DB"))
OUTPUT <- Sys.getenv(c("OUTPUT"))

library(data.table)
library(glue)
library(haven)
library(xtable)

#' Applies a range of input values to a model
#' @param func character that identifies a response func
#' @param file character, file containing the model data
#' @param input character, file containing the input data
#' @return data table with [func, y, lowerci, upperci] columns. The two latter are NA if they don't exist in the underlying data. 
Predict <- function(func, file, input, confidence_intervals=TRUE){

	data <- as.data.table(read_dta(file)) #read models data

	# if (!all(c(paste0('lowerci_', func), paste0('upperci_', func)) %in% names(data))) data[,paste0('lowerci_', func):=Inf][,paste0('upperci_', func):=Inf] #super dirty trick
	
	data <- subset(data, select=c('tavg_poly_1_GMFD', paste0('y_', func), paste0('lowerci_', func), paste0('upperci_', func))) #keep chosen model data

	setnames(data,c('x', 'y', 'lowerci', 'upperci')) #standard names

	input <- as.data.table(read_dta(input)) #read input value data

	setnames(input,c('x', 'value')) #standard name

	setkey(data, x) #sort
	setkey(input, x) #sort

	DT <- na.omit(data[input]) #merge and omit x values lost

	for (j in c('y','lowerci', 'upperci')) set(DT, j = j, value = sum(DT[[j]]*DT[['value']])) #dot product computation

	DT <- DT[1,.(y, lowerci, upperci)][,func:=func][] #keep unique row
	return(DT)
}

#' @param data data table, with predictions and CIs returned by Predict()
#' @param reference_function see MakeTable
#' @param alternative_functions see MakeTable
#' returns a named list of logicals, with names being the alternative models, and the logicals indicating whether the point estimate of the 
#' predictions of the alternative_functions fall in the CI of the reference model
BelongsToCI <- function(data, reference_function, alternative_functions){
	result <- list()
	for (alt in alternative_functions){
		result[[alt]] <- data[func==alt, y]>=data[func==reference_function, lowerci] | data[func==alt, y]<=data[func==reference_function, upperci]
 	}

 	return(result)
}

#' Builds a table of the form : < model | difference | belongs to reference model confidence interval ? >
#' where model is the name of a model that's an alternative to the reference,
#' difference is the difference in predictions with the reference model in absolute, 
#' whith the prediction being the sum of the models values when x is passed as an argument value.
#' @param reference_function character
#' @param alternative_functions character
#' @param latex logical
#' @param save logical or character
#' @param ... additional parameters passed to Predict()
MakeTable <- function(reference_function, alternative_functions, latex=FALSE, save=FALSE, ...){

	DT <- rbindlist(mapply(func=c(reference_function, alternative_functions), FUN=Predict, MoreArgs=list(...),SIMPLIFY=FALSE)) #make predictions for each model
	#answers <- BelongsToCI(DT,reference_function, alternative_functions) #check CI
	DT <- DT[,y_diff:=(y-DT[1,y])] #compute absolute diff w.r. to first row of table (because by construction it's the reference one -- see right above line)
	DT <- DT[,y_diff_pct:=(y-DT[1,y])/DT[1,y]*100] #compute absolute diff w.r. to first row of table (because by construction it's the reference one -- see right above line)

	# DT <- DT[2:nrow(DT),.(y,func)] #discard reference model
	#DT[,CI:=unlist(answers)][,CI:=ifelse(CI, 'yes','no')]#add CI check
	DT <- DT[,.(func,y, lowerci, upperci, y_diff, y_diff_pct)] #reorder
	setnames(DT,c('model','point estimate','lowerbound','upperbound','absolute diff', '% diff')) #nice names

	if (latex){
		out <- xtable(DT) #makes a latex table
		if (!isFALSE(save)){
			print(xtable(out, type = "latex"), file = save, include.rownames=FALSE) #saves it
		} else {
			print(out, include.rownames=FALSE)
		}
	} else {
		return(DT)
	}

}

MakeTable(reference_function='country_IND',
          alternative_functions=c('main_av_IND_full','main_av_IND_no_tbar','main_av_IND_no_income'),
        file=glue('{OUTPUT}/figures/Agespec_interaction_nointeraction_IND_responses.dta'),
        input=glue('{OUTPUT}/figures/tavg_bins_collapsed_IND.dta', latex=TRUE))