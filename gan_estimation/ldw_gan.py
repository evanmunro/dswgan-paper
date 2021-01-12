#wrapper function to save model weights and generate large dataset for
#any Lalonde dataset passed

import wgan
import torch
import pandas as pd
import numpy as np
import ot
from hypergrad import AdamHD

def wd_distance(real, gen):
  n = real.shape[0]
  a = np.ones(n)/n
  d_gen = ot.emd2(a, a, M=ot.dist(real.to_numpy(),
                        gen.to_numpy(),
                        metric='euclidean'), numItermax=2000000)
  return d_gen

def do_all(df, type, batch_size=128, architecture = [128, 128, 128], lr=1e-4,
                    max_epochs=4000, optimizer=AdamHD, path=""):
    print(type, "starting training")
    critic_arch = architecture.copy()
    critic_arch.reverse()
    # X | t
    continuous_vars1 = ["age", "education", "re74", "re75"]
    continuous_lower_bounds1 = {"re74": 0, "re75": 0}
    categorical_vars1 = ["black", "hispanic", "married", "nodegree"]
    context_vars1 = ["t"]

    # Y | X, t
    continuous_vars2 = ["re78"]
    continuous_lower_bounds2 = {"re78": 0}
    context_vars2 = ["t", "age", "education", "re74", "re75", "black",
                          "hispanic", "married", "nodegree"]

    df_balanced = df.sample(2*len(df), weights=(1-df.t.mean())*df.t+df.t.mean()*(1-df.t),
                                    replace=True, random_state=0)
    #First X|t
    data_wrapper1 = wgan.DataWrapper(df_balanced, continuous_vars1, categorical_vars1,
                                     context_vars1, continuous_lower_bounds1)
    x1, context1 = data_wrapper1.preprocess(df_balanced)
    specifications1 = wgan.Specifications(data_wrapper1, critic_d_hidden=critic_arch, generator_d_hidden=architecture,
                                          batch_size=batch_size, optimizer=optimizer, max_epochs=max_epochs, generator_lr=lr, critic_lr=lr, print_every=1e6)

    generator1 = wgan.Generator(specifications1)
    critic1 = wgan.Critic(specifications1)
    #Then Y|X,t
    data_wrapper2 = wgan.DataWrapper(df_balanced, continuous_vars = continuous_vars2,
                                     context_vars= context_vars2, continuous_lower_bounds = continuous_lower_bounds2)
    x2, context2 = data_wrapper2.preprocess(df_balanced)
    specifications2 = wgan.Specifications(data_wrapper2, critic_d_hidden=critic_arch, generator_lr=lr, critic_lr=lr,
                                          generator_d_hidden=architecture, optimizer=optimizer, batch_size=batch_size,
                                          max_epochs=max_epochs,print_every=1e6)

    generator2 = wgan.Generator(specifications2)
    critic2 = wgan.Critic(specifications2)
    df_real = df.copy()
    G=[generator1,generator2]
    C=[critic1,critic2]
    data_wrappers = [data_wrapper1,data_wrapper2]

    wgan.train(generator1, critic1, x1, context1, specifications1)
    wgan.train(generator2, critic2, x2, context2, specifications2)

    df_fake_x = data_wrappers[0].apply_generator(G[0], df.sample(int(1e5), replace=True))
    df_fake = data_wrappers[1].apply_generator(G[1], df_fake_x)

    # Let's also add a counterfactual re78 column to our fake data frame
    df_fake_x["t"] = 1 - df_fake_x["t"]
    df_fake["re78_cf"] = data_wrappers[1].apply_generator(G[1], df_fake_x)["re78"]

    tt = (df_fake.re78 - df_fake.re78_cf).to_numpy()[df_fake.t.to_numpy()==1]
    print("att =", tt.mean(), "| se =", tt.std()/tt.size**0.5)

    # Now, we'll compare our fake data to the real data
    table_groupby = ["t"]
    scatterplot = dict(x=[],
                         y=[],
                         samples = 400)
    histogram = dict(variables=['re78', 'black', 'hispanic', 'married', 'nodegree',
                                  're74', 're75', 'education', 'age'],
                       nrow=3, ncol=3)
    compare_path = path + "compare_"+type
    wgan.compare_dfs(df_real, df_fake, figsize=5, table_groupby=table_groupby,
                       histogram=histogram, scatterplot=scatterplot,save=True,
                       path=compare_path)

    df_fake_x = data_wrappers[0].apply_generator(G[0], df.sample(df.shape[0], replace=True))
    df_fake = data_wrappers[1].apply_generator(G[1], df_fake_x)

    print(df_real.columns)
    df_real = df_real.drop("source",axis=1)
    wd = wd_distance(df_real, df_fake)
    print("wd =", wd)

    for model, name in zip(G + C, ["G_0", "G_1", "C_0", "C_1"]):
      torch.save(model.state_dict(), path+ name + "_{}.pth".format(type))
    n_samples = int(1e6)
    df_fake_x = data_wrappers[0].apply_generator(G[0], df_balanced.sample(n_samples, replace=True))
    df_fake = data_wrappers[1].apply_generator(G[1], df_fake_x)
    df_fake_x["t"] = 1 - df_fake_x["t"]
    df_fake["re78_cf"] = data_wrappers[1].apply_generator(G[1], df_fake_x)["re78"]
    df_fake.to_feather(path+"{}_generated.feather".format(type))
