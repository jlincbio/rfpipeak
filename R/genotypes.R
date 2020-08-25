#' Reformats a matrix into a genotype-class data frame for LDheatmap
#'
#' Convenience function to convert a matrix (or data frame) to the proper class format for LDheatmap
#' @param x input; required.
#' @keywords vectors
#' @export
genotype.matrix <- function(x) {
	y <- as.data.frame(x)
	for (i in 1:dim(y)[2]) {
		y[,i] <- genetics:::as.genotype(y[,i])
	}
	if ("genotype" %in% class(y[,1])) {
		return(y)
	}
	stop("Error - conversion to genotype matrix cannot continue.")
}
