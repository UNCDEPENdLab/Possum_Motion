#!/usr/bin/env Rscript

convertDfileToPossum <- function(dfile, trlen, outfilename) {
   require(plyr)

   # 3dvolreg output is peculiar: rotation first, then translation: z, x, y.
   dfile <- read.table(dfile, header=FALSE, col.names=c("r.z", "r.x", "r.y", "t.z", "t.x", "t.y")) 

   dfile <- adply(dfile, 1, function(row) {
      row$r.x <- row$r.x * (pi/180) #deg to rad
      row$r.y <- row$r.y * (pi/180)
      row$r.z <- row$r.z * (pi/180)
      row$t.x <- row$t.x / 1000 #mm to m
      row$t.y <- row$t.y / 1000
      row$t.z <- row$t.z / 1000
      return(row[c("t.x", "t.y", "t.z", "r.x", "r.y", "r.z")])
   })


   dfile <- cbind(time=trlen*0:(nrow(dfile)-1), dfile)


   write.table(dfile, file=outfilename, row.names=FALSE, col.names=FALSE)
}

# example call
# convertDfileToPossum("10776.dfile_WashU.1D", 1.5, "testPossumMotion")

args<-commandArgs(TRUE)
convertDfileToPossum(args[1], 1.5, args[2])

