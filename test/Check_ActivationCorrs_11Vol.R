
library(fmri)
library(oro.nifti)
library(plyr)
#origActiv15_scale1_gm244 <- "original/Input/origactiv_first15.nii.gz" 
#possumSim10_scale1_gm244 <- "original/Input/nbswkmt_Brain_act1.5_15_zero_1.5_15_abs_trunc5_6_scale1_1mm_244GMMask.nii.gz"
#spheres_int              <- "original/Input/10653_bb244_gmMask_fast.nii.gz"
origActiv15_scale1_gm244 <- "inputs/act1.5_15.nii.gz"
possumSim10_scale1_gm244 <- "preproc/simBrain_preproced.nii.gz"
spheres_int              <- "fromSubj/10653_bb244_gmMask_fast.nii.gz"

# only load nifitis if it hasn't been done before
if( ! length(grep("origActiv15Mat",ls() )) ) {
   origActiv15Mat <- readNIfTI(origActiv15_scale1_gm244)@.Data
   possumSim10Mat <- readNIfTI(possumSim10_scale1_gm244)@.Data
   spheresMat     <- readNIfTI(spheres_int)@.Data
}

#obtain indices of non-zero voxels in first volume (will be the same for all other vols) 
origActivPresent <- which(origActiv15Mat[,,,1] != 0.0, arr.ind=TRUE)
simActivPresent  <- which(possumSim10Mat[,,,1] != 0.0, arr.ind=TRUE)

# num vols in 4th dim (time)
origVols <- dim(origActiv15Mat)[4]
simVols  <- dim(possumSim10Mat)[4]

#note that the orig is in 1.5s and contains 15 volumes (22.5 s)
#the sim is in 2.05s and contains 10 vols (20.5s)

#sanity check: read in masked files -- 244 regiosn should be the same
identical(origActivPresent, simActivPresent)

targetSampFreq <- 1/1.0 #TR=1.0s
origTR         <- 1.5
origFreq       <- 1/origTR
simTR          <- 2.05
simFreq        <- 1/simTR

numsecs <- 19

resampTime <- seq(0, (numsecs-1) *targetSampFreq, by=targetSampFreq) #0 ... 18    by 1
origTime   <- seq(0, (origVols-1)*origTR,         by=origTR)         #0 ... 21    by 1.5
simTime    <- seq(0, (simVols-1) *simTR,          by=simTR)          #0 ... 18.45 by 2.05

# initialize array {orig,sim} by 80342 by 19
resampVoxMat <- array(NA, dim=c(2, nrow(origActivPresent), length(resampTime)),               # 2x__x__
                          dimnames=list(orig_sim=c("orig", "sim"), vox=NULL, time=resampTime)
                     )

# per voxel simple linear interpolation here
# for each voxel (row) of activation in mask (Present)
# using known x:y pair time:activation
# to approx values at resampTime
for (i in 1:nrow(origActivPresent)) {
  resampVoxMat["orig",i,] <- approx(origTime, 
                                    origActiv15Mat[cbind(pracma::repmat(origActivPresent[i,], origVols, 1), 1:origVols)], 
                                    # i.e. origActiv15Mat[origActivPresent[i,1],origActivPresent[i,2],origActivPresent[i,3],1:15],
                                    # e.g. i=1, origA..=80,53,40 => origActiv15Mat[80,53,40,]
                                    # instead rep  origActive for as many vols and column bind the vols to index matrix
                                    # making 80,53,40,1; 90,53,40,2; ....
                                    xout=resampTime)$y
  resampVoxMat["sim", i,] <- approx(simTime, 
                                    possumSim10Mat[cbind(pracma::repmat(simActivPresent[i,], simVols, 1), 1:simVols)], 
                                    xout=resampTime)$y
}

#and if that works, correlate each voxel time series between the original and sim.
voxCorr <- aaply(resampVoxMat, 2, function(suba) {
      cor(suba[1,], suba[2,])
    })

mean(voxCorr, na.rm=TRUE) #looks promising! :P

# initialize array for all rois
rois <- array(NA,264);
# try per-roi correlation 
#for (n in sort(unique((as.vector(spheresMat))))) { # all rois in spheresMat
pdf('cor.pdf',width=8.5,height=11)
for (n in 1:264) {
   # find indexes of active region matching this roi
   roi  <- which(spheresMat[simActivPresent] == n)
   
   # skip if there are none
   if( length(roi) < 1 ) next

   # take the mean across voxels of roi
   omean <- apply(resampVoxMat["orig",roi, ] , 2 , FUN=mean )
   smean <- apply(resampVoxMat["sim", roi, ] , 2 , FUN=mean )

   plot( resampTime, omean, type="l",col="blue")
   lines(resampTime, smean, type="l",col="red")
   
   rois[n]<- cor( omean, smean  ) 

   legend("bottomright", c("orig","sim"),lty=c(1,1),col=c("blue","red"))
   title(paste(n,": ",rois[n]))
}
dev.off()
mean(abs(rois), na.rm=TRUE)
min(abs(rois), na.rm=TRUE)
max(abs(rois), na.rm=TRUE)

sort(abs(rois))
