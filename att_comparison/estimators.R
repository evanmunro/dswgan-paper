#--------------------------------#
# various estimators for the ATT #
#--------------------------------#
source("att_comparison/basis_utils.R")

# Residual balancing estimator (Athey, Imbens and Wager 2018)
# install and activate requirements:
  # devtools::install_github("swager/balanceHD")
  # install.packages("quadprog")
RB_ATT = function(X, Y, W, interactions=TRUE, ...) {
  # any arguments passed to ... will be forwarded to balanceHD
  if (interactions) {X = expand_covariates(X, W)} # expands covariates as done in p.56 of https://arxiv.org/pdf/1712.00038.pdf
  results = balanceHD::residualBalance.ate(X, Y, W,
                                           estimate.se = TRUE,
                                           target.pop = 1, ...)
  att = results[1]; se  = results[2]
  return(list(att = att, se = se, ci = att + c(-1, 1) * 1.96 * se))
}


# Bias Corrected Matching (Abadie and Imbens 2012)
# (linear mean estimate, mahalanobis dist matching)

BCM_ATT = function(X, Y, W, M) {   
  # M is the number of matches
  m = Matching::Match(Y=Y, Tr=W, X=X, BiasAdjust=TRUE, M=M)
  att = as.numeric(m$est)
  se = as.numeric(m$se)
  return(list(att = att, se = se, ci = att + 1.96 * c(-1,1) * se))
}

# Double Machine Learning (Chernozhukov et. al. 2017)
# install and activate requirements:
  # install.packages("ranger")
DML_ATT = function(X, Y, W, K=4, clip=0.1, fix_mu=F, fix_p=F, type="rf", norm=T, mu_params=list(), p_params=list()) {
  # K is the number of folds
  N = length(Y); tr = (W == 1)
  fold = sample.int(K, N, replace = TRUE)
  att_hat = function(Y, W, mu_0, p) {
    normalize = ifelse(norm, sum((1-W)*p/(1-p)), sum(W)) + 1e-7
    sum(W*(Y-mu_0)/sum(W) - (1-W)*p/(1-p)*(Y-mu_0)/normalize)
  }
  mu_0 = rep(NA, N); p = rep(NA, N); keep = rep(T, N); p_bar = rep(NA, N); att = 0
  if (type == "rf") {model = rf} else if (type == "nn") {model = nn} else {model = linear}
  for (i in 1:K) {
    c = (fold == i)
    nc = !c
    if (K == 1) nc = c
    if(!fix_mu) {
      mu_0[c] = do.call(model, append(list(Y[nc][!tr[nc]], X[nc,][!tr[nc],], X[c,]), mu_params))
    } else {
      mu_0[c] = 0
    }
    if(!fix_p) {
      p[c] = do.call(model, append(list(W[nc], X[nc,], X[c,], probs=TRUE), p_params))
    } else {
      p[c] = 0
    }
    keep[c] = p[c] <= 1-clip
    p_bar[c][keep[c]] = mean(W[c][keep[c]])
    att = att + att_hat(Y[c][keep[c]], W[c][keep[c]], mu_0[c][keep[c]],
                        p[c][keep[c]])*sum(c)/N
  }
  e = W*(Y-mu_0-att)/p_bar-(1-W)*p/(1-p)*(Y-mu_0)/p_bar
  se = sd(e[keep])/sqrt(sum(keep))
  ci = att + c(-1, 1) * 1.96 * se
  return(list(att = att, se = se, ci = ci))
}


# Causal Forest (Athey et. al. 2016)
GRF_ATT = function(X, Y, W, grf_params=list()) {
  forest = do.call(grf::causal_forest, append(list(X, Y, W, num.threads=1), grf_params))
  res = grf::average_treatment_effect(forest, target.sample = "treated", method = "AIPW")
  att = unname(res[1]); se = unname(res[2])
  return(list(att = att, se = se, ci = att + c(-1, 1) * 1.96 * se))
}


# Naive Difference in Outcomes
DIFF_ATT = function(X, Y, W) {
  res = summary(lm(Y ~ W))$coefficients["W", 1:2]
  att = unname(res[1]); se = unname(res[2])
  return(list(att = att, se = se, ci = att + c(-1, 1) * 1.96 * se))
}


# Naive OLS
OLS_ATT = function(X, Y, W) {
  res = summary(lm(Y ~ W + X))$coefficients["W", 1:2]
  att = unname(res[1]); se = unname(res[2])
  return(list(att = att, se = se, ci = att + c(-1, 1) * 1.96 * se))
}



# --------------------------------#
# various regression subroutines #
# --------------------------------#

# neural net implementation
nn = function(Y, X, X_eval, probs=F, hidden=c(32, 8),
              l2=0.01, n_batch=128, n_epochs=50, lr=1e-3, ...) {
  if (probs) Y = as.character(Y)
  net = ANN2::neuralnetwork(X, Y, hidden.layers = hidden,
                           regression = !probs,
                           standardize = TRUE,
                           loss.type = ifelse(probs, "log", "squared"),
                           activ.functions = "relu",
                           optim.type = "adam",
                           L2 = l2,
                           batch.size = n_batch,
                           n.epochs = n_epochs,
                           verbose = F,
                           learn.rates = lr, ...)
  if (probs) return(predict(net, X_eval)$probabilities[, "class_1"])
  if (!probs) return(predict(net, X_eval)$predictions)
}

# random forest implementation
rf = function(Y, X, X_eval, probs=F, ...) {
  if (probs) Y = as.character(Y)
  rf = ranger::ranger(Y ~ ., dat = data.frame(X), probability = probs, num.threads = 1, ...)
  if (probs) return(predict(rf, data.frame(X_eval))$predictions[, "1"])
  if (!probs) return(predict(rf, data.frame(X_eval))$predictions)
}

# linear model implementation
linear = function(Y, X, X_eval, probs=F, ...) {
  family = ifelse(probs, "binomial", "gaussian")
  (predict(glm(Y ~ ., data = as.data.frame(X), family = family, ...),
                 newdata = as.data.frame(X_eval), type="response"))
}
