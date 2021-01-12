# --------------------------------------------------
# setup the session
# --------------------------------------------------
library("optparse")
option_list = list(
  make_option(c("--input_data_type"), type="character", default="exp", 
              help="One of exp/cps/psid. Determines number of (un)treated obs, hyperparameters, etc.", metavar="character"),
  make_option(c("--input_feather_path"), type="character", default="generated_exp.feather", 
              help="path to dataset containing treated + controls", metavar="character"),
  make_option(c("--output_feather_path"), type="character", default="out.feather", 
              help="output filename", metavar="character"),
  make_option(c("--resume"), type="logical", default=TRUE, 
              help="Resume from previous intermediate results?", metavar="logical"),
  make_option(c("--N_runs"), type="integer", default=1000L, 
              help="Number of runs per estimator", metavar="integer"),
  make_option(c("--N_chunk"), type="integer", default=20L, 
              help="After N_chunk runs, intermediate results will be saved", metavar="integer"),
  make_option(c("--N_workers"), type="integer", default=1, 
              help="If n_workers > 1, runs will be parallelized using 'future.apply'", metavar="integer")
)

opt_parser = OptionParser(option_list=option_list)
opt = parse_args(opt_parser)

if (opt$N_workers > 1) {
  library("future.apply")
  plan(multiprocess, workers = opt$N_workers)
  options(future.globals.maxSize = 3000 * 1024 ^ 2)
  replicate = future_replicate
}


if (opt$input_data_type == "exp") {
  N_treated = 185; N_control = 260
  rf_p_params = list(num.trees = 800, sample.fraction = 0.5)
  rf_mu_params = list(num.trees = 400, sample.fraction = 0.5)
  nn_p_params = list(hidden = c(8,4), l2 = 0.02)
  nn_mu_params = list(hidden = c(8,4), l2 = 0.01)
  grf_params = list(min.node.size = 18, sample.fraction = 0.5, mtry = 3,
                    alpha = 0.18868161, imbalance.penalty = 0.45784454)
  rb_alpha = 1
} else if (opt$input_data_type == "cps") {
  N_treated = 185; N_control = 15992
  rf_p_params = list(num.trees = 600, sample.fraction = 0.5)
  rf_mu_params = list(num.trees = 800, sample.fraction = 0.5)
  nn_p_params = list(hidden = c(16,8,8), l2 = 0.05)
  nn_mu_params = list(hidden = c(32,8), l2 = 0.05)
  grf_params = list(min.node.size = 3, sample.fraction = 0.5, mtry = 7,
                    alpha = 0.099224568, imbalance.penalty = 0.830981586)
  rb_alpha = 0.25
} else if (opt$input_data_type == "psid") {
  N_treated = 185; N_control = 2490
  rf_p_params = list(num.trees = 400, sample.fraction = 0.8)
  rf_mu_params = list(num.trees = 600, sample.fraction = 0.8)
  nn_p_params = list(hidden = c(16,8,8), l2 = 0.05)
  nn_mu_params = list(hidden = c(16,4), l2 = 0.02)
  grf_params = list(min.node.size = 19, sample.fraction = 0.5, mtry = 3,
                    alpha = 0.163144186371937, imbalance.penalty = 0.601943773806879)
  rb_alpha = 0.25
}


# --------------------------------------------------
# specify estimators and covariates
# --------------------------------------------------
covariates = c("black", "hispanic", "married", "nodegree",
               "re74", "re75", "education", "age")

source("att_comparison/estimators.R")
estimators = list(
  DIFF  = DIFF_ATT,
  BCM   = function(x,y,w) BCM_ATT(x,y,w, M=1),
 
  CM_ln = function(x,y,w) DML_ATT(x,y,w, K=1, type="lin", fix_p=T),
  CM_rf = function(x,y,w) DML_ATT(x,y,w, K=4, type="rf", fix_p=T, mu_params=rf_mu_params, p_params=rf_p_params),
  CM_nn = function(x,y,w) DML_ATT(x,y,w, K=4, type="nn", fix_p=T, mu_params=nn_mu_params, p_params=nn_p_params),

  PS_ln = function(x,y,w) DML_ATT(x,y,w, K=1, type="lin", fix_mu=T),
  PS_rf = function(x,y,w) DML_ATT(x,y,w, K=4, type="rf", fix_mu=T, mu_params=rf_mu_params, p_params=rf_p_params),
  PS_nn = function(x,y,w) DML_ATT(x,y,w, K=4, type="nn", fix_mu=T, mu_params=nn_mu_params, p_params=nn_p_params),

  DR_ln = function(x,y,w) DML_ATT(x,y,w, K=1, type="lin"),
  DR_rf = function(x,y,w) DML_ATT(x,y,w, K=4, type="rf", mu_params=rf_mu_params, p_params=rf_p_params),
  DR_nn = function(x,y,w) DML_ATT(x,y,w, K=4, type="nn", mu_params=nn_mu_params, p_params=nn_p_params),

  GRF   = function(x,y,w) GRF_ATT(x,y,w, grf_params),
  RB    = function(x,y,w) RB_ATT (x,y,w, optimizer="mosek", alpha=rb_alpha)
)
#if (opt$input_data_type == "cps") estimators["RB"] = NULL

    
# --------------------------------------------------
# define some helper functions to loop over
# --------------------------------------------------
get_sample = function() {
  t = data$t == 1
  s = rbind(data[t,][sample(1:sum(t), N_treated),],
                 data[!t,][sample(1:sum(!t), N_control),])
  return(list(X=as.matrix(s[, covariates]), Y=s$re78, W=s$t))
}

iteration = function() {
  import = list(DIFF_ATT, BCM_ATT, RB_ATT, DML_ATT, GRF_ATT, data, N_treated, N_control)
  sampled = get_sample()
  result = estimators[[method]](sampled$X, sampled$Y, sampled$W)
  return(c(att=result$att, se=result$se))
}


# --------------------------------------------------
# execute iterations and save intermediate results
# --------------------------------------------------
suppressWarnings(data <- feather::read_feather(opt$input_feather_path))
N_runs = rep(opt$N_runs, length(estimators))
names(N_runs) = names(estimators)
print(paste("starting iterations with input", opt$input_feather_path))
tictoc::tic("total time: ")
if (opt$resume & file.exists(opt$output_feather_path)) {runs = as.data.frame(feather::read_feather(opt$output_feather_path))} else {runs = NULL}
iter = 0
for (method in (names(estimators))) {
  N_completed = sum(runs$method==method)
  print(paste("Method:", method, "Completed:", N_completed))
  while (N_completed < N_runs[method]) {
    tictoc::tic("chunk time: ")
    N_chunk = ifelse(method == "RB", opt$N_workers, opt$N_workers*opt$N_chunk)
    runs_chunk = replicate(N_chunk, iteration())
    tictoc::toc()
    if (opt$resume & file.exists(opt$output_feather_path) | iter > 0) {runs = as.data.frame(feather::read_feather(opt$output_feather_path))} else {runs = NULL}
    runs = rbind(runs, data.frame(method=method, att=runs_chunk["att",], se=runs_chunk["se",]))
    N_completed = N_completed + ncol(runs_chunk)
    print(paste("Method:", method, "Completed:", N_completed, "| Saving results..."))
    feather::write_feather(runs, opt$output_feather_path)
    iter = iter + 1
  }
}
tictoc::toc()
future:::ClusterRegistry("stop")

