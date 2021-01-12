import ldw_gan
import pandas as pd

# first redo with the original data
output_path = "data/generated/"
data_path = "data/original_data/"
#
file = data_path+"exp_merged.feather"
df = pd.read_feather(file).drop(["u74", "u75"], axis=1)
ldw_gan.do_all(df, "exp", batch_size=128, max_epochs=1000, path=output_path)

file = data_path+"cps_merged.feather"
df = pd.read_feather(file).drop(["u74", "u75"], axis=1)
ldw_gan.do_all(df, "cps", batch_size=4096, max_epochs=5000, path=output_path)

file = data_path+"psid_merged.feather"
df = pd.read_feather(file).drop(["u74", "u75"], axis=1)
ldw_gan.do_all(df, "psid", batch_size=512, max_epochs=4000, path=output_path)
