#!/bin/bash
#SBATCH --job-name=wgan-org
#SBATCH --time=20:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=64G
#SBATCH -p owners
#SBATCH --requeue

NRUNS=1
NCHUNK=1
NWORKERS=1
RESUME=true
export OMP_NUM_THREADS=1
export SINGULARITYENV_APPEND_PATH=/home/users/metzgerj/mosek/9.2/tools/platform/linux64x86/bin

cd /home/users/metzgerj/athey/metzgerj/github/design-of-simulations
singularity exec \
$GROUP_HOME/metzgerj/stored/containers/pytorch_env/ \
Rscript att_comparison/comparison.R \
--input_data_type $INPUTDTYPE \
--input_feather_path $INPUTPATH \
--output_feather_path $OUTPUTPATH \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS
