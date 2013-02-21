activT <- read.table("activt_150")
#from here: http://r.789695.n4.nabble.com/Interleaving-elements-of-two-vectors-td795123.html

interleave <- function(a, b) { 
  mlab <- min(length(a), length(b)) 
  seqmlab <- seq(length=mlab) 
  c(rbind(a[seqmlab], b[seqmlab]), a[-seqmlab], b[-seqmlab]) 
} 

#want a vector of this form
#16
#17.9
#18
#19.9

#such that two volumes in the activation 4d have exactly the same values, so that activation is "held"
#at some level for 1.9s of the 2s TR.

newAct <- data.frame(newact=interleave(activT$V1, activT$V1 + 1.9))
write.table(newAct, file="activ_150_hold1p9", row.names=FALSE, col.names=FALSE)
