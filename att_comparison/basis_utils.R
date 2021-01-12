library(EQL) # for Hermite polynomials
library(rpart)

expand_covariates = function(X, W) {
	continuous = c("re74", "re75", "education", "age")
	X.cont = X[ , continuous]
	X.hermite = generate.basis(X.cont, order=4)
	#X.tree = make.tree.basis(X, W, num.tree=1)
	X.int = model.matrix(~.^2+0, data.frame(X))
	return(cbind(X.hermite, X.int))
}

generate.basis = function(X, order=3) {
    H = lapply(1:ncol(X), function(j) {
        sapply(1:order, function(k) hermite(X[,j], k, prob = TRUE) / sqrt(factorial(k)))
    })
    polys = lapply(1:order, function(r) {
        partitions = combn(r + ncol(X) -1, ncol(X) - 1,
                           function(vec) c(vec, r + ncol(X)) - c(0, vec) - 1)
        elems = sapply(1:ncol(partitions), function(iter) {
            part = partitions[,iter]
            idx = which(part > 0)
            elem = H[[idx[1]]][,part[idx[1]]]
            if (length(idx) > 1) {
                for (id in idx[-1]) {
                    elem = elem * H[[id]][,part[id]]
                }
            }
            elem
        })
        scale(elems) / sqrt(ncol(elems)) / r
    })
    Reduce(cbind, polys)
}

make.tree.basis = function(X, W, num.tree = 5) {
	nobs = length(W)

	Reduce(cbind, lapply(1:num.tree, function(rep) {
		if (rep == 1) {
			features = 1:ncol(X)
		} else {
			features=sample(1:ncol(X), ceiling(3 * ncol(X)/4))
		}

		DF=data.frame(W=W, X[,features])
		tree = rpart(W~., data = DF, control=rpart.control(cp=0))
		nodes = matrix(0, nobs, nrow(tree$frame))
		for(iter in 1:nobs) {
			nodes[iter, tree$where[iter]] = 1
		}

		node.names = as.numeric(rownames(tree$frame))
		for(idx in nrow(tree$frame):2) {
			parent.name = floor(node.names[idx]/2)
			parent.idx = which(node.names == parent.name)
			nodes[,parent.idx] = nodes[,parent.idx] + nodes[,idx]
		}
		nodes
	}))
}
