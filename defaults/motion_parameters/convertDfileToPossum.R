#!/usr/bin/env Rscript

convertDfileToPossum <- function(dfile, outfilename, TR, offset=0, t1Zero=TRUE, fmt="afni", trunc=0) {
  suppressMessages(require(plyr))
  cat("\nInputs:\n   motfile:" , dfile, "\n   outfile:", outfilename, "\n   TR:", TR, "\n   offset:", offset, "\n")

  if (fmt=="afni") {      
      ## 3dvolreg output is peculiar: rotation first, then translation: z, x, y.
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
  } else {
      #file is rx ry rz (radians) tx ty tz (mm): applies to mcflirt and sliceMotion4d
      dfile <- read.table(dfile, header=FALSE, col.names=c("r.x", "r.y", "r.z", "t.x", "t.y", "t.z")) 

      dfile <- adply(dfile, 1, function(row) {
          row$t.x <- row$t.x / 1000 #mm to m
          row$t.y <- row$t.y / 1000
          row$t.z <- row$t.z / 1000
          return(row[c("t.x", "t.y", "t.z", "r.x", "r.y", "r.z")])
      })      
  }

  #allow for truncation
  if (trunc > 0) {
      dfile <- dfile[1:trunc,]
  }
  
  # to avoid weird initial head position, usually fix head position to 0 at t=0 and t=FirstMotion
  if (t1Zero) {
    dfile <- colwise(function(col) {
      #shift vector to have value=0 for row 1
      col <- col + -1*col[1L]
      return(col)
    })(dfile)
  }

  dfile <- cbind(time=(offset + TR*0:(nrow(dfile)-1)), dfile)

  if (offset > 0) {
    dfile <- rbind(rep(0, 7), dfile) #add zero position to first row at t=0
  }           	   
  
  write.table(dfile, file=outfilename, row.names=FALSE, col.names=FALSE)
}

# example call
# convertDfileToPossum("10776.dfile_WashU.1D", "testPossumMotion", 1.5, 16)

args<-commandArgs(TRUE)

if (length(args) < 2L) stop("convertDfileToPossum requires arguments <dfile> <outfileName> <TR> <offset> <fmt=afni,4dst,mcflirt>")
if (length(args) > 2L) {
  TR <- as.numeric(args[3L])
} else {
  TR <- 1.5
}

if (length(args) > 3L) {
  offset <- as.numeric(args[4L])
} else {
  offset <- 0
}

if (length(args) > 4L) {
  fmt <- args[5L]
} else {
  fmt <- "afni"
}

if (length(args) > 5L) {
  trunc <- as.numeric(args[6L])
} else {
  trunc <- 0
}


cat("calling func with args: \n1>", args[1], "\n2>", args[2], "\n3>", TR, "\n4>", offset, "\n5>", fmt, "\n")
convertDfileToPossum(dfile=args[1], outfilename=args[2], TR=TR, offset=offset, fmt=fmt, trunc=trunc)
