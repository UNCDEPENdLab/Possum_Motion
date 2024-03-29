#PBS -l ncpus=96 
#PBS -l walltime=94:00:00 
#PBS -q batch
#PBS -j oe
#PBS -M hallquistmn@upmc.edu
source $PBS_O_WORKDIR/possumRun.bash
( possumRun 0097 10895_nomot_fullFreq 55.4995833333333 )&
( possumRun 0162 10895_nomot_fullFreq 53.8008611111111 )&
( possumRun 0163 10895_nomot_fullFreq 53.3930277777778 )&
( possumRun 0161 10895_nomot_fullFreq 53.3194722222222 )&
( possumRun 0164 10895_nomot_fullFreq 52.68475 )&
( possumRun 0158 10895_nomot_fullFreq 52.5391111111111 )&
( possumRun 0157 10895_nomot_fullFreq 52.4350833333333 )&
( possumRun 0095 10895_nomot_fullFreq 52.2453333333333 )&
( possumRun 0150 10895_nomot_fullFreq 52.0078055555556 )&
( possumRun 0160 10895_nomot_fullFreq 51.8494722222222 )&
( possumRun 0159 10895_nomot_fullFreq 51.7319444444444 )&
( possumRun 0149 10895_nomot_fullFreq 51.72425 )&
( possumRun 0155 10895_nomot_fullFreq 51.5242222222222 )&
( possumRun 0146 10895_nomot_fullFreq 51.5031944444444 )&
( possumRun 0153 10895_nomot_fullFreq 51.2829722222222 )&
( possumRun 0143 10895_nomot_fullFreq 51.2741666666667 )&
( possumRun 0152 10895_nomot_fullFreq 51.0615833333333 )&
( possumRun 0154 10895_nomot_fullFreq 50.9096666666667 )&
( possumRun 0144 10895_nomot_fullFreq 50.8396944444444 )&
( possumRun 0145 10895_nomot_fullFreq 50.8386111111111 )&
( possumRun 0148 10895_nomot_fullFreq 50.7760277777778 )&
( possumRun 0147 10895_nomot_fullFreq 49.9527222222222 )&
( possumRun 0142 10895_nomot_fullFreq 49.3863611111111 )&
( possumRun 0156 10895_nomot_fullFreq 48.5478611111111 )&
( possumRun 0141 10895_nomot_fullFreq 48.2548611111111 )&
( possumRun 0085 10895_nomot_fullFreq 48.2465 )&
( possumRun 0078 10895_nomot_fullFreq 47.8663055555556 )&
( possumRun 0074 10895_nomot_fullFreq 47.4943333333333;
	 possumRun 0085 10895_nomot_bandpass 18.3654722222222 )&
( possumRun 0070 10895_nomot_fullFreq 47.4234722222222 )&
( possumRun 0075 10895_nomot_fullFreq 47.3404722222222 )&
( possumRun 0069 10895_nomot_fullFreq 46.8911111111111 )&
( possumRun 0073 10895_nomot_fullFreq 46.7329444444444 )&
( possumRun 0071 10895_nomot_fullFreq 46.5974166666667 )&
( possumRun 0061 10895_nomot_roiAvg_fullFreq 39.9307222222222;
	 possumRun 0097 10895_nomot_roiAvg_fullFreq 25.509 )&
( possumRun 0081 10895_nomot_roiAvg_fullFreq 37.8264722222222;
	 possumRun 0160 10895_nomot_roiAvg_fullFreq 25.0383888888889 )&
( possumRun 0058 10895_nomot_roiAvg_fullFreq 37.65075;
	 possumRun 0046 10895_nomot_roiAvg_fullFreq 24.5068611111111 )&
( possumRun 0116 10895_nomot_roiAvg_fullFreq 36.4628888888889;
	 possumRun 0154 10895_nomot_roiAvg_fullFreq 24.4560833333333 )&
( possumRun 0055 10895_nomot_fullFreq 36.369;
	 possumRun 0063 10895_nomot_roiAvg_fullFreq 23.3118055555556 )&
( possumRun 0058 10895_nomot_fullFreq 35.63325;
	 possumRun 0130 10895_nomot_roiAvg_fullFreq 22.8059444444444 )&
( possumRun 0150 10895_nomot_roiAvg_fullFreq 35.4326111111111;
	 possumRun 0075 10895_nomot_roiAvg_fullFreq 22.6883611111111 )&
( possumRun 0139 10895_nomot_roiAvg_fullFreq 33.6264166666667;
	 possumRun 0121 10895_nomot_roiAvg_fullFreq 22.5584444444444 )&
( possumRun 0105 10895_nomot_roiAvg_fullFreq 22.4530833333333;
	 possumRun 0102 10895_nomot_roiAvg_fullFreq 22.3341388888889 )&
( possumRun 0094 10895_nomot_roiAvg_fullFreq 91.1686111111111 )&
( possumRun 0074 10895_nomot_roiAvg_fullFreq 90.8039166666667 )&
( possumRun 0113 10895_nomot_fullFreq 87.2255277777778 )&
( possumRun 0080 10895_nomot_fullFreq 86.1268333333333 )&
( possumRun 0082 10895_nomot_fullFreq 85.8779722222222 )&
( possumRun 0112 10895_nomot_fullFreq 85.4989444444444 )&
( possumRun 0072 10895_nomot_fullFreq 85.1183333333333 )&
( possumRun 0087 10895_nomot_fullFreq 85.0874166666667 )&
( possumRun 0119 10895_nomot_fullFreq 84.6802777777778 )&
( possumRun 0118 10895_nomot_fullFreq 84.6604166666667 )&
( possumRun 0111 10895_nomot_fullFreq 84.5690555555556 )&
( possumRun 0089 10895_nomot_fullFreq 84.4106111111111 )&
( possumRun 0133 10895_nomot_fullFreq 83.4707777777778 )&
( possumRun 0123 10895_nomot_fullFreq 83.3549444444444 )&
( possumRun 0136 10895_nomot_fullFreq 83.2048888888889 )&
( possumRun 0116 10895_nomot_fullFreq 83.0358611111111 )&
( possumRun 0152 10895_nomot_roiAvg_fullFreq 82.9546111111111 )&
( possumRun 0110 10895_nomot_fullFreq 82.8739722222222 )&
( possumRun 0125 10895_nomot_fullFreq 82.7517222222222 )&
( possumRun 0121 10895_nomot_fullFreq 82.7076666666667 )&
( possumRun 0131 10895_nomot_fullFreq 82.4981944444445 )&
( possumRun 0128 10895_nomot_fullFreq 82.4528333333333 )&
( possumRun 0092 10895_nomot_fullFreq 82.2025277777778 )&
( possumRun 0135 10895_nomot_fullFreq 82.1407777777778 )&
( possumRun 0090 10895_nomot_fullFreq 82.1159166666667 )&
( possumRun 0088 10895_nomot_fullFreq 81.9273055555555 )&
( possumRun 0098 10895_nomot_fullFreq 81.7176666666667 )&
( possumRun 0076 10895_nomot_fullFreq 81.2391388888889 )&
( possumRun 0072 10895_nomot_roiAvg_fullFreq 81.0865555555555 )&
( possumRun 0120 10895_nomot_fullFreq 81.0769166666667 )&
( possumRun 0124 10895_nomot_fullFreq 80.2203333333333 )&
( possumRun 0077 10895_nomot_fullFreq 79.9305833333333 )&
( possumRun 0129 10895_nomot_fullFreq 79.8802777777778 )&
( possumRun 0137 10895_nomot_fullFreq 79.8646944444445 )&
( possumRun 0138 10895_nomot_fullFreq 79.6776111111111 )&
( possumRun 0127 10895_nomot_fullFreq 79.4139166666667 )&
( possumRun 0109 10895_nomot_fullFreq 79.0924444444444 )&
( possumRun 0138 10895_nomot_roiAvg_fullFreq 78.9914166666667 )&
( possumRun 0122 10895_nomot_fullFreq 78.6105277777778 )&
( possumRun 0083 10895_nomot_fullFreq 78.2394722222222 )&
( possumRun 0126 10895_nomot_fullFreq 77.7398888888889 )&
( possumRun 0096 10895_nomot_fullFreq 77.6699166666667 )&
( possumRun 0132 10895_nomot_fullFreq 77.6086944444444 )&
( possumRun 0086 10895_nomot_fullFreq 77.2112222222222 )&
( possumRun 0151 10895_nomot_fullFreq 76.5483611111111 )&
( possumRun 0134 10895_nomot_fullFreq 75.7116111111111 )&
( possumRun 0081 10895_nomot_fullFreq 75.1042222222222 )&
( possumRun 0079 10895_nomot_fullFreq 74.7376944444444 )&
( possumRun 0084 10895_nomot_fullFreq 74.7053333333333 )&
( possumRun 0099 10895_nomot_fullFreq 73.0390555555555 )&
( possumRun 0108 10895_nomot_fullFreq 68.9513055555556 )&
( possumRun    )&
( possumRun    )&
( possumRun    ) 
# 55.4995833333333 hours
# 53.8008611111111 hours
# 53.3930277777778 hours
# 53.3194722222222 hours
# 52.68475 hours
# 52.5391111111111 hours
# 52.4350833333333 hours
# 52.2453333333333 hours
# 52.0078055555556 hours
# 51.8494722222222 hours
# 51.7319444444444 hours
# 51.72425 hours
# 51.5242222222222 hours
# 51.5031944444444 hours
# 51.2829722222222 hours
# 51.2741666666667 hours
# 51.0615833333333 hours
# 50.9096666666667 hours
# 50.8396944444444 hours
# 50.8386111111111 hours
# 50.7760277777778 hours
# 49.9527222222222 hours
# 49.3863611111111 hours
# 48.5478611111111 hours
# 48.2548611111111 hours
# 48.2465 hours
# 47.8663055555556 hours
# 65.8598055555556 hours
# 47.4234722222222 hours
# 47.3404722222222 hours
# 46.8911111111111 hours
# 46.7329444444444 hours
# 46.5974166666667 hours
# 65.4397222222222 hours
# 62.8648611111111 hours
# 62.1576111111111 hours
# 60.9189722222222 hours
# 59.6808055555556 hours
# 58.4391944444444 hours
# 58.1209722222222 hours
# 56.1848611111111 hours
# 44.7872222222222 hours
# 91.1686111111111 hours
# 90.8039166666667 hours
# 87.2255277777778 hours
# 86.1268333333333 hours
# 85.8779722222222 hours
# 85.4989444444444 hours
# 85.1183333333333 hours
# 85.0874166666667 hours
# 84.6802777777778 hours
# 84.6604166666667 hours
# 84.5690555555556 hours
# 84.4106111111111 hours
# 83.4707777777778 hours
# 83.3549444444444 hours
# 83.2048888888889 hours
# 83.0358611111111 hours
# 82.9546111111111 hours
# 82.8739722222222 hours
# 82.7517222222222 hours
# 82.7076666666667 hours
# 82.4981944444445 hours
# 82.4528333333333 hours
# 82.2025277777778 hours
# 82.1407777777778 hours
# 82.1159166666667 hours
# 81.9273055555555 hours
# 81.7176666666667 hours
# 81.2391388888889 hours
# 81.0865555555555 hours
# 81.0769166666667 hours
# 80.2203333333333 hours
# 79.9305833333333 hours
# 79.8802777777778 hours
# 79.8646944444445 hours
# 79.6776111111111 hours
# 79.4139166666667 hours
# 79.0924444444444 hours
# 78.9914166666667 hours
# 78.6105277777778 hours
# 78.2394722222222 hours
# 77.7398888888889 hours
# 77.6699166666667 hours
# 77.6086944444444 hours
# 77.2112222222222 hours
# 76.5483611111111 hours
# 75.7116111111111 hours
# 75.1042222222222 hours
# 74.7376944444444 hours
# 74.7053333333333 hours
# 73.0390555555555 hours
# 68.9513055555556 hours
# 0 hours
# 0 hours
# 0 hours 
# 2396 hours lost to idle 
wait
ja -chlst
