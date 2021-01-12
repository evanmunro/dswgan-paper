import wgan
import pandas as pd
import torch
import numpy as np
import torch.nn.functional as F
from matplotlib import pyplot as plt


########################################
# setup
########################################
df = pd.read_feather("data/original_data/cps_merged.feather").drop("u75",1).drop("u74",1)
df = df.loc[df.t==0,]
continuous_vars_0 = ["age", "education", "re74", "re75", "re78"]
continuous_lower_bounds_0 = {"re74": 0, "re75": 0, "re78": 0, "age": 0}
categorical_vars_0 = ["black", "hispanic", "married", "nodegree"]
context_vars_0 = ["t"]
dw = wgan.DataWrapper(df, continuous_vars_0, categorical_vars_0, context_vars_0, continuous_lower_bounds_0)
x, context = dw.preprocess(df)
a = lambda *args, **kwargs: torch.optim.Adam(betas=(0, 0.9), *args, **kwargs)
oa = lambda *args, **kwargs: wgan.OAdam(betas=(0, 0.9), *args, **kwargs)
spec = wgan.Specifications(dw, batch_size=512, max_epochs=int(3e3), print_every=500, optimizer=a, generator_optimizer=oa, critic_lr=1e-4, generator_lr=1e-4)


########################################
# define penalties
########################################
def monotonicity_penalty_kernreg(factor, h=0.1, idx_out=4, idx_in=0, x_min=None, x_max=None, data_wrapper=None):
  """
  Adds Kernel Regression monotonicity penalty.
  Incentivizes monotonicity of the mean of cat(x_hat, context)[:, dim_out] conditional on cat(x_hat, context)[:, dim_in].
  Parameters
  ----------
  x_hat: torch.tensor
      generated data
  context: torch.tensor
      context data
  Returns
  -------
  torch.tensor
  """
  if data_wrapper is not None:
    x_std = torch.cat(data_wrapper.stds, -1).squeeze()[idx_in]
    x_mean = torch.cat(data_wrapper.means, -1).squeeze()[idx_in]
    x_min, x_max = ((x-x_mean)/(x_std+1e-3) for x in (x_min, x_max))
  if x_min is None: x_min = x.min()
  if x_max is None: x_max = x.max()
  def penalty(x_hat, context):
    y, x = (torch.cat([x_hat, context], -1)[:, idx] for idx in (idx_out, idx_in))
    k = lambda x: (1-x.pow(2)).clamp_min(0)
    x_grid = ((x_max-x_min)*torch.arange(20, device=x.device)/20 + x_min).detach()
    W = k((x_grid.unsqueeze(-1) - x)/h).detach()
    W = W/(W.sum(-1, True) + 1e-2)
    y_mean = (W*y).sum(-1).squeeze()
    return (factor * (y_mean[:-1]-y_mean[1:])).clamp_min(0).sum()
  return penalty


def monotonicity_penalty_chetverikov(factor, bound=0, idx_out=4, idx_in=0):
  """
  Adds Chetverikov monotonicity test penalty.
  Incentivizes monotonicity of the mean of cat(x_hat, context)[:, dim_out] conditional on cat(x_hat, context)[:, dim_in].
  Parameters
  ----------
  x_hat: torch.tensor
      generated data
  context: torch.tensor
      context data
  Returns
  -------
  torch.tensor
  """
  def penalty(x_hat, context):
    y, x = (torch.cat([x_hat, context], -1)[:, idx] for idx in (idx_out, idx_in))
    argsort = torch.argsort(x)
    y, x = y[argsort], x[argsort]
    sigma = (y[:-1] - y[1:]).pow(2)
    sigma = torch.cat([sigma, sigma[-1:]])
    k = lambda x: 0.75*F.relu(1-x.pow(2))
    h_max = torch.tensor((x.max()-x.min()).detach()/2).to(x_hat.device)
    n = y.size(0)
    h_min = 0.4*h_max*(np.log(n)/n)**(1/3)
    l_max = int((h_min/h_max).log()/np.log(0.5))
    H = h_max * (torch.tensor([0.5])**torch.arange(l_max)).to(x_hat.device)
    x_dist = (x.unsqueeze(-1) - x) # i, j
    Q = k(x_dist.unsqueeze(-1) / H) # i, j, h
    Q = (Q.unsqueeze(0) * Q.unsqueeze(1)).detach() # i, j, x, h
    y_dist = (y - y.unsqueeze(-1)) # i, j
    sgn = torch.sign(x_dist) * (x_dist.abs() > 1e-8) # i, j
    b = ((y_dist * sgn).unsqueeze(-1).unsqueeze(-1) * Q).sum(0).sum(0) # x, h
    V = ((sgn.unsqueeze(-1).unsqueeze(-1) * Q).sum(1).pow(2)* sigma.unsqueeze(-1).unsqueeze(-1)).sum(0) # x, h
    T = b / (V + 1e-2)
    return T.max().clamp_min(0) * factor
  return penalty



mode = "load"

if mode == "train":
    ########################################
    # train and save models
    ########################################
    gennone, critnone = wgan.Generator(spec), wgan.Critic(spec)
    wgan.train(gennone, critnone, x, context, spec)
    torch.save(genchet,  "monotonicity_penalty/genchet.torch")
    torch.save(critchet, "monotonicity_penalty/critchet.torch")

    genkern, critkern = wgan.Generator(spec), wgan.Critic(spec)
    wgan.train(genkern, critkern, x, context, spec, monotonicity_penalty_kernreg(1, h=1, idx_in=0, idx_out=4, x_min=0, x_max=90, data_wrapper=dw))
    torch.save(genkern,  "monotonicity_penalty/genkern.torch")
    torch.save(critkern, "monotonicity_penalty/critkern.torch")

    genchet, critchet = wgan.Generator(spec), wgan.Critic(spec)
    wgan.train(genchet, critchet, x, context, spec, monotonicity_penalty_chetverikov(1, idx_in=0, idx_out=4))
    torch.save(gennone,  "monotonicity_penalty/gennone.torch")
    torch.save(critnone, "monotonicity_penalty/critnone.torch")

elif mode == "load":
    ########################################
    # load models
    ########################################
    genchet  = torch.load("monotonicity_penalty/genchet.torch", map_location=torch.device('cpu'))
    critchet = torch.load("monotonicity_penalty/critchet.torch", map_location=torch.device('cpu'))
    genkern  = torch.load("monotonicity_penalty/genkern.torch", map_location=torch.device('cpu'))
    critkern = torch.load("monotonicity_penalty/critkern.torch", map_location=torch.device('cpu'))
    gennone  = torch.load("monotonicity_penalty/gennone.torch", map_location=torch.device('cpu'))
    critnone = torch.load("monotonicity_penalty/critnone.torch", map_location=torch.device('cpu'))


########################################
# produce figures
########################################

# sample data
df_none = dw.apply_generator(gennone, df.sample(int(5e5), replace=True)).reset_index(drop=True)
df_kern = dw.apply_generator(genkern, df.sample(int(5e5), replace=True)).reset_index(drop=True)
df_chet = dw.apply_generator(genchet, df.sample(int(5e5), replace=True)).reset_index(drop=True)

# Kernel Smoother for plotting
def y_smooth(x, y, h):
  x, y = torch.tensor(x), torch.tensor(y)
  k = lambda x: (1-x.pow(2)).clamp_min(0)
  x_grid = (x.max()-x.min())*torch.arange(20)/20 + x.min()
  W = k((x_grid.unsqueeze(-1) - x)/h)
  W = W/W.sum(-1, True)
  return x_grid, (W*y).sum(-1)

# Compare conditional means
plt.figure(figsize=(10, 6))
for df_, lab in zip((df, df_none, df_kern, df_chet), ("Original Data", "Unpenalized WGAN", "Kernel Regression Penalty", "Chetverikov Penalty")):
  x_, y = df_.age.to_numpy(), df_.re78.to_numpy()
  x_grid, y_hat = y_smooth(x_, y, 1)
  plt.plot(x_grid, y_hat, label=lab)
plt.ylabel("Earnings 1978")
plt.xlabel("Age")
plt.legend()
plt.savefig("figures/monotonicity.pdf", format="pdf")

# Compare overall fits
f, a = plt.subplots(4, 6, figsize=(15, 10), sharex="col", sharey="col")
for i, (ax, df_, n) in enumerate(zip(a, [df, df_none, df_kern, df_chet], ["Original", "Unpenalized WGAN", "Kernel Regression Penalty", "Chetverikov Penalty"])):
  ax[0].set_ylabel(n)
  ax[0].matshow(df_.drop(["t"], 1).corr())
  ax[1].hist(df_.re78, density=True)
  ax[2].hist(df_.age, density=True)
  ax[3].hist(df_.re74, density=True)
  ax[4].hist(df_.education, density=True)
  ax[5].hist(df_.married, density=True)
  for _ in range(1,6): ax[_].set_yticklabels([])
for i, n in enumerate(["Correlation", "Earnings 1978", "Age", "Earnings 1974", "Education", "Married"]):
  a[0, i].set_title(n)
plt.savefig("figures/monotonicity_fit.pdf", format="pdf")
