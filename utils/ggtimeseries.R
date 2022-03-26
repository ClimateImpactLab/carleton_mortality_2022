# Timeseries function

# This function returns a global timeseries from projection impacts

#create function that plots timeseries
ggtimeseries <- function(df.list = NULL, 
    df.u = NULL, df.x = "year",
    ub = NULL, lb = NULL, 
    ub.2 = NULL, lb.2 = NULL, 
    ub.3 = NULL, lb.3 = NULL, 
    uncertainty.color = "black", 
    uncertainty.color.2 = "black", 
    uncertainty.color.3 = "black", 
    df.box = NULL, df.box.2 = NULL, 
    start.yr = 2000, end.yr = 2099, 
    legend.title = "Adaptation",
    alpha=1, 
    legend.breaks = c(
        "full adaptation",
        "income adaptation",
        "no adaptation",
        "total mortality-related costs"),
    legend.values = c("#009E73", "#E69F00", "#D55E00", "#000000"), 
    x.label = "Year", y.label = "Deaths per 100,000", 
    y.limits = NULL, x.limits = c(2000, 2100),
    title=NULL, y.breaks=NULL, legend.pos=NULL) {
    
    # Base plot.
    p <- ggplot() +
        geom_hline(yintercept=0, size=.2) +
        scale_x_continuous(expand=c(0, 0), limits=c(start.yr, end.yr)) +
        scale_colour_manual(
            name=legend.title,
            breaks=legend.breaks,
            values=legend.values) +
        scale_alpha_manual(name="", values=c(.7)) +
        theme_bw() +
        theme(
            panel.grid.major = element_blank(), 
            panel.grid.minor = element_blank(),
            panel.background = element_blank(), 
            axis.line = element_line(colour = "black")) +
        xlab(x.label) + ylab(y.label) +
        coord_cartesian(xlim = c(x.limits[1], x.limits[length(x.limits)]), ylim = y.limits)
        ggtitle(title) 

    if (!is.null(ub))
        p <- p + geom_ribbon(
            data = df.u,
            aes(x=df.u[,df.x], ymin=df.u[,ub], ymax=df.u[,lb]),
            fill = uncertainty.color, linetype=2, alpha=0.2)

    
    if (!is.null(ub.2))
        p <- p + geom_ribbon(
            data = df.u,
            aes(x=df.u[,df.x], ymin=df.u[,ub.2], ymax=df.u[,lb.2]),
            fill = uncertainty.color.2, linetype=2, alpha=0.2)
    
    
    if (!is.null(ub.3))
        p <- p + geom_ribbon(
            data = df.u,
            aes(x=df.u[,df.x], ymin=df.u[,ub.3], ymax=df.u[,lb.3]),
            fill = uncertainty.color.3, linetype=2, alpha=0.2)

    
    if (!is.null(df.list)) {
        
        #assign model names to each data frame
        for (j in seq_along(df.list)){
            df.list[[j]]$model <- legend.breaks[j]
        }

        df <- do.call("rbind", df.list)
        
        p <- p + geom_line(
            data=df,
            aes(x=df[,1], y=df[,2], color=model),
            alpha = alpha, size=1)

    }
    
    if(!is.null(df.box)){ #plot first boxplot
        p <- p + 
            geom_errorbar(
                aes(x=(end.yr+3), ymin = df.box[1], ymax = df.box[7]),
                color = "tomato4", lty = "dotted", width = 0) +
            geom_boxplot(
                aes(x=(end.yr+3), ymin = df.box[2], lower = df.box[3],
                    middle = df.box[4], upper = df.box[5], ymax = df.box[6]),
                width = 2, size = 0.5, fill="tomato2", color="tomato4",
                stat = "identity", alpha = 1) +
            scale_x_continuous(
                expand=c(0, 0),
                limits=c((x.limits[1]), (x.limits[2] + 2))) +
            coord_cartesian(
                ylim = y.limits,
                xlim = c(x.limits[1], (x.limits[2] + 2))) 
    }
    
    if(!is.null(df.box.2)){ #plot second boxplot
        p <- p + 
            geom_errorbar(
                aes(x=(end.yr+7), ymin = df.box.2[1], ymax = df.box.2[7]),
                color = "steelblue4", lty = "dotted", width = 0) +
            geom_boxplot(
                aes(x=(end.yr+7), ymin = df.box.2[2], lower = df.box.2[3],
                    middle = df.box.2[4], upper = df.box.2[5], 
                    ymax = df.box.2[6]),
                width = 2, size = 0.5, fill="steelblue2", color="steelblue4",
                stat = "identity", alpha = 1) +
            scale_x_continuous(
                expand=c(0, 0),
                limits=c((x.limits[1]), (x.limits[2] + 8))) +
            coord_cartesian(
                ylim = y.limits,
                xlim = c(x.limits[1], (x.limits[2] + 8)))
    }

    if (!is.null(y.breaks))     
        p = p + scale_y_continuous(breaks=y.breaks)
    
    if (!is.null(legend.pos))     
        p = p + theme(legend.position=legend.pos) 

    return(p)
} 
