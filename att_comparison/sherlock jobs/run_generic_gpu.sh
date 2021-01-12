#!/bin/bash
#SBATCH --job-name=wgan-all
#SBATCH --time=7:00:00
#SBATCH -p gpu
#SBATCH --gpus 1

NRUNS=10000
NCHUNK=1
NWORKERS=2
RESUME=true

singularity exec \
--home $GROUP_HOME/metzgerj/github/design-of-simulations \
--writable $GROUP_HOME/metzgerj/stored/containers/pytorch_env/ Rscript att_comparison/comparison.R \
--input_data_type $INPUTDTYPE \
--input_feather_path $INPUTPATH \
--output_feather_path $OUTPUTPATH \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS
