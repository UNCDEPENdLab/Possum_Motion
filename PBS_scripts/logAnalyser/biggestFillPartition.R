####
# DESCRIPTION
#  have up to n processors to use on n jobs of varing time
#  while  any subset of jobs can be run on any subset of processors
#  e.g all processes on 1 processor, all jobs on their own processor, 2 jobs on 1 proc, rest on another, ...
#  we should use as many processors as possibile, and will cause problems if we use 1 job/proc
#
#  time charged will be the longest concatation of jobs on any processor X the number of processors requested
#
#  The goal is to minimize time charged to account
#
# OBJECTIVE:
#  given a set of times, try to find "i" paritions/fill "i" bins such that
#  each partition's sum is the same ( sum(set)/i )
#
# "
#   BPP-2: Minimize the capacity c for a given number m of bins. 
#   BPP-2 is equivalent to the problem of scheduling n independent jobs 
#   having operation times wj on m identical parallel processors 
#   with the objective of minimizing the makespan c 
# "
# ** http://www.wiwi.uni-jena.de/Entscheidung/binpp/ **
#    http://www.sciencedirect.com/science/article/pii/S0305054896000822
#
#  http://www.or.deis.unibo.it/kp/Chapter8.pdf ** section 8.5 MTP
#
#  http://en.wikipedia.org/wiki/Bin_packing_problem
#
#  http://en.wikipedia.org/wiki/Partition_problem
#
#
#
#  NAIVE APPROACH: First Fit Decreasing. worset case 11/9x optimal solution (?)
#
#   assign a desired number of processors to use (partitions/bins)
#   start each bin (processor) with the largets time job avaliable
#    add the next largest(s) that will fit in the time given by sum/(# paritions)
#    until bins are filled
#    then find the smallest bin and add the largets remaining job
#    until all jobs are in a bin
#
# returns "obj:"  a list of bins, indexes, and total lost time, total time for longest processor
#
###

magicPartition <- function(set,i) {
   # we want to equally distribute the use of each processor
   # so the bins should be equal and sum to the total
   #  for i bins, each bin should fit as close as possible to sum/i
   binTotal  <- sum(set)/i
   print(c(n,binTotal))

   # sort so we know when we find the first that fits in a bin
   # it is the biggest that will fit
   sorted <- sort(decreasing=T,set,index.return=T)


   n <- length(set)
   takeorder <- 1:n

   bins <- vector("list",i) # we'd like i bins (binTotal*i==totalTime)
   bins.idx<-bins
   binNum <- 1
   while(length(takeorder)>0) {

     currentTotal <- sum(bins[[binNum]])
     canBeAdded   <- which( (sorted$x[takeorder]+currentTotal) <= binTotal)
     if(length(canBeAdded)>0) {
        # take is the biggest that will fit
        take<-takeorder[canBeAdded[1]]
        takeorder <- takeorder[-canBeAdded[1]]
        newBin <- c(bins[[binNum]],sorted$x[take])
        bins[[binNum]] <- newBin
        bins.idx[[binNum]] <- c(bins.idx[[binNum]],sorted$ix[take])
        cat(binNum,": +",take,"->", sorted$x[take], "=", sum(bins[[binNum]]), "\n")
     }  else {
       print(sorted$x[takeorder]+currentTotal)
       print(binTotal)

       binNum<-binNum+1
       cat("skipping to", binNum, "\n")

       if(binNum > i ) {
          binNum <- which.min( lapply(bins,sum) )
          binTotal <- ceiling( sum(   c( bins[[binNum]], max(sorted$x[takeorder]) )    )  )
          cat('bin total increased to ', binTotal, "\n")
        }
     }
   }

   # TODO ###
   # if the difference between the max and smallest is > time of job in max
   # move that job to smallest


   sums<- unlist(lapply(bins,sum))
   totalLost <- sum(sums[which.max(sums)] - sums)
   cat("total lost hours: ", totalLost,"\n")

   obj<- list(bins=bins,binidx=bins.idx,
              runtime=max(sums), totallost=totalLost,
              partitions=i,idealTotal=binTotal)
}
