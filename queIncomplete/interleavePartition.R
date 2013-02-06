magicPartition <- function(set,i, binTotal) {
   print(c(n,binTotal))
   sorted <- sort(set,index.return=T)


   # order to build sets
   # alternate indexes: eg. for n=23
   # 23 1 22 2 ... 13 11 12
   n <- length(set)
   takeorder <- rep(0,n)
   takeorder[1:n%%2==1] <- n:ceiling(n/2)
   takeorder[1:n%%2==0] <- 1:floor(n/2)


   bins <- vector("list",i) # we'd like i bins (binTotal*i==totalTime)
   bins.idx<-bins
   binNum <- 1
   while(length(takeorder)>0) {

     newBin <- c(bins[[binNum]],sorted$x[takeorder[1]])

     if(sum(newBin) < binTotal +10 ){
       bins[[binNum]] <- newBin
       bins.idx[[binNum]] <- c(bins.idx[[binNum]],sorted$ix[takeorder[1]])
       cat(binNum,": +",takeorder[1],"->", sorted$x[takeorder[1]], "=", sum(bins[[binNum]]), "\n")
       takeorder<-takeorder[-1]

     }  else {


       binNum<-binNum+1
       cat(sum(newBin), ">", binTotal+10, "skipping to", binNum, "\n")

       if(binNum > i ) {
          binNum <- which.min( lapply(bins,sum) )
          binTotal <- sum(c(bins[[binNum]], sorted$x[takeorder[1]] ))
        }
     }
   }

   # TODO ###
   # if the difference between the max and smallest is > time of job in max
   # move that job to smallest


   sums<- unlist(lapply(bins,sum))
   totalLost <- sum(sums[which.max(sums)] - sums)
   cat("total lost hours: ", totalLost,"\n")

   obj<- list(bins=bins,binidx=bins.idx,totallost=totalLost,partitions=i,idealTotal=binTotal)
}

