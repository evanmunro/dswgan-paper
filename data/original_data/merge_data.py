#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Aug 15 10:20:16 2019

@author: jonas
"""

import pandas as pd

exp = pd.read_feather("exp_merged.feather")
cps = pd.read_feather("cps_controls.feather")
psid = pd.read_feather("psid_controls.feather")

cps = pd.concat((exp.loc[exp.t==1], cps), ignore_index=True)
psid = pd.concat((exp.loc[exp.t==1], psid), ignore_index=True)

cps.to_feather("cps_merged.feather")
psid.to_feather("psid_merged.feather")