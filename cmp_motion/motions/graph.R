library(reshape2)
library(ggplot2)
oned <-grep('1D',list.files(),value=T)
mot <- oned[-grep('3dvolreg',oned)]
d<-data.frame(); 
for(m in mot){ 
 name <- sub('.1D','',m);
 d <- rbind(d,
	    cbind(
		  read.table(m,header=F,col.names=c("t","t.x", "t.y", "t.z", "r.x", "r.y", "r.z")),
		  name 
		  )
	    )
}
m<-melt(d,id.vars=c('t','name'))

# max from max(d$t[as.character(d$name)=='psm.mo'])
p<- ggplot(m,aes(x=t,y=value,color=name,group=name))+
        geom_line()+
	facet_grid(variable~.,scale='free_y')+
	scale_x_continuous(limits=c(0,38*2))+
	scale_color_brewer(palette='Set2')
ggsave(file='inVmoVnomo.pdf',p)
