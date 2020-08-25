kurtosis <- cmpfun(function (x) {
    x <- x[!is.na(x)]
    n <- length(x)
    x <- x - mean(x)
    r <- n * sum(x^4)/(sum(x^2)^2)
    y <- r * (1 - 1/n)^2 - 3
    # return(log(exp(z), base = 10))
    return(y)
})

kendall <- cmpfun(function (x, y, use = "everything") {
    if (length(x) == 0L || length(y) == 0L) {
        return(NA)
    } else if ((sum(x == 0) == length(x)) || (sum(y == 0) == length(y))) {
        return(0)
    } else {
        z <- ((!is.na(x)) & (!is.na(y)))
        x <- matrix(x[z], ncol = 1L)
        y <- matrix(y[z], ncol = 1L)
    }   
    
    ncx <- ncol(x)
    ncy <- ncol(y)
    r <- matrix(0, nrow = ncx, ncol = ncy)
    for (i in seq_len(ncx)) {
        for (j in seq_len(ncy)) {
            x2 <- rank(x[, i])
            y2 <- rank(y[, j])
            r[i, j] <- .Call(stats:::C_cor, x2, y2, 1L, "kendall" == "kendall")
        }
    }
    rownames(r) <- colnames(x)
    colnames(r) <- colnames(y)
    return(drop(r))
})

txy <- cmpfun(function(x, y) {
    return(
        tryCatch(t.test(x,y)$p.value,
            error = function(w) {
                return(1)}))
})

validate.peaks <- function(nbed, validations, show.stats = NULL) {
	with.sites <- which(nbed[,7] %in% 2001:2009)
	dim(unique(nbed[with.sites,1:6]))
	fp <- nbed[,8]/(nbed[,8]+nbed[,9])
	f.nonzero <- which(fp != 0)
	dim(unique(nbed[intersect(f.nonzero, with.sites),1:6]))
	f.half <- which(fp > 0.5)
	dim(unique(nbed[intersect(f.half, with.sites),1:6]))
	
	message("Calculating basic statistics...")
	colnames(nbed)[9] <- "V9"
	keys.nbed <- colnames(nbed)[1:6]
	n2 <- data.table:::as.data.table(nbed)[,list(
    	sPd = sum(V8), mPd = mean(V8), q1.pd = summary(V8)[2], 
    	q3.pd = summary(V8)[4], sIn = sum(V9), mIn = mean(V9), 
    	q1.in = summary(V9)[2], q3.in = summary(V9)[4], 
    	kurtPd = kurtosis(V8), kurtIn = kurtosis(V9), t = txy(V8, V9)), keys.nbed]
	
	final <- read.table(file = validation, header = FALSE, sep = "\t")
	final$V2 <- final$V2 - 2000
	final$V3 <- final$V3 + 2000
	key.final <- paste(final$V1, final$V2, final$V3, sep = "\t")
	key.n2 <- paste(n2$V1, n2$V2, n2$V3, sep = "\t")
	n2.positive <- as.logical(match(key.n2, key.final, nomatch = FALSE))
	n2 <- cbind(n2, factor(n2.positive))
	colnames(n2) <- qw("Chrom Start End Symbol Motif Strand sumPd meanPd q1Pd q3Pd sumIn meanIn q1In q3In kurtPd kurtIn tPval Positive")

	n2$kurtPd[!is.finite(n2$kurtPd)] <- floor(min(n2$kurtPd, na.rm = TRUE)) - 1
	n2$kurtIn[!is.finite(n2$kurtIn)] <- floor(min(n2$kurtIn, na.rm = TRUE)) - 1

	# correlate with earlier chem-seq data
	message("Performing Random Forest...")
	c.pos <- match("Positive", colnames(n2))
	g.x <- data.frame(n2)[,7:c.pos]
	g.trees <- c(1, seq(100, 5000, by = 100))
	g.rf <- vector(mode = "list", length = length(g.trees))
	
	for (i in 1:length(g.rf)) {
		cat("Tree count = ", g.trees[i])
		g.rf[[i]] <- ranger:::ranger(formula = Positive ~ ., data = g.x, num.trees = g.trees[i], importance = "impurity", num.threads = 8)
		cat("\n")
	}
	
	if (!is.null(show.stats)) {
		pdf(show.stats, width = 7, height = 7)
		g.err <- sapply(g.rf, function(x) x$prediction.error)
		g.err <- g.err[-1]
		g.err.trees <- g.trees[-1]
		plot(g.err.trees, g.err, pch = 19, type = "p", xlab = "Ensemble Tree Counts", ylab = "Prediction Error")
		g.fit <- glm(g.err ~ g.err.trees, family = binomial)
		g.pred <- data.frame(trees = g.err.trees)
		g.pred$est <- ranger:::predict.ranger(g.fit, newdata = g.pred, type = "response")
		lines(est ~ trees, data = g.pred, col = "green4", lwd = 2)

		g.curr.model <- g.rf[[length(g.rf)]]
		g.importance <- data.frame(
			names(g.curr.model$variable.importance), g.curr.model$variable.importance)
		colnames(g.importance) <- c("Item", "Importance")
		
		barplot(g.importance, xlab = "", ylab = "Gini Impurity Score") # remove ggplot2 until final version	
		#ggplot2:::ggplot(g.importance, 
		#	ggplot2:::aes(x=reorder(Item,Importance), y = Importance, fill = Importance)) +
		#	ggplot2:::geom_bar(stat="identity", position="dodge")+ coord_flip()+
		#	ggplot2:::ylab("Gini Impurity Score")+
		#	ggplot2:::xlab("")+
		#	ggplot2:::guides(fill = FALSE)+
		#	ggplot2:::scale_fill_gradient(low = "red", high = "blue") + 
		#	ggplot2:::theme(text = element_text(size = 8))
		
		g.col <- colors()
		g.col <- unique(gsub("[0-9]$", "", g.col))
		g.col <- unique(gsub("[0-9]$", "", g.col))
		g.col <- g.col[grep("light", g.col, invert = TRUE)]
		g.col <- g.col[grep("yellow", g.col, invert = TRUE)]
		g.col1 <- c("magenta", "green", "mediumslateblue", "darkgray","mediumpurple","darkgreen","azure","snow","cornflowerblue","papayawhip","pink")
        
		g.features <- g.x[,1:11]
		colnames(g.features) <- c("Sum PD", "Mean PD", "Q1 PD", "Q3 PD", "Sum Input", "Mean Input", "Q1 Input", "Q3 Input", "Skewness PD", "Skewness In", "t")
		layout(matrix(1:12, 3,4))
		for (i in 1:dim(g.features)[2]) {
			hist(log(g.features[,i]), col = g.col1[i], xlab = "log Features", main = colnames(g.features)[i])
		}
		
		g.tries <- vector(mode = "list", length = 11)
		for (i in 1:length(g.tries)) {
			g.tries[[i]] <- ranger:::ranger(formula = Positive ~ ., data = g.x, num.trees = 5000, mtry = i, importance = "impurity", num.threads = 8)
		}

		g.tries.err <- sapply(g.tries, function(x) x$prediction.error)
		g.tries.mtry <- sapply(g.tries, function(x) x$mtry)
		plot(g.tries.mtry, g.tries.err, xlab = "Parameters at Split", ylab = "Prediction Error")
		g.tries.fit <- glm(g.tries.err ~ g.tries.mtry, family = binomial)
		g.tries.pred <- data.frame(mtry = g.tries.mtry)
		g.tries.pred$est <- ranger:::predict.ranger(g.tries.fit, newdata = g.tries.pred, type = "response")
		lines(est ~ mtry, data = g.tries.pred, col = "blue4", lwd = 2)
	}
	return(g.rf)
}
