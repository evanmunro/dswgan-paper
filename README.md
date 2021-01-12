# Replication Repository for "Using Wasserstein Generative Adversarial Networks for the Design of Monte Carlo Simulations"
### Authors: Susan Athey, Guido Imbens, Jonas Metzger and Evan Munro

This repository contains code that can be used to replicate the tables and figures in the authors' [paper](https://arxiv.org/pdf/1909.02210.pdf).

The code is in both R and in Python 3, both of which must be installed. Before replicating any of the analysis, complete the following steps:

**1. Clone our Github repository and change working directory to the repository**
```
git clone https://github.com/evanmunro/dswgan-paper/
cd design-of-simulations
```

**2. Install the python requirements using pip**
```
pip install -r requirements.txt
```
This will install outside packages in Python, as well as our own Python package, `wgan`, for estimating WGANs on economic datasets, which is hosted at https://github.com/gsbDBI/ds-wgan/. If you are looking to train a WGAN on your own dataset, rather than replicating all of the results in our paper, we suggest starting first with the [tutorial and documentation](https://github.com/gsbDBI/ds-wgan/) in the `wgan` package repository.  

**3. Install the required R packages**

The following packages are required. They can be installed through `install.packages`, except for
`balanceHD` which must be installed through the R package `devtools`:

```
install.packages(c("feather","optparse","kableExtra","dplyr","fastDummies", "Matching",
                    "tidyr","tictoc","quadprog","grf","glmnet","randomForest","gtools",
                    "ranger","ANN2","MASS","future.apply","future"))
devtools::install_github("swager/balanceHD")
```
While `balanceHD` works with the quadprog optimizer installed above, applying it to the larger CPS samples requires the pogs or mosek optimizer ([installation instructions](https://github.com/swager/balanceHD)).
The file `check_dependencies.R` loads all the required libraries for the replication files. If it runs without error, then you have installed all the required R packages.

```
Rscript check_dependencies.R
```

**4. Download the simulated data from Google Drive**

The simulated datasets are too large to be hosted on Github. The empty folder in `data/generated/`
must be filled with the contents of the following Google Drive [folder](https://drive.google.com/drive/folders/1y3xPsnlMlNZPYltMDUeJssSjUOOmHiW3?usp=sharing) before running any replication steps.

### Replication Summary

The replication is separated into a series of steps. We first describe how to replicate the exact figures and tables in the paper from intermediate output. We then proceed to describe the steps for reproducing the intermediate output, including estimating WGANs to simulate data and estimating treatment effects on samples of simulated data. Due to random variation in the training of the GANs and samples from the GANs, the intermediate output will not be replicated exactly, but the tables and figures produced from new intermediate output will be similar to those in the paper.

`replication.sh` runs all of the steps to reproduce intermediate output and figures and tables from intermediate output. However, replicating all the analysis in the paper is very computationally intensive; on a laptop the computation may take weeks to run (it can be run more efficiently on a computing cluster). Instead of running all steps at once, we advise being selective about which parts of the intermediate output to reproduce.


## Replication of Tables and Figures from Intermediate Output

To reproduce all tables and figures, run the following, which shouldn't take more than
15 minutes to complete:  

```
python3 exhibits.py
Rscript exhibits.R
```

The PDF figures are saved in `figures\` and LaTeX code for each table is saved in `tables\`

The python script produces the following tables and figures:

- Table 1: Summary Statistics for Lalonde-Dehejia-Wahba Data
- Table 2: Summary Statistics for WGAN-Generated Data based on LDW Data
- Table 3: Wasserstein Distance Calculations for Generated and Normal Data
- Figure 1: Marginal Histograms for CPS Data: `cps_[varname].pdf`
- Figure 2: Correlations for CPS Data:`cps_corr.pdf`
- Figure 3: Conditional Histograms for CPS Data: `ps_c*re74.pdf`
- Figure 4: Kernel Regression on Original Data and WGANs with Various Penalties
- Figure 5: Penalized WGANs Fit Unpenalized Dimensions of the Data

The R script produces the remaining tables:
- Table 4: Out-of-Sample Goodness of Fit on Real and Generated Data
- Table 5: Estimates based on LDW Data
- Table 6: Estimates based on LDW Experimental Data
- Table 7: Estimates based on LDW-CPS Data
- Table 8: Estimates based on LDW-PSID Data
- Table 9: Robustness of Ranking for M=10 Samples
- Table 10: Robustness to Model Architecture
- Table 11: RMSE for Different Training Sizes

Note: For Table 4, the computation of cross-validated error for the neural network
is commented out. There is a bug in the ANN2 package that causes R to crash on Mac OS X.
If you are running the code on Linux, you can uncomment these lines to reproduce
the full table.

## Producing Intermediate Output

### Step 1: WGAN Model Estimation

Run the following to re-estimate GANs and re-simulate data:
```
python3 `gan_estimation/gan_baseline.py`
python3 `gan_estimation/gan_robust.py`
```

- The script `gan_estimation/gan_baseline.py` estimates the baseline models for the three datasets
- The script  `gan_estimation/gan_robust.py` estimates the models for the robustness checks
- Input: A copy of the Dehejia-Wahba sample of the Lalonde data in `data/original_data/`
- Output:
  1.  Large simulated data files in `data/generated/`. As mentioned previously, the exact simulated data used in the published version of the paper is available [here](https://drive.google.com/open?id=1HVtKoI0K5n30sUUd37zrV0_SS7qDGl4d).
  2. The code by default also outputs some diagnostic plots and model weights for every model trained
     to the same folder where the data is saved. These are not used, however, in the replication.

### Step 2: Sample from WGAN and Compute Treatment Effect Estimates

Run the following script to reproduce the intermediate output from the WGAN simulations.
```
sh att_comparison/run_simulations.sh
```

The code is split into parts, corresponding to the respective table in our paper. The first part runs all estimators once on the original data set, producing the intermediate output for table 4. All other parts involve multiple iterations of sampling small data sets from the large data frames generated by python scripts during the previous step, running all estimators on the small data set, and saving the results to the intermediate output files. These parts are computationally intensive and thus commented out by default. All intermediate output is saved to the `att_comparison/` folder.
