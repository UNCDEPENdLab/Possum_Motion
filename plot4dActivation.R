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
# setwd("~/possum_complete/10895_nomot_roiAvg_fullFreq_x10_05Feb2013-09:40/combined")
setwd("~/possum_complete/10895_nomot_roiAvg_fullFreq_x5_0p1back_19Feb2013-10:40/combined")

# run <- "roiAvg_fullFreq_x10"
run <- "roiAvg_fullFreq_x5_0p1back"

#get mean time courses for all 264 ROIs
outputActivation <- read.table("out_ROI_meanTimeCourses.1D", header=TRUE)[,-1]
outputActivation$time <- 1:nrow(outputActivation)*tr + discardTime #scale volumes to seconds
outputActivation$s <- factor("Output")

#get baseline (static tissue) values for each ROI using the third volume (pre-activation)
baseline <- as.vector(t(read.table("baseline_ROI_mean.1D", header=TRUE)[,-1])) #obtain as vector

# graph of just outputs
# out.melt <- melt(outputActivation[,c(paste("Mean", 1:20, sep="_"), "time", "s")], id.vars=c("time", "s"))
# ggplot(out.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line()

inputActivation <- read.table("in_ROI_meanTimeCourses.1D", header=TRUE)[,-1]
inputActivation$time <- 1:nrow(inputActivation)*tr + discardTime #activation time course starts at 4th volume, so time starts with 8s
inputActivation$s <- factor("Input")

#look at range and IQR for input 4d activation delta t2* units
act4d.inputsummary <- aaply(inputActivation[,1:264], 2, function(roi) {
  roi <- t(roi) #convert to column vector
  return(c(minAct=min(roi), maxAct=max(roi), medAct=median(roi), iqrAct=IQR(roi)))
})

act4d.agg <- aaply(act4d.inputsummary, 2, mean)

in.melt <- melt(inputActivation[,c(paste("Mean", 1:20, sep="_"), "time", "s")], id.vars=c("time", "s"))
# ggplot(in.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line()

#graph of inputs for first 20 ROIs (T2* units)
png(paste0("~/Possum_Motion/output/possum_rest_", run, "_inputs_t2s.png"), width=11, height=6, units="in", res=150)
ggplot(in.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line() +
  xlab("Time (s)") + ylab("Activation input (delta T2*)") + ggtitle("POSSUM Resting State mean activation input within 20 ROIs")
dev.off()

#obtain estimated t2* for each timepoint for select ROIs
act_x_time.t2ms <- as.matrix(inputActivation[,c(paste("Mean", roisToCompare, sep="_"))]) * 1000 + t2s_static #add t2*static and bring back to ms

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
act_x_time.psc$time <- inputActivation$time #add time
act_x_time.psc$s <- factor("Input")

#plot PSC estimates for 4d input
# in.melt <- melt(subset(act_x_time.psc, select=-s), id.vars=c("time"))
# ggplot(in.melt, aes(x=time, y=value)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line()

#Scale output to percent signal change:
#Because we don't have a true baseline, the best option is not some sort of voxel mean scaling, but instead to use
#the third simulated volume as the static tissue value since this is relatively steady state and will represent
#the WM + GM + CSF contributions to signal intensity.

activation.psc <- data.frame(sapply(roisToCompare, function(x) {
  ( outputActivation[,paste("Mean", x, sep="_")]/baseline[x] - 1 ) * 100
}))

names(activation.psc) <- names(outputActivation)[roisToCompare]
activation.psc$time <- outputActivation$time
activation.psc$s <- factor("Output")

all.psc <- rbind(activation.psc, act_x_time.psc)

act.melt <- melt(all.psc, id.vars=c("time", "s"))

#such a scaling difference, that overlaying with color obscures in vs out
# ggplot(act.melt, aes(x=time, y=value, colour=s)) + facet_wrap(~variable, scales="free_y") + geom_point() + geom_line() +

png(paste0("~/Possum_Motion/output/possum_rest_", run, "_in_vs_out_psc.png"), width=16, height=11, units="in", res=150)
ggplot(act.melt, aes(x=time, y=value)) + facet_wrap(~s*variable, scales="free_y") + geom_point() + geom_line() +
  xlab("Time (s)") + ylab("Percent Signal Change") + ggtitle(paste0("POSSUM resting-state using ", run, " activation: input versus output"))
dev.off()



#Detritus

#only applied to old sims where activation started earlier
#looks like the first two time points have bigger T2* values...
#so need to dicard volumes 1-5 corresponding to second 0-8, begin activation at 6th TR (10 s)
# outputActivation[1:2, paste("Mean", 1:264, sep="_")] <- NA

# inputActivation <- read.table("input_roiAvg_bandpass_bb264_meanTimeCourses.1D", header=TRUE)[,-1]
# inputActivation <- read.table("input_roiAvg_fullFreq_x10_bb264_meanTimeCourses.1D", header=TRUE)[,-1]
