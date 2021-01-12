import ldw_gan
import pandas as pd
import numpy as np
import multiprocessing
from multiprocessing import active_children
from joblib import Parallel, delayed

num_cores = multiprocessing.cpu_count()
print(num_cores)
# first redo with the original data

epochs=5000
batch=4096
output = "data/generated/robustness/"
datapath = "data/original_data/"
df0 = pd.read_feather(datapath+"cps_controls.feather").drop(["u74", "u75"], axis=1)
df1 = pd.read_feather(datapath+"exp_treated.feather").drop(["u74","u75"], axis=1)

#architecture
df = pd.concat([df0,df1])
Parallel(n_jobs=num_cores)(delayed( ldw_gan.do_all)(df, name, architecture=arch,
                                                  batch_size=batch, max_epochs=epochs, path=output+"tbl_arch/")
                                                  for arch, name in zip([[64, 128, 256], [256, 128, 64]], ["arch1", "arch2"]) )

#Part 1: 80% CV Exercise

def get_sample(df0, df1, pct):
  rows0 = int(pct*len(df0))
  rows1 = int(pct*len(df1))
  controls = df0.sample(rows0, replace=False)
  treated = df1.sample(rows1, replace=False)
  return pd.concat([controls,treated])

df_cv = [ get_sample(df0, df1, 0.8) for i in range(10) ]
name_cv = ["cps"+str(i) for i in range(10)]

Parallel(n_jobs=num_cores)(delayed(ldw_gan.do_all)(dfs, name, batch_size=4096, max_epochs=epochs, path=output+"tbl_cv/")
                                          for dfs, name in zip(df_cv, name_cv) )
df_size = [ get_sample(df0, df1, pct) for pct in [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1] ]
name_size = ["cps"+ str(pct*100) for pct in [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1]]

Parallel(n_jobs=num_cores)(delayed(ldw_gan.do_all)(dfs, name, batch_size=4096,
                              max_epochs=epochs, path=output+"tbl_size/")
                              for dfs, name in zip(df_size, name_size))
