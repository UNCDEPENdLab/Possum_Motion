
orig <- read.table("10761_motion_fdM_50pct_90sec46vol", header=FALSE)
PossumTR <- 2.0
newTimeGrid <- seq(from=0, to=floor(max(orig[,1])), by=PossumTR)

interpolated <- cbind(newTimeGrid, do.call(cbind, (lapply(orig[,-1], function(col) {
                        return(approx(x=orig[,1], y=col, xout=newTimeGrid)$y)
                      })))
                      )

plot(orig[,1], orig[,2], type="l", col="blue")
lines(interpolated[,1], interpolated[,2], type="l", col="red")

write.table(interpolated, file="10761_motion_fdM_50pct_90sec46vol_2TRInterp", row.names=FALSE, col.names=FALSE)
