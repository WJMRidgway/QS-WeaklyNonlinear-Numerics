#!/bin/bash

module load gcc/gcc11

# Executes the unsteady_density code multiple times for a range of parameters

i=3
DP_LIST=($(<Dp.in))
Dp=${DP_LIST[${i}]}

#input timestepping tolerance from file

#input file name
INPUT_FILE="${pwd}input${i}.dat"

#RESTART_FILE="SUPER_RESULT_IC/restart3"

#PARTITION_FILE="SUPER_RESULT_IC/partition.dat"

#generate a new input file  
# output problem parameters to input file 
#**************** Problem Parameters *************************
printf "D2 = 0.2\n" > $INPUT_FILE	#note the single arrow '>'
printf "beta = 8.0\n" >> $INPUT_FILE
printf "alpha = 10.0\n" >> $INPUT_FILE
printf "D1_star = 0.5\n" >> $INPUT_FILE
printf "D1_p_star = ${Dp}\n" >>  $INPUT_FILE
printf "D_inf_0 = 0.1\n" >> $INPUT_FILE
printf "Lu = 1.5\n" >>  $INPUT_FILE
printf "Lx = 8.0\n" >>  $INPUT_FILE
	
#**************** kinetic parameters ***********************
printf "a = 0.3\n" >>  $INPUT_FILE
printf "L = 6.0\n" >>  $INPUT_FILE
printf "K = 0.3\n" >>  $INPUT_FILE
printf "lambda = 4.5\n" >>  $INPUT_FILE
printf "rho_star=0.65\n" >>  $INPUT_FILE
printf "epsilon = 2.0e-3\n" >>  $INPUT_FILE
	
#****************** numerical parameters **********************
printf "epsilon_t = 9e-5\n" >>  $INPUT_FILE
printf "t_max = 1e6\n" >>  $INPUT_FILE
printf "dt_out = 10\n" >>  $INPUT_FILE
printf "Nu_density = 600\n" >>  $INPUT_FILE
printf "Nu_helm = 1\n" >>  $INPUT_FILE
printf "Nx = 50\n" >>  $INPUT_FILE

# setup result directory
RESULT_DIR="STABILITY_TEST_RESULT${i}/"
mkdir $RESULT_DIR

OUT_FILE="${pwd}output${i}.dat"

mpirun -np 32 ./unsteady_density $INPUT_FILE $RESULT_DIR >> $OUT_FILE &
#mpirun -np 16 ./unsteady_density $INPUT_FILE $RESULT_DIR --restart-file $RESTART_FILE --partition-file $PARTITION_FILE >> $OUT_FILE

#sbatch combine_proc_output.sh #combine processor-labelled output files
#sbatch chain0_run1.sh
