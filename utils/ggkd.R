# Kernel Density Plotting Function

# This function returns a kernel density plot from a specific impact region from projection impacts

#----------------------------------------------------------------------------------

#create function that plots kernel density
ggkd <- function(df.kd = NULL,
                 topcode.ub = NULL, topcode.lb = NULL, 
                 yr = NULL, ir.name = NULL, 
                 x.label = NULL, y.label = "Density", 
                 kd.color = "grey50") {
  
  ir_fin <- df.kd

  ir_mean <- weighted.mean(ir_fin$value, ir_fin$weight) #calculate weighted mean
  
  #calculate weighted standard deviation
  weighted.sd <- function(x,w){ 
    mu <- weighted.mean(x,w)
    u <- sum(w*(x-mu)^2)
    d <- ((length(w)-1)*sum(w))/length(w)
    s <- sqrt(u/d)  
    return(s)
  }
  
  ir_sd <- weighted.sd(ir_fin$value, ir_fin$weight) 
  
  if(is.null(yr)){ #assign year
  yr <- ir_fin$year[1]
  }
  
  if(is.null(ir.name)){ #assign ir.name
    ir.name <- ""
  }
  
  ir_fin$weight <- ir_fin$weight/sum(ir_fin$weight) #normalize weights so they sum to 1
  
  if (!is.null(topcode.ub)){ #assign topcode if needed
    ir_fin$value <- ifelse(ir_fin$value>topcode.ub, topcode.ub, ir_fin$value) 
  }
  
  if (!is.null(topcode.lb)){ #assign bottomcode if needed
    ir_fin$value <- ifelse(ir_fin$value<topcode.lb, topcode.lb, ir_fin$value) 
  }
  

  print(paste0('--- IR MEAN IS', ir_mean, ' ----'))

  print(paste0('--- IR MEAN IS', mean(ir_fin$value), ' ----'))
  
  #calculate gcm-weighted mean per year per batch per IR 
  #ir_fin$wt_value <- ir_fin$value * ir_fin$weight #multiply value by weight 
  #ir_mean <- aggregate(list(value = (ir_fin$wt_value)), by = list(year = ir_fin$year, region = ir_fin$region), FUN = sum, na.rm = T) #get the average value across the batches for each year per IR
  
  #calculate density
  ir_fin_density <- data.frame(density(ir_fin$value, weights = ir_fin$weight)[c("x", "y")])
  print(names(ir_fin_density))
  print(mean(ir_fin_density$x))
  print(mean(ir_fin_density$y))


  #plot kernal density
  print(paste0("plotting kernel density for ", ir.name, yr))
  
  p <- ggplot(ir_fin_density, aes(x, y)) +
    geom_area(fill = kd.color, alpha = .9) + #full distribution #grey
    geom_area(data = subset(ir_fin_density, x < (ir_mean - ir_sd)), fill = "white", alpha = .3) + #1 sd below
    geom_area(data = subset(ir_fin_density, x < (ir_mean - (2*ir_sd))), fill = "white", alpha = .4) + #2 sd below
    geom_area(data = subset(ir_fin_density, x > (ir_mean + ir_sd)), fill = "white", alpha = .3) + #1 sd above
    geom_area(data = subset(ir_fin_density, x > (ir_mean + (2*ir_sd))), fill = "white", alpha = .4) + #2 sd above
    geom_hline(yintercept=0, size=.2, alpha = 0.5) + #zeroline
    geom_vline(xintercept = ir_mean, size=.9, alpha = 1, lty = "solid", color = "white") + #mean line
    #scale_x_continuous(expand=c(0, 0)) +
    theme_bw() +
    theme(panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(),
          panel.background = element_blank(), 
          axis.line = element_line(colour = "grey80", size = 0.2),
          plot.title = element_text(hjust=0.5, size = 10), 
          plot.caption = element_text(hjust=0.5, size = 7),
          axis.text.x = element_text(size=7, hjust=.5, vjust=.5, face="plain")) +
    xlab(x.label) + ylab(y.label) +
    labs(title = paste0("Kernel Density Plot ",yr," ",ir.name), 
         caption = paste0("GCM-weighted mean = ", round(ir_mean, 6)))  
  
  return(p)
}



