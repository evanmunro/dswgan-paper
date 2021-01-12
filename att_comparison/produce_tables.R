suppressMessages(library("dplyr"))
suppressMessages(library("kableExtra"))
print(paste("working directory:", getwd()[1]))

estimator_names = c("DIFF", "BCM", "CM_ln", "CM_rf","CM_nn", "PS_ln", "PS_rf", "PS_nn", "DR_ln", "DR_rf", "DR_nn", "GRF", "RB", "RB_lin", "RB_old")
rename = c("DIFF"="DIFF", "BCM"="BCM", "CM_ln"="L", "CM_rf"="RF", "CM_nn"="NN","PS_ln"="L", "PS_rf"="RF", "PS_nn"="NN", "DR_ln"="L", "DR_rf"="RF", "DR_nn"="NN", "GRF"="CF", "RB"="RB", "RB_lin"="RB_lin", "RB_old"="RB_old")

estimator_group = function(method) {
    result = list(list("", 0, 0))
    baselines =  c("DIFF", "BCM")
    outcome = c("CM_ln", "CM_rf","CM_nn")
    pscore = c("PS_ln", "PS_rf", "PS_nn")
    drob = c("DR_ln", "DR_rf", "DR_nn", "GRF", "RB", "RB_lin")
    if (any(method %in% baselines)) {
        result = append(result, list(list("Baselines", 1, sum(method %in% baselines))))
    }
    if (any(method %in% outcome)) {
        last = result[[length(result)]][[3]]
        result = append(result, list(list("Outcome Models", last+1, last+sum(method %in% outcome))))
    }
    if (any(method %in% pscore)) {
        last = result[[length(result)]][[3]]
        result = append(result, list(list("Propensity Score Models", last+1, last+sum(method %in% pscore))))
    }
    if (any(method %in% drob)) {
        last = result[[length(result)]][[3]]
        result = append(result, list(list("Doubly Robust Methods", last+1, last+sum(method %in% drob))))
    }
    return(result[2:length(result)])
}
## Original Data 

run_exp = feather::read_feather("att_comparison/original_data/exp_merged.feather") %>% as.tbl
run_cps = feather::read_feather("att_comparison/original_data/cps_merged.feather") %>% as.tbl 
run_psid = feather::read_feather("att_comparison/original_data/psid_merged.feather") %>% as.tbl
original_table = cbind(run_exp, run_cps[,2:3], run_psid[,2:3])
original_table$method = original_table$method %>% as.character
original_table[,2:7] = round(original_table[,2:7]/1000, 2)
colnames(original_table) = c("method", 1:6)
group_header = c(" ", 2, 2, 2)
names(group_header) = c("", "Experimental", "CPS", "PSID")
original_table = original_table %>%
                arrange(match(method, estimator_names))
mthds = original_table$method
original_table = original_table %>%
                mutate(method = rename[mthds]) %>%
                kable("latex", longtable = F, booktabs = T, col.names= c(" ", rep(c("estimate", "s.e."), 3))) %>%
                kable_styling(full_width = F) %>%
                add_header_above(group_header) %>%
                kable_styling(latex_options = c("repeat_header"))
for (group in estimator_group(mthds)) {
    original_table = original_table %>% pack_rows(group[[1]], group[[2]], group[[3]])
}
original_table %>% write("tables/table4.txt")

### Generated Data
make_table = function(runfile, datafile) {
    gt = feather::read_feather(datafile) %>% 
        filter(t==1) %>% mutate(te = re78 - re78_cf) %>%
        summarise(att=mean(te), se=sd(te)/n()^0.5)
    runs = feather::read_feather(runfile) %>% as.tbl %>%
        mutate(error = (att - gt$att)/1000, se=se/1000) %>%
        mutate(covered = abs(error)<1.96*se, detected=att>1.96*se) %>%
        mutate(method = as.character(method))
    results = runs %>%
        group_by(method) %>%
        summarise(rmse = sqrt(mean(error^2)), bias = mean(error), sdev=sd(error),
                  coverage = mean(covered), power = mean(detected), n_runs=as.character(n()),
                  rmse_se = sd(error^2)/sqrt(n())/2/sqrt(mean(error^2)), bias_se = sd(error)/sqrt(n()), 
                  sdev_se = sd((error-mean(error))^2)/sqrt(n())/2/sqrt(sd(error)),
                  coverage_se = sd(covered)/sqrt(n()),
                  power_se = sd(detected)/sqrt(n())) %>%
        ungroup() %>%
        mutate(rank = rank(rmse)) %>%
        select(method, rank, rmse, rmse_se, bias, bias_se, sdev, sdev_se, coverage, coverage_se, power, power_se, n_runs)
    return(results %>% as.tbl)
}

{aggregate_tables = function(runfiles, datafiles, labels, columns, summarize, outfile, n_digits) {
    if (endsWith(outfile, ".txt")) {
        outtype = "latex"
    } else if (endsWith(outfile, ".html")) {
        outtype = "html"
    } else {
        stop("outfile must end in .txt or .html")
    }
    aggregate_table = NULL
    for (i in 1:length(runfiles)) {
        current_table = make_table(runfiles[i], datafiles[i]) %>% select(c("method", columns))
        current_table$label = labels[i]
        aggregate_table = rbind(aggregate_table, current_table)
    }
    
    if (summarize) {
        var_se = function(x) paste0(round(mean(x), n_digits), ' (', round(sd(x), n_digits), ')')
        final_table = aggregate_table %>%
            select(-label) %>%
            group_by(method) %>%
            summarize_all(.funs=var_se) %>%
            arrange(match(method, estimator_names))
        mthds = final_table$method
        final_table = final_table %>%
            mutate(method = rename[mthds])
        ktable = final_table %>% kable(outtype, longtable = F, booktabs = T) %>% kable_styling(full_width = F)
    } else {
        final_table = NULL
        for (col in columns) {
            col_table = aggregate_table %>% 
                select(method, label, !!col) %>%
                tidyr::spread(label, !!col) %>%
                mutate_if(.predicate=is.numeric, .funs=function(var) round(var, n_digits)) %>%
                select(c("method", labels))
            methods = col_table %>% select(method)
            colnames(col_table)[-1] = paste0(col, "_", colnames(col_table)[-1])
            if (is.null(final_table)) {final_table = col_table} else {final_table = cbind(final_table, col_table %>% select(-method))}
        }
        if (length(labels) > 1) {
            group_header = c(" ", rep(length(labels), length(columns)))
            names(group_header) = c("", columns)
            col_names = c("method", rep(labels, length(columns)))
        } else {
            group_header = c(" ", length(columns))
            names(group_header) = c("", labels)
            col_names = c("method", columns)
        }
        ktable = final_table %>%
            arrange(match(method, estimator_names))
        mthds = ktable$method
        ktable = ktable %>%
            mutate(method = rename[mthds]) %>%
            kable(outtype, longtable = F, booktabs = T, col.names=col_names) %>%
            kable_styling(full_width = F) %>%
            add_header_above(group_header) %>%
            kable_styling(latex_options = c("repeat_header"))
    }
    for (group in estimator_group(mthds)) {
        ktable = ktable %>% pack_rows(group[[1]], group[[2]], group[[3]])
    }
    
    if (outtype == "latex") {
        ktable %>% write(outfile)
    } else {
        ktable %>% save_kable(file = outfile, self_contained = T)
    }
}
}
## Main Tables 
runfiles = c("att_comparison/generated/exp_generated.feather")
datafiles = c("data/generated/exp_generated.feather")
aggregate_tables(runfiles, datafiles, labels=c("exp"),
                columns=c("rmse", "bias", "sdev", "coverage"), summarize=FALSE, outfile="tables/table5.txt", n_digits=2)

runfiles = c("att_comparison/generated/cps_generated.feather")
datafiles = c("data/generated/cps_generated.feather")
aggregate_tables(runfiles, datafiles, labels=c("cps"),
                columns=c("rmse", "bias", "sdev", "coverage"), summarize=FALSE, outfile="tables/table6.txt", n_digits=2)

runfiles = c("att_comparison/generated/psid_generated.feather")
datafiles = c("data/generated/psid_generated.feather")
aggregate_tables(runfiles, datafiles, labels=c("psid"),
                columns=c("rmse", "bias", "sdev", "coverage"), summarize=FALSE, outfile="tables/table7.txt", n_digits=2)

## Robustness Exercises
# CV Excercise
runfiles = paste0("att_comparison/generated/robustness/tbl_cv/cps", 0:9, "_generated.feather")
datafiles = paste0("data/generated/robustness/tbl_cv/cps", 0:9, "_generated.feather")
aggregate_tables(runfiles, datafiles, labels=0:10,
                columns=c("rmse", "bias", "sdev", "coverage"), summarize=TRUE, outfile="tables/table8.txt", n_digits=2)

# Architecture Exercise
runfiles = c("att_comparison/generated/cps_generated.feather",
             paste0("att_comparison/generated/robustness/tbl_arch/", c("arch1", "arch2"), "_generated.feather"))
datafiles = c("data/generated/cps_generated.feather", 
              paste0("data/generated/robustness/tbl_arch/", c("arch1", "arch2"), "_generated.feather"))
aggregate_tables(runfiles, datafiles, labels=c("Main", "Alt1", "Alt2"),
                columns=c("rmse", "bias", "sdev"), summarize=FALSE, outfile="tables/table9.txt", n_digits=2)                          
                          
# Size Exercise
runfiles = c(paste0("att_comparison/generated/robustness/tbl_size/cps", c("20.0", "30.0", "40.0", "50.0", "60.0", "70.0", "80.0", "90.0"), "_generated.feather"),
             "att_comparison/generated/cps_generated.feather")
datafiles = c(paste0("data/generated/robustness/tbl_size/cps", c("20.0", "30.0", "40.0", "50.0", "60.0", "70.0", "80.0", "90.0"), "_generated.feather"),
             "data/generated/cps_generated.feather")
aggregate_tables(runfiles, datafiles, labels=c("0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8", "0.9", "1.0"),
                columns=c("rmse"), summarize=FALSE, outfile="tables/table10.txt", n_digits=2)
