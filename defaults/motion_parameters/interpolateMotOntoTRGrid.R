#!/usr/bin/Rscript
require(tools,quietly=TRUE)
require(plyr,quietly=TRUE)
require(reshape2, quietly=TRUE)

args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2L) stop("usage: interpolateMotOntoTRGrid.R motFile outTR t1Zero offset colnames")
#default that we should start motion file at all zeros
if (length(args) < 3L) { t1Zero <- TRUE } else { t1Zero <- as.logical(args[3L]) }
if (length(args) < 4L) { offset <- 0 } else { offset <- as.numeric(args[4L]) }
if (length(args) < 5L) { cnames <- c("time", "t.x", "t.y", "t.z", "r.x", "r.y", "r.z")
                     } else {
                         cnames <- strsplit(args[4L], "\\s*,\\s*", perl=TRUE)[[1L]]
                     }

motFile <- args[1L]
stopifnot(file.exists(motFile))

orig <- read.table(motFile, header=FALSE)
names(orig) <- cnames

PossumTR <- as.numeric(args[2L])
newTimeGrid <- seq(from=0, to=floor(max(orig[,1])), by=PossumTR)

interpolated <- data.frame(cbind(newTimeGrid, do.call(cbind, (lapply(orig[,-1], function(col) {
                        return(approx(x=orig[,1], y=col, xout=newTimeGrid)$y)
                      })))
                      ))

names(interpolated) <- cnames

allMot <- rbind(cbind(interpolated, type="interpolated"), cbind(orig, type="orig"))
allMelt <- melt(allMot, id.vars=c("time", "type"))
require(ggplot2, quietly=TRUE)

png(paste0(file_path_sans_ext(motFile), "_interp.png"), width=1200, height=800, res=150)
g <- ggplot(allMelt, aes(x=time, y=value, color=type)) + facet_grid(variable~., scales="free_y") + theme_bw(base_size=12) + geom_line()
print(g)
#plot(orig[,1], orig[,2], type="l", col="blue")
#lines(interpolated[,1], interpolated[,2], type="l", col="red")
dev.off()

## to avoid weird initial head position, usually fix head position to 0 at t=0 and t=FirstMotion
if (t1Zero) {
    interpolated <- colwise(function(col) {
        ## shift vector to have value=0 for row 1
        col <- col + -1*col[1L]
        return(col)
    })(interpolated)
}

if (offset > 0) {   
    interpolated <- cbind(time=(offset + PossumTR*0:(nrow(interpolated)-1)), subset(interpolated, select=-time))
    interpolated <- rbind(rep(0, 7), interpolated) #add zero position to first row at t=0
}

write.table(interpolated, file=paste0(file_path_sans_ext(motFile), "_", as.character(PossumTR), "s_interp"), row.names=FALSE, col.names=FALSE)
