#' Vectorizes function `FUN` and calls all combinations of an arbitrary 
#' number of input vectors.
#'
#' Ex.
#' wrap_mapply(year=c(2050, 2090), region=c('reg1', 'reg2'), FUN=map_func)
#' 
#' Originally written for delta-beta, so most additional features are for data
#' in array format.
#'
#' @param FUN Function to vectorize.
#' @param engine Underlying function for vectorizing. Defaults mapply, 
#' but also accepts mcmapply. Returns a list of outputs from vectorized call.
#' @param stack_dim Dimension over which to stack the list output by engine.
#' @param array_to_stack If you want to stack your engine output to another
#' array, supply it here.
#' @param array_to_stack_dim Dimension over which to stack the array provided in
#' `array_to_stack`.
#' @param MoreArgs Additional arguments to `FUN`
#' @param SIMPLIFY Annoying thing that mapply and mcmapply do to output. FALSE
#' is appropriate in most cases. 
#' @param mc.cores Number of cores to use if you're using `mcmapply`
#' @return List of output or an n-dimensional array.
wrap_mapply <- function(
    ...,
    FUN,
    stack_dim=NULL,
    array_to_stack=NULL,
    array_to_stack_dim=NULL,
    MoreArgs=NULL,
    SIMPLIFY=FALSE,
    mc.cores=1,
    mc.silent=TRUE) {

    # Reformat inputs and call engine.
    eg_args = list(...)
    if (is.dflist(...)) 
        vect = eg_args
    else {
        eg_args[['stringsAsFactors']] = FALSE
        vect = as.list(do.call(expand.grid, eg_args))
    }

    vect[['MoreArgs']] = MoreArgs
    vect[['FUN']] = FUN
    vect[['SIMPLIFY']] = SIMPLIFY

    # If multicore, set number of cores.
    engine=mapply
    if (mc.cores > 1) {
        engine=mcmapply
        vect[['mc.cores']] = mc.cores
        vect[['mc.silent']] = mc.silent
    }

    outlist = do.call(engine, vect)

    # If provided a stacking dimension, stack output array.
    if (!is.null(stack_dim)) {
        out = stack(outlist, along=stack_dim)
    } else {
        out = outlist
    }

    # If provided another array, stack onto that array.
    if (!is.null(array_to_stack)) {
        out = stack(
            list(out, array_to_stack), 
            along = array_to_stack_dim)
    }

    return(out)
}


is.dflist = function(...) {
    test = list(...)
    for (n in names(test)) {
        if (typeof(test[[n]]) == 'list') {
            lst = test[[n]]
            for (m in lst) {
                if (is.data.frame(m)) {
                    return(TRUE)
                }
            }

        } else if (is.data.frame(test[[n]])) {
            return(TRUE)
        }
    }
    return(FALSE)
}

#' Stacks arrays while respecting names in each dimension and preserving 
#' attributes
#'
#' Code adapted from https://github.com/mschubert/narray/blob/master/R/stack.r
#'
#' @param ...         N-dimensional arrays, or a list thereof
#' @param along       Which axis arrays should be stacked on (default: new axis)
#' @param fill        Value for unknown values (default: \code{NA})
#' @param drop        Drop unused dimensions (default: FALSE)
#' @param keep_empty  Keep empty elements when stacking (default: FALSE)
#' @param allow_overwrite  Overwrite values if more arrays share same key
#' @param fail_if_empty    Stop if no arrays left after removing empty elements
#' @return            A stacked array, either n or n+1 dimensional
#' @export
stack = function(
    ...,
    along=length(dim(arrayList[[1]]))+1,
    fill=NA,
    drop=FALSE,
    keep_empty=FALSE,
    allow_overwrite=FALSE,
    fail_if_empty=TRUE) {

    arrayList = list(...)
    if (length(arrayList) == 1 && is.list(arrayList[[1]]))
        arrayList = arrayList[[1]]
    X = arrayList[[1]]

    if (typeof(along)=="character")
        along = attr(X, along)
    
    N = narray::stack(..., along=along, fill=fill, drop=drop,
        keep_empty=keep_empty, allow_overwrite=allow_overwrite, 
        fail_if_empty=fail_if_empty)

    if (!drop) {
        N = copy_attr(N, X)
    }
    return(N)
}


memo.csv = addMemoization(read.csv)