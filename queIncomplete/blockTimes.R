######
# use most completed possum run to guess the time to complete
#  write out to a new file
#
### ASSUMES SAME NUMBER OF BLOCKS FOR EACH COMPARED RUN ###
#####


library(ggplot2)
library(reshape2)

args <- commandArgs(TRUE)
inputfilename <- args[1]
outputfilename <- args[2]

a<-read.table(header=T, file=inputfilename)

a$voxT0 <-  as.character(a$voxT0)
a$voxT1 <-  as.character(a$voxT1)
a$voxT2 <-  as.character(a$voxT2)
a$voxT0[grep('\\?',a$voxT0)] <- NA
a$voxT1[grep('\\?',a$voxT1)] <- NA
a$voxT2[grep('\\?',a$voxT2)] <- NA
a$voxT0 <-  as.numeric(a$voxT0)
a$voxT1 <-  as.numeric(a$voxT1)
a$voxT2 <-  as.numeric(a$voxT2)

a$voxsum<-rowSums(a[,paste('voxT',c(0,1,2),sep="")])

a$poss_logfile <- as.numeric(substring(levels(a$poss_logfile),11))

### Voxels (unused)
voxels <-subset(a,subset=remainingsec==0,select=c('sim_cfg','poss_logfile','voxsum')) 
names(voxels)[2] <- 'block'
wide<-reshape(voxels,direction='wide', timevar='sim_cfg', idvar='block')
long<-melt(wide,id.vars='block')
voxplot <- ggplot(long,aes(x=block,y=value,group=variable,color=variable))+geom_line()

voxcount <- data.frame(avg = rowMeans(wide[,-1],na.rm=T), block = wide$block )


#levels(a$sim_cfg) <- c('bp','ff','avgbp','avgff')
times <-subset(a,subset=remainingsec==0,select=c('sim_cfg','poss_logfile','expectedsec')) 

a<-a[,-which('voxsum' == names(a))]

## find all finished/known times

names(times)[2] <- 'block'
names(times)[3] <- 't'
times$t <- times$t/60**2
wide<-reshape(times,direction='wide', timevar='sim_cfg', idvar='block')
long<-melt(wide,id.vars='block')
timeplot <- ggplot(long,aes(x=block,y=value,group=variable,color=variable))+geom_line()

#
# create data frame 'd' rows=>blocks, columns=>run  
# find the most complete column/run
# determine scaling factor for most complete to every other run
#
d<-dcast(long,...~variable)
# find the least NA possum run config
bestidx <- which.min(apply(d[,-1],2,function(x){length(which(is.na(x)))} ) ) + 1
guess <- d
#useidx <- d$t.avgbp>10
for(n in grep('t', names(d), value=T)) {
 expectedDiff <- mean(d[ ,n ]/d[,bestidx], na.rm=T) 
 guess[,n] <- expectedDiff * d[,bestidx] * 60**2
}

knownExample <- reshape(guess,direction='long',varying=names(guess)[-1])[,c('block','time','t')]
names(knownExample) <- c('poss_logfile','sim_cfg','knownExample')

a<-a[,-which('knownExample' == names(a))]

newA <- merge(a,knownExample,by=c('sim_cfg','poss_logfile'),sort=F,all.x=T)


newA$poss_logfile <- sprintf('possumlog_%04d', a$poss_logfile)
write.table(sep="\t",newA, file=outputfilename, quote=F,row.names=F)




