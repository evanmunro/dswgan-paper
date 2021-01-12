# The  Residual Balancing estimator gets quire resource hungry, especially on the CPS data. 
# Mosek has somewhat better performance than pogs. 
# We recommend commenting out the RB estimator in the comarison.R file, at line 72 before executing this file.

# --------------------------------------------------------------------------------------
# run estimators once on original data sets
# --------------------------------------------------------------------------------------


Rscript att_comparison/comparison.R \
--input_data_type "exp" \
--input_feather_path "data/original_data/exp_merged.feather" \
--output_feather_path "att_comparison/original_data/exp_merged.feather" \
--resume false \
--N_runs 1 \
--N_chunk 1 \
--N_workers 1

#Rscript att_comparison/comparison.R \
#--input_data_type "psid" \
#--input_feather_path "data/original_data/psid_merged.feather" \
#--output_feather_path "att_comparison/original_data/psid_merged.feather" \
#--resume false \
#--N_runs 1 \
#--N_chunk 1 \
#--N_workers 1
#
#Rscript att_comparison/comparison.R \
#--input_data_type "cps" \
#--input_feather_path "data/original_data/cps_merged.feather" \
#--output_feather_path "att_comparison/original_data/cps_merged.feather" \
#--resume false \
#--N_runs 1 \
#--N_chunk 1 \
#--N_workers 1
#
#

# --------------------------------------------------------------------------------------
# run estimators on ranodm subsamples of the simulated data
# --------------------------------------------------------------------------------------

# Optionally supports parallelization by letting NWORKERS processes compute NCHUNK runs in parallel before appending it to the output file. Set RESUME=true, otherwise workers will overwrite each others changes.

NRUNS=10
NCHUNK=1
NWORKERS=1
RESUME=false

COMMAND="Rscript att_comparison/comparison.R"

echo "main comparison on generated data is commented out" && : '

$COMMAND \
--input_data_type "exp" \
--input_feather_path "data/generated/exp_generated.feather" \
--output_RDS_path "att_comparison/generated/exp_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "psid" \
--input_feather_path "data/generated/psid_generated.feather" \
--output_RDS_path "att_comparison/generated/psid_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/cps_generated.feather" \
--output_RDS_path "att_comparison/generated/cps_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

' # comment ends here

# --------------------------------------------------------------------------------------
# run estimators on the data for the Architecture Robustness Check
# --------------------------------------------------------------------------------------

echo "architecture robustness check is commented out" && : '

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_arch/arch1_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_arch/arch1_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_arch/arch2_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_arch/arch2_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

' # comment ends here

# --------------------------------------------------------------------------------------
# run estimators on the data for the Cross Fitting Robustness Check
# --------------------------------------------------------------------------------------

echo "cross fitting robustness check is commented out" && : '

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps0_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps1_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps1_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps2_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps2_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps3_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps3_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps4_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps4_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps5_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps5_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps6_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps6_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps7_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps7_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps8_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps8_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_cv/cps9_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_cv/cps9_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

' # comment ends here


# --------------------------------------------------------------------------------------
# run estimators on the data for the Sample Size Robustness Check
# --------------------------------------------------------------------------------------


echo "sample size robustness check is commented out" && : '

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps100_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps100_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps20.0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps20.0_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps30.0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps30.0_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps40.0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps40.0_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps50.0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps50.0_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps60.0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps60.0_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps70.0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps70.0_generated.feather" \
--resume false \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps8_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps8_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

$COMMAND \
--input_data_type "cps" \
--input_feather_path "data/generated/robustness/tbl_size/cps90.0_generated.feather" \
--output_RDS_path "att_comparison/generated/robustness/tbl_size/cps90.0_generated.feather" \
--resume $RESUME \
--N_runs $NRUNS \
--N_chunk $NCHUNK \
--N_workers $NWORKERS

' # comment ends here
