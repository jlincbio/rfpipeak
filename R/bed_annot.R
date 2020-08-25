#' Annotate a BED file with entries in another BED file
#'
#' Intersects two BED files with bedtools, and parses the data into a data.frame
#' @param a input BED; required.
#' @param b database BED; required.
#' @param opt BEDTools options; if unspecified, "wao" will be used
#' @param match.only should only matched entries be returned?
#' @keywords genome bedtools
#' @export

bed.annot <- function(a, b, opt = "wao", match.only = TRUE) {
	if (file.exists(a) & file.exists(b)) {
		orig.scipen <- getOption("scipen")
		options(scipen = 999)
		cmd <- sprintf("bedtools intersect -a %s -b %s -%s", a, b, opt)
		bed <- system(cmd, intern = TRUE)
		bedList <- sapply(bed, function(x) strsplit(x, "\t"))
		m <- max(sapply(bedList, length))
		n <- length(bedList)
		output <- matrix(NA, nrow = n, ncol = m)
		for (i in 1:dim(output)[1]) {
			output[i,] <- unlist(bedList[i])
		}
		output <- as.data.frame(output)
		output[,2] <- as.numeric(output[,2])
		output[,3] <- as.numeric(output[,3])
		bmatch <- dim(output)[2]
		output[,bmatch] <- as.numeric(output[,bmatch])
	} else {
		message(sprintf("Error: BED files cannot be located!\na: %s\nb: %s\n", a, b))
		return(NULL)
	}
	if (match.only) {
		# remove nonmatches
		output <- output[(output[,bmatch] > 0),]
	}
	options(scipen = orig.scipen)
	return(output)
}