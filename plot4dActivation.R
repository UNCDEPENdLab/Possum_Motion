#plot 4d activations against input
library(ggplot2)
library(reshape2)
library(plyr)

t2s_static <- 51 #51ms
te <- 30
tr <- 2
# discardTime <- 6
# setwd("~/Possum_Motion/output/10895_nomot_roiAvg_bandpass_18Jan2013-10:34")
# outputActivation <- read.table("output_roiAvg_bandpass_bb264_meanTimeCourses.1D", header=TRUE)[,-1]

roisToCompare <- 1:20 #which ROIs to plot

discardTime <- 14 #first activation starts at 16 s
fallOffVols <- 4  #number of vols at the end for BOLD fall-off
# setwd("~/possum_complete/10895_nomot_roiAvg_fullFreq_x10_05Feb2013-09:40/combined")
#setwd("~/possum_complete/10895_nomot_roiAvg_fullFreq_x5_0p1back_19Feb2013-10:40/combined")
#setwd("/Volumes/Serena/rs-fcMRI_motion_simulation/possum_complete/10895_nomot_roiAvg_fullFreq_x5_1p9hold_24Feb2013-20:54/combined")
#setwd("~/possum_complete/10895_nomot_roiAvg_fullFreq_x5_1p9hold_24Feb2013-20:54/combined")
setwd("~/possum_complete/10895_nomot_roiAvg_fullFreq_1p9hold_24Feb2013-20:52/combined")

# run <- "roiAvg_fullFreq_x10"
# run <- "roiAvg_fullFreq_x5_0p1back"
# run <- "roiAvg_fullFreq_x5_1p9hold"
run <- "roiAvg_fullFreq_1p9hold"

### READ:
##    1) Mean time courses for 264 ROIs from POSSUM activation input (T2* change units)
##    2) Mean time courses for 264 ROIs from POSSUM output (Raw scanner units)
##    3) Static tissue intensity from volumes 6 7 8, pre-activation (Raw scanner units) 

#ROI mean time courses from activation input to POSSUM (T2* change units)
inputActivation <- read.table("in_ROI_meanTimeCourses.1D", header=TRUE)[,-1] #first column is sub-brik name
activT <- read.table("~/Possum_Motion/defaults/activt_150_hold1p9")$V1
inputActivation$time <- activT
#inputActivation$time <- 1:nrow(inputActivation)*tr + discardTime #activation time course starts at 4th volume, so time starts with 8s
inputActivation$s <- factor("Input")

#ROI mean time courses from activation output (Raw scanner units)
outputActivation <- read.table("out_ROI_meanTimeCourses.1D", header=TRUE)[,-1]
#default sim has 0 2 4 6 8 for stabilization of magnetization
#10 12 14 are for static intensity
#activation is 16-154s
outputActivation$time <- 1:nrow(outputActivation)*tr + discardTime #scale volumes to seconds
outputActivation$s <- factor("Output")

#get baseline (static tissue) values for each ROI using the third volume (pre-activation)
baseline <- as.vector(t(read.table("baseline_ROI_mean.1D", header=TRUE)[,-1])) #obtain as vector


# graph of just outputs
# out.melt <- melt(outputActivation[,c(paste("Mean", 1:20, sep="_"), "time", "s")], id.vars=c("time", "s"))
# ggplot(out.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line()

#look at range and IQR for input 4d activation delta t2* units
act4d.inputsummary <- aaply(inputActivation[,1:264], 2, function(roi) {
  roi <- t(roi) #convert to column vector
  return(c(minAct=min(roi), maxAct=max(roi), medAct=median(roi), iqrAct=IQR(roi)))
})

act4d.agg <- aaply(act4d.inputsummary, 2, mean)

in.melt <- melt(inputActivation[,c(paste("Mean", 1:20, sep="_"), "time", "s")], id.vars=c("time", "s"))
# ggplot(in.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line()

#graph of inputs for first 20 ROIs (T2* units)
# png(paste0("~/Possum_Motion/output/possum_rest_", run, "_inputs_t2s.png"), width=11, height=6, units="in", res=150)
# ggplot(in.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line() +
#   xlab("Time (s)") + ylab("Activation input (delta T2*)") + ggtitle("POSSUM Resting State mean activation input within 20 ROIs")
# dev.off()

#obtain estimated t2* for each timepoint for select ROIs
inputActivation.t2ms <- as.matrix(inputActivation[,c(paste("Mean", roisToCompare, sep="_"))]) * 1000 + t2s_static #add t2*static and bring back to ms

#now can compute percent change
#intensity is S = S_0 * exp(-TE/T2*)
#so, static intensity S = S_0 * exp(-30/51) for a TE of 30
intens.static <- exp(-te/t2s_static)
inputActivation.intens <- exp(-te/inputActivation.t2ms)

#can compute expected proportion change as intens_sim / inten_static
#subtract 1 to represent change above or below static, multiply by 100 to get %
inputActivation.psc <- data.frame( ( (inputActivation.intens / intens.static) - 1 ) * 100 )

#convert column names to reflect that these are inputs
# names(inputActivation.psc) <- gsub("^Mean_", "InpM_", names(inputActivation.psc), perl=TRUE)
inputActivation.psc$time <- inputActivation$time #add time
inputActivation.psc$s <- factor("Input")

#plot PSC estimates for 4d input
# in.melt <- melt(subset(inputActivation.psc, select=-s), id.vars=c("time"))
# ggplot(in.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line()

# Scale output to percent signal change:
# Because we don't have a true baseline, the best option is not some sort of voxel mean scaling, but instead to use
# simulated volumes prior to onset of activation as the static tissue value since this is relatively steady state and
# will represent the WM + GM + CSF contributions to signal intensity.

outputActivation.psc <- data.frame(sapply(roisToCompare, function(x) {
  ( outputActivation[,paste("Mean", x, sep="_")]/baseline[x] - 1 ) * 100
}))

names(outputActivation.psc) <- names(outputActivation)[roisToCompare]
outputActivation.psc$time <- outputActivation$time
outputActivation.psc$s <- factor("Output")

all.psc <- rbind(outputActivation.psc, inputActivation.psc)

act.melt <- melt(all.psc, id.vars=c("time", "s"))

#such a scaling difference, that overlaying with color obscures in vs out
# ggplot(act.melt, aes(x=time, y=value, colour=s)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line() +

png(paste0("~/Possum_Motion/output/possum_rest_", run, "_in_vs_out_psc.png"), width=16, height=11, units="in", res=150)
ggplot(act.melt, aes(x=time, y=value)) + facet_wrap(~s*variable, scales="free_y") + geom_point() + geom_line() +
  xlab("Time (s)") + ylab("Percent Signal Change") + ggtitle(paste0("POSSUM resting-state using ", run, " activation: input versus output"))
dev.off()

# overlay inputs and outputs by color
# ggplot(act.melt, aes(x=time, y=value, color=s)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line() +
#   xlab("Time (s)") + ylab("Percent Signal Change") + ggtitle(paste0("POSSUM resting-state using ", run, " activation: input versus output"))


#time series correlation for rois of interest
outTS <- outputActivation.psc[1:(nrow(outputActivation.psc) - fallOffVols), roisToCompare]
inTS <- inputActivation.psc[seq(1, nrow(inputActivation.psc), 2), roisToCompare]

for (i in 1:ncol(outTS)) {
  cat("in.out r", i, " = ", round(cor(inTS[,i], outTS[,i])), "\n")
}



#Detritus

#only applied to old sims where activation started earlier
#looks like the first two time points have bigger T2* values...
#so need to dicard volumes 1-5 corresponding to second 0-8, begin activation at 6th TR (10 s)
# outputActivation[1:2, paste("Mean", 1:264, sep="_")] <- NA

# inputActivation <- read.table("input_roiAvg_bandpass_bb264_meanTimeCourses.1D", header=TRUE)[,-1]
# inputActivation <- read.table("input_roiAvg_fullFreq_x10_bb264_meanTimeCourses.1D", header=TRUE)[,-1]
