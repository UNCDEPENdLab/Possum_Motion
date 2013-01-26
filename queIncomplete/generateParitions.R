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
startNum  <- 16  # min num of processors to use
maxTimehr <- 100 # largest job blacklight will do

args <- commandArgs(TRUE)
inputfilename <- args[1]
outputfilename <- args[2]
ncpusTouse    <- args[3]
# change this file to read in others
if(is.null(inputfilename) ){
  cat ("# ls 1 * | egrep -v 0001 | possumLogtime.pl > possumTimes.txt\n")
  message("What file has the perl parsed log times? ")
  inputfilename <- readLines("stdin",n=1)
}

times.all   <- read.table(inputfilename,header=T)
times.unfin <- times.all[times.all$remainingsec!=0,]
times       <- times.unfin[times.unfin$expectedsec/60**2<maxTimehr,]
if(dim(times)[1]!=dim(times.unfin)[1]) {
 cat("DROPPED jobs are expted to take over 100 hours\n")
 print(times.unfin[times.unfin$expectedsec/60**2>=110,c('sim_cfg','poss_logfile','expectedsec')] )
}

remain      <- apply(cbind(times$expectedsec,times$knownExample)/60**2,1,max,na.rm=T)
remain[remain==-Inf] <- 40 #mean(times$expectedsec[times$expectedsec>1*60^2],na.rm=T)/60**2
# sort(remain,index.return=T)


n         <- length(remain)
totalTime <- sum(remain)
maxTime   <- max(remain)


allbins <- vector("list",n)
for ( i in seq(startNum,n,by=16) ) {
  desiredSum <- totalTime/i
  if(desiredSum < maxTime -10 ){
    cat("desired sum:", desiredSum, "too small!", " have  ", maxTime," hr job -- output will be funny\n" )
    #break
  }
  allbins[[i]] <- magicPartition(remain, i)
}

# hours that are expected to be lost for each grouping
# vs total length to complete
lost <- unlist(lapply(allbins, '[', 'totallost'))
runtime <- unlist(lapply(allbins, '[', 'runtime'))

df<-data.frame(numProc=seq(startNum,n,by=16)[1:length(runtime)],runtime=runtime,lost=lost )
#if(is.null(ncpusTouse )) {
  #todo, try catch on x11
  #x11()
  #library(ggplot2)
  #p<- ggplot(data=df,aes(x=runtime,y=lost,label=numProc))+
  #     geom_text()+theme_bw()+
  #     ggtitle("run time vs lost time (hours)") 
  #     #scale_y_continuous(limits=c(0,200))
  #print(p)
  
  # best  -- likely always to be grouping by 2 processors
  best <- unname(which.min(lost))
  #cat('numproc: ',  best + 1, "\n" )
  print(df)
  cat("\n\n\n\n\n")
  #cat(best+startNum, "losses the least\n")
  message("how many processors givs optimal totalTimeVsCharge? ")
  best <- as.numeric(readLines("stdin",n=1)) 
#} else {
# best <- ncpusTouse
# cat('using', best,"\n")
#}

# which possum nums do groups correspond to?
#substring( as.character(  times$poss_logfile[ allbins[[best]]$binidx[[1]]  ] ),  11)

timetocomplete <- unlist(lapply(allbins[[best]]$binidx, function(x) { sum(times$expectedsec[x])/60**2 } ))
totaltime <- max(timetocomplete)
filename <- paste(outputfilename, "finish-with-",best,"-PBS.bash",sep="")
sink(file=filename)
cat(paste("#PBS -l ncpus=",best,sep=""),"\n" )
cat(paste("#PBS -l walltime=",round(totaltime)+3,":00:00",sep=""),"\n" )
cat("#PBS -q batch\n" )
cat("#PBS -j oe\n")
cat("#PBS -M hallquistmn@upmc.edu\n")

#cat("simName=__simName__\n") # if all had the same configuration. They dont
cat("source $(cd $(basename $0);pwd)/possumRun.bash\n" )
cat( 
  paste( '(',  
            lapply(allbins[[best]]$binidx, function(x) { 
               paste( 
                 paste('possumRun', 
                     substring( as.character(times$poss_logfile[x]),11),
                     as.character(times$sim_cfg[x]), 
                     times$expectedsec[x]/60**2, 
                     sep=" "), 
                     collapse=";\n\t ")
               }   
             ), 
          ')', collapse="&\n" ), 
   "\n")
cat( paste( '#', timetocomplete, 'hours', collapse="\n"), "\n")
cat(paste("#",round(lost[[best/16]]),"hours lost to idle"),"\n" )
cat('wait\n')
cat('ja -chlst\n')
sink()

cat("wrote to ", filename,"\n")
