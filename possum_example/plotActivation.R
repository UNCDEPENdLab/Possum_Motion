library(ggplot2)
library(reshape2)

t2s_static <- 51 #51ms
te <- 30
tr <- 2
discardTime <- 6
setwd("~/Possum_Motion/possum_example")

#output mean timecourses for 8 ROIs
activationResults <- read.table("activation_meanTimeCourses.1D", header=TRUE)[,-1]
activationResults$time <- 1:nrow(activationResults)*tr + discardTime #activation time course starts at 4th volume, so time starts with 8s
activationResults$s <- factor("Output")

#get baseline values for each ROI using the third volume (pre-activation)
baseline <- as.vector(t(read.table("activation_baselinemean.1D", header=TRUE)[,-1])) #obtain as vector

#input 3d timecourse (in 3s TR terms).
#this modulates the 3d NIFTI file: T2s_est (v) = T2s_static + 3dt * activation (v)
time3d <- read.table("activation3Dtimecourse", col.names=c("time", "actMult"))

#mean activation values in simulation input 3D NIFTI file (should be in terms of T2* change)
actInput <- read.table("activation_inputVals.1D", header=TRUE)[,-1]

#resample activation scaling onto 2s TR grid using linear interpolation
time3d.2TR <- data.frame(approx(x=time3d$time, y=time3d$actMult, xout=activationResults$time))
names(time3d.2TR) <- c("time", "actMult")

actInput.meanOnly <- actInput[,grepl("^Mean", names(actInput), perl=TRUE)]

#multiple mean ROI activation by time scaling factor to get estimated t2* change relative to static
act_x_time <- outer(as.numeric(time3d.2TR$actMult), as.numeric(actInput.meanOnly))
colnames(act_x_time) <- names(actInput.meanOnly)

#just look at range of input values
act3d.inputsummary <- aaply(act_x_time, 2, function(roi) {
  roi <- t(roi) #convert to column vector
  return(c(minAct=min(roi), maxAct=max(roi), medAct=median(roi), iqrAct=IQR(roi)))
})

act3d.agg <- aaply(act3d.inputsummary, 2, mean)


#obtain estimated t2* for each timepoint
act_x_time.t2ms <- act_x_time * 1000 + t2s_static #add t2*static and bring back to ms

#now can compute percent change
#intensity is S = S_0 * exp(-TE/T2*)
#so, static intensity S = S_0 * exp(-30/51) for a TE of 30
intens.static <- exp(-te/t2s_static)
act_x_time.intens <- exp(-te/act_x_time.t2ms)

#can compute expected proportion change as intens_sim / inten_static
#subtract 1 to represent change above or below static, multiply by 100 to get %
act_x_time.psc <- data.frame( ( (act_x_time.intens / intens.static) - 1 ) * 100 )

#convert column names to reflect that these are inputs
# names(act_x_time.psc) <- gsub("^Mean_", "InpM_", names(act_x_time.psc), perl=TRUE)
act_x_time.psc$time <- time3d.2TR$time #add time
act_x_time.psc$s <- factor("Input")

#because we don't have a true baseline, the best option is not one of these scalings, but instead to use
#the third simulated volume as the static tissue value since this is steady state and will represent WM + GM + CSF contributions.

activation.psc <- data.frame(sapply(1:8, function(x) {
  ( activationResults[,paste("Mean", x, sep="_")]/baseline[x] - 1 ) * 100
}))
names(activation.psc) <- names(activationResults)[1:8]
activation.psc$time <- activationResults$time
activation.psc$s <- factor("Output")

all.psc <- rbind(activation.psc, act_x_time.psc)

act.melt <- melt(all.psc, id.vars=c("time", "s"))

# ggplot(act.melt, aes(x=time, y=value)) + facet_wrap(~s*variable, scales="free_y") + geom_point() + geom_line()
ggplot(act.melt, aes(x=time, y=value, colour=s)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line()

# cor(activationResults[,-1])

#conclusion: looks clean and with perfect temporal correspondence!!



#obtain activation input in terms of percent signal change. (more conventional scaling) 
# act_x_time.psc <- data.frame(apply(act_x_time, 2, function(column) {
#   column <- column + 100 #Add 100 because values too close to zero for scaling to work properly
#   return(100*((column - mean(column)) / mean(column)))
# #   return((column/mean(column)) * 100 )
# }))

#clunky sapply version
# act_x_time <- sapply(actInput.meanOnly, function(x) { x * time3d.2TR$actMult }) #multiple activation by time

#try to scale to PSC, but don't have a baseline per se, which makes it hard
# activation.psc <- apply(activationResults[,paste("Mean", 1:8, sep="_")], 2, function(column) {  
#   #   return( ( ( column/min(column) ) - 1 ) * 100 )
#   #   return(100*((column - mean(column)) / mean(column)))
#   #   return((column/mean(column)) * 100 )
#   #   cmean <- mean(column)
#   #   return((column - cmean)/mean(c(c))
#   #   return(column/mean(column))
# })

#should be able to work backwards from activation input and timecourse to observed activations
# actInput.melt <- melt(actInput)
# actInput.melt$roiNum <- as.numeric(gsub("\\w+_(\\d+)", "\\1", actInput.melt$variable, perl=TRUE))

# activationResults <- merge(activationResults, time3d.2TR, by="time")
# activationResults <- rbind(activationResults, act_x_time.psc)
# activationResults <- merge(activationResults, act_x_time.psc, by="time")
