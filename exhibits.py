import random
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import ot

#define paths and set random seed
data_path = "data/"
fig_path  = "figures/"
random.seed(100)

################################################################################
## Helper Functions
################################################################################

#load real data and a sample of generated data of equal size
def load_sample(name, path):
    real = pd.read_feather(path+"original_data/{}_merged.feather".format(name)).drop(["u74", "u75"], axis=1)
    n0 = real[real["t"]==0].shape[0]
    n1 = real[real["t"]==1].shape[0]
    gen = pd.read_feather(path+"generated/{}_generated.feather".format(name)).drop(["re78_cf"], axis=1)
    gen = pd.concat([ gen[gen["t"]==1].sample(n1,replace=False),
                  gen[gen["t"]==0].sample(n0,replace=False)])
    return real, gen

#plot a marginal histogram
def histogram(real_data, gen_data, fname, bins):
    plt.figure(figsize=(4,4))
    plt.hist([real_data, gen_data], density=1,
            histtype='bar', label=["real", "generated"], bins=bins, color=["blue", "red"])
    plt.legend(prop={"size": 10})
    plt.yticks([])
    plt.savefig(fname)
    plt.close()

# returns exact wasserstein distance between
# real and generated data and real and multivariate normal
# data that matches the moments of the real data
def wd_distance(real, gen):
    n = real.shape[0]
    normal = pd.DataFrame(np.random.multivariate_normal(real.mean(), real.cov(), n),
                          columns=real.columns)
    a = np.ones(n)/n
    d_gen = ot.emd2(a, a, M=ot.dist(real.to_numpy(),
                              gen.to_numpy(),
                              metric='euclidean'),numItermax=2000000)
    d_normal = ot.emd2(a, a, M=ot.dist(real.to_numpy(),
                              normal.to_numpy(),
                              metric='euclidean'),numItermax=2000000)
    return [d_gen, d_normal]

########################################################################
#Figure 1 (Marginal Histograms)
########################################################################
real, gen = load_sample("cps",data_path)
for var in ["re78","black","hispanic","married","nodegree","re74", "re75", "education", "age"]:
    fname = fig_path + "cps_" + var +".pdf"
    if var in ["re78", "re74", "re75"]:
        bins= 9
    else:
        bins = 10
    histogram(real[var], gen[var], fname, bins)

########################################################################
#Figure 2 (Correlation)
########################################################################
fig4 = plt.figure(figsize=(10,4))
s1 = [fig4.add_subplot(1, 2, i) for i in range(1, 3)]
s1[0].set_xlabel("real")
s1[1].set_xlabel("generated")
s1[0].matshow(real.corr())
s1[1].matshow(gen.corr())
fig4.savefig(fig_path+"cps_corr.pdf")

########################################################################
#Figure 3 (Conditional Histogram)
########################################################################
gen_data1 = gen["re78"][gen["re74"]==0]
real_data1 = real["re78"][real["re74"]==0]

gen_data2 = gen["re78"][gen["re74"]>0]
real_data2 = real["re78"][real["re74"]>0]

bins = 9
histogram(real_data1, gen_data1, fig_path+"cps_c0re74.pdf", bins)
histogram(real_data2, gen_data2, fig_path+"cps_c1re74.pdf", bins)

########################################################################
#Table 1: Summary Statistics for LDW Data
########################################################################
df = pd.read_feather(data_path+"original_data/"+"exp_treated"+".feather").drop(["u74","u75","t"],axis=1)
col_order = ["black", "hispanic", "age", "married", "nodegree", "education", 're74', 're75', 're78']
names = [ "{\tt black}", '{\tt hispanic}', '{\tt age}', '{\tt married}', '{\tt nodegree}', '{\tt education}',
         '{\tt earn \'74}', '{\tt earn \'75}', '{\tt earn \'78}']
results = [names]
colnames = ["Variable"]
for file in ["exp_treated","exp_controls","cps_controls","psid_controls"]:
    df = pd.read_feather(data_path+"original_data/"+file+".feather").drop(["u74","u75","t"],axis=1)
    df = df[col_order]
    means = df.mean()
    stds = df.std()
    means[6:9] = means[6:9]/1000
    stds[6:9] = stds[6:9]/1000
    results.append(means.round(2))
    results.append("(" + stds.round(2).astype(str) +")")
    colnames.append(file + " mean")
    colnames.append(file + " sd")

df = pd.DataFrame(results).transpose()
df.columns = colnames
print("\n Table 1: ")
print(df.to_latex(index=False, escape=False))
with open('tables/table1.txt','w') as tf:
    tf.write(df.to_latex(index=False, escape=False))

########################################################################
#Table 2: Summary Statistics for Generated Data
########################################################################

results = [names]
colnames = ["Variable"]
for name in ["exp","cps","psid"]:
    gen =  pd.read_feather(data_path + "generated/" + name + "_generated.feather")
    gen = gen[col_order+["t"]]
    if name== "exp":
        groups = [1,0]
    else:
        groups = [0]
    for i in groups:
        gen_i = gen[gen["t"]==i].sample(int(1e5), replace=False)
        gen_i = gen_i.drop(["t"],axis=1)
        means = gen_i.mean()
        stds = gen_i.std()
        means[6:9] = means[6:9]/1000
        stds[6:9] = stds[6:9]/1000
        results.append(means.round(2).to_list())
        results.append(("(" + stds.round(2).astype(str) +")").to_list())
        colnames.append(name + str(i)+ " mean")
        colnames.append(name + str(i)+ " sd")

df = pd.DataFrame(results).transpose()
df.columns = colnames
print("\n Table 2: ")
print(df.to_latex(index=False, escape=False))
with open('tables/table2.txt','w') as tf:
    tf.write(df.to_latex(index=False, escape=False))

########################################################################
#Table 3: Wasserstein Distance
########################################################################
random.seed(100)
results = []
for name in ["exp", "cps", "psid"]:
    gendist = 0
    normdist = 0
    if name =="cps":
        #K=1?
        K=3
    else:
        K=10
    for j in range(K):
        real, gen = load_sample(name, data_path)
        wd = wd_distance(real, gen)
        gendist += wd[0]
        normdist += wd[1]
    results.append([name, int(gendist/K), int(normdist/K), gendist/normdist])

df = pd.DataFrame(results, columns=["Dataset","WD, GAN Simulation", "WD, MVN Simulation","Ratio"])
print("\nTable 3: ")
print(df.round(2).to_latex(index=False))
with open('tables/table3.txt','w') as tf:
    tf.write(df.round(2).to_latex(index=False))

########################################################################
#Figures 4 and 5: Enforcing Monotonicity
########################################################################
import os
os.system('python monotonicity_penalty/monotonicity.py')
