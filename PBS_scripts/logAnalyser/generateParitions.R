# Want to build a qsub command that minimizes time lost to idle processors:
#  we request n processors for a batch we are charged for n*(time of longest job).
#
# 
# For any number of processors used, we want to max each's usage
# time/proc =  sum(time of ea possum job)/(# procs to use)
#
# we can try to get the jobs to align to this time for each number of processors
# and way total time of the run to the lost time
#
# EXAMPLE
#  3 PROCESSORS
#
#    #PBS =l walltime=00:90:00
#    #PBS -l ncpus=3
#    (job1; jobs2) &               #  15+20+50       # 85h
#    (job3; job4; job 5) &         #  15+20+50       # 85h
#    job 6; job 7; job 8; job 9;   #  20+25+25       # 70h
#
#  takes 85h to complete
#  charged 85*3 hours even though processor 3 is free at hour 70.  == 15 hours overcharged
#
# 2 PROCESSORS
#
#        50+50+20            # 120
#        25+25+20+20+15+15   # 120
#
#  takes 120 hours to complete
#  no time lost
#

##########################################################################

# load magicPartition function
# --- will use fill with biggests first naive algorithm 2/3 optimal :-/
source('biggestFillPartition.R')

# change this file to read in others
cat ("# ls 1 * | egrep -v 0001 | possumLogtime.pl > possumTimes.txt\n")
cat ("What file has the perl parsed log times? ")
inputfilename <- readline()
times.all <- read.table(inputfilename,header=T)
times     <- times.all[times.all$remainingsec>0,]
remain    <- times$expectedsec/60**2
# sort(remain,index.return=T)


n         <- length(remain)
totalTime <- sum(remain)
maxTime   <- max(remain)

allbins <- vector("list",n-2)
for ( i in 2:(n-2) ) {
  desiredSum <- totalTime/i
  if(desiredSum < maxTime -10 ){
    cat("desired sum:", desiredSum, "too small!", " max is ", maxTime,"\n" )
    break
  }

  allbins[[i-1]] <- magicPartition(remain, i)
}

# hours that are expected to be lost for each grouping
# vs total length to complete
lost <- unlist(lapply(allbins, '[', 'totallost'))
runtime <- unlist(lapply(allbins, '[', 'runtime'))

library(ggplot2)
df<-data.frame(run=runtime,lost=lost,numProc=seq(2,n)[1:length(runtime)]  )
p<- ggplot(data=df,aes(x=run,y=lost,label=numProc))+
     geom_text()+theme_bw()+
     ggtitle("run time vs lost time (hours)") +
     scale_y_continuous(limits=c(0,200))
print(p)

# best  -- likely always to be grouping by 2 processors
best <- unname(which.min(lost))
#cat('numproc: ',  best + 1, "\n" )

cat("\n\n\n\n\n")
cat(best+1, "losses the least\nbut how many processors is optimal totalTimeVsCharge? ")
best <- as.numeric(readline()) - 1


# which possum nums do groups correspond to?
#substring( as.character(  times$poss_logfile[ allbins[[best]]$binidx[[1]]  ] ),  11)

timetocomplete <- unlist(lapply(allbins[[best]]$binidx, function(x) { sum(times$expectedsec[x])/60**2 } ))
totaltime <- max(timetocomplete)
filename <- paste("finish-possum-with-",best+1,"-PBS.bash",sep="")
sink(file=filename)
cat(paste("#PBS -l ncpus=",best+1,sep=""),"\n" )
cat(paste("#PBS -l walltime=",round(totaltime)+3,":00:00",sep=""),"\n" )
cat("#PBS -q batch\n" )
cat("source possumRun.bash\n" )
cat( 
  paste( '(',  
            lapply(allbins[[best]]$binidx, function(x) { 
               paste( 
                 paste('possumRun', 
                     substring( as.character(times$poss_logfile[x]),11), sep=" "), 
                     collapse="; ")
               }   
             ), 
          ')', collapse="&\n" ), 
   "\n")
cat( paste( '#', timetocomplete, 'hours', collapse="\n"), "\n")
cat(paste("#",round(lost[[best]]),"hours lost to idle"),"\n" )
sink()

cat("wrote to ", filename,"\n")
