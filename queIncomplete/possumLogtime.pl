#!/usr/bin/perl

# create a table of tissue voxels and runtime
#  first voxel number ? in a field is an estimate based on seen voxels of that tissue type within log file
#  second and third ? are averages of seen and estimated (b/c that tissue type is never in the log)
#
# OUTPUT SNIP
#           poss_logfile     vox/s voxT0 voxT1 voxT2 expectedsec remainingsec
#   sim_cfg possumlog_0151   0.203 6804  2616  3903  65681        0
#   sim_cfg possumlog_0152   0.082 8147? 8147? 8147? 298636.6     219850.6
#                                ^      ^     ^      ^
#          partly seen, rest est-|      |     |      |
#          never seen, totally made up--|-----|      |
#          based on only a few zz steps that were avaliable in in tisue type 0
#
# NOTE: error in vox per second calcuation
#
# USAGE EXAMPLE
#  \ls -1 *|grep -v 0001 | possumLogtime.pl  > possumTimes.txt
#
# currently uses first log file mod time as creation time of every file
#

## TODO:
#  * make hash of finished times for when lifeSecs is 0 (hasn't started)
#  * make hash of qsub so currently processed jobs dont get added?

use strict; use warnings;
# easily find stat info by name
use File::stat;
#use Time::localtime; # ctime() writes time as date
#use Data::Dumper;

# to find first log file
use File::Basename;      
use File::Glob ':glob';

# undefined until needed
my $log1mtime;

die "need first argument to be sim_cfg" if $#ARGV<0;

my $sim_cfg = $ARGV[0];


print join("\t",qw(sim_cfg poss_logfile vox/s voxT0 voxT1 voxT2 expectedsec remainingsec knownExample)),"\n";
 
#input should be log file names
while(<>) {
 
 next if !$_ ;
 chomp;
 my $logfile=$_;
 #print "$_ not a log file! (.log\$)" && next if ! m/.log$/;
 if(! -e $logfile) {
  print STDERR "$logfile DNE\n";
  next;
  }
 #print "looking at $_\n";
 my $ctime = stat($logfile)->ctime();
 my $mtime = stat($logfile)->mtime();

 my $lifeSecs=$mtime-$ctime;
 if($lifeSecs <= 0 ) { 
  #print "WARN: ctime stamp on $_ is definetly not creation time (mtime-ctime=$lifeSecs s)\n";

  # get the mod time of the first log file if we haven't already
  if(! $log1mtime) {
   my $dirname =dirname($logfile);
   my @log1 =  bsd_glob("$dirname/*_00*1*");
   die "cannot find initial log file!" if ! -e $#log1<0;
   #print "mtime for '$log1[0]' ";
   $log1mtime = stat($log1[0])->mtime();
   #print "$log1mtime\n";
  }
  # use log1 mod time as a close guess

  $lifeSecs = $mtime - $log1mtime;

  # is it still negative!?
  print STDERR "WARN: first log is too young ($log1mtime) looking at $_ ($mtime)\n this wont be useful!\n" && next if $lifeSecs<=0;
  # next
 }


 # get voxel count
 my $tissueTypesSeen=0;
 my $voxelsSeen=0;
 my $lastVoxel=0;
 my $zz=0;
 my $finished;
 my $zend;
 my @voxPerTissue;

 # slow way to go through the file
 # could readBackwards, but need module from cpan
 open my $logfileFH, $logfile or die "cannot open log file $_";
 while(<$logfileFH>) {
   $zend            = $1 if !$zend && m/zend=(\d+);/;
   $lastVoxel       = $1 if m/Voxelnumber=(\d+)/;

   # update zz (and voxs per tissue if new tissuetype)
   if(m/zz=(\d+);/){
     push @voxPerTissue, $lastVoxel if ($1 < $zz); # new tissue type
     $zz = $1;
   }

   $tissueTypesSeen = $1 if m/Tissue type=(\d)/ and $1 > $tissueTypesSeen;
   if( /Possum finished generating the signal for (\d+) voxels/){
      $lastVoxel = $1;
      $finished  = 1;
      push @voxPerTissue, $lastVoxel;
   }
   $voxelsSeen=$lastVoxel if $lastVoxel > $voxelsSeen;

 }


 # to get num voxels for just that tissue type
 # subtract previous from current 
 for my $i (reverse(0..$#voxPerTissue)) {
  next if $i<=0;
  $voxPerTissue[$i]-=$voxPerTissue[$i-1]
 }

 my $voxPerSec = 0;
 $voxPerSec = $voxelsSeen/$lifeSecs if $lifeSecs>0;
 #print "\n\nhave seen ${voxelsSeen}vox (@voxPerTissue) in ${lifeSecs}s, rate=$voxPerSec\n";
 print join("\t", $sim_cfg, basename($logfile), sprintf("%.3f",$voxPerSec) , @voxPerTissue);

 if( ! $finished) {
    my $remainingTissues=3-$tissueTypesSeen;
    my $remainingZ       = $zend - ($zz+1); # zz zero based, zend not? 
    
    # get expected voxels for this tissueType
    my $sumPrevTissue = 0;
    $sumPrevTissue += $_ for @voxPerTissue;

    # get voxels on just this tissue type, find about how many per step, multiply by total steps
    my $expectVoxelNum = ( ($voxelsSeen-$sumPrevTissue)/($zz+1) ) * $zend; 


    my $avgVox=sprintf("%.0f",($sumPrevTissue + $expectVoxelNum)/( 1+ ($#voxPerTissue +1) ) );



    print "\t", sprintf("%.0f?",$expectVoxelNum);
    print "\t", join("\t", ($avgVox."?")x(2 - ($#voxPerTissue+1) )) if $#voxPerTissue < 1;


    my $totalExpectedTime = 0;
    $totalExpectedTime = sprintf('%.1f', ($avgVox*3)/$voxPerSec ) if $lifeSecs>0;
    my $remainingSec = $totalExpectedTime - $lifeSecs;

    #print "\naverage per tissue type is ${avgVox}vox (tot ",$avgVox*3," vox). Should take ${totalExpectedTime}s. already ${lifeSecs}s in\n";
    print "\t$totalExpectedTime\t$remainingSec";

 }else { 
  print "\t$lifeSecs\t0";
  }

 print "\n"; # end line
 

}

