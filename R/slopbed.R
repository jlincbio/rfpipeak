#' Randomly increase/decrease feature lengths in a BED file 
#'
#' Change feature lengths in a BED file based on normally distributed random sizes; the center of a feature is also shifted either left or right at the same time. Inspired by BEDtool's "flankBed" function, this allows one to randomly permute features for various computations.
#' @param bed BED file for input; The file must be tab-delimited and the first 3 columns must conform to BED standards. Alternatively, a data.frame is also acceptable. Required.
#' @param reformat should the output be reformatted to a BED6 file including only the newly shifted coordinate information? If FALSE, the resultant feature changes will be appended to the right of the existing columns. Defaults to TRUE.
#' @param genome genomic (chromosomal) information corresponding to the BED file. If left as NULL (default), will call fetch.genome() to retrieve precoded hg19 chromosome information, which may or may not be applicable to the supplied BED file.
#' @param read.length average read length; this is used to determine the extent of deviations from a feature center, assuming that the length is normally distributed. Defaults to 128 bp, the average read length from our published KR12 Chem-seq results. To turn off random center shifts, set this to 0.
#' @param slop.range a vector containing possible span of allowable feature shifts (defaults to 300:2000, based on published KR12 Chem-seq methodology);
#' @param bin.size number of randomly selected lengths to change the features (default: 9).
#' @param output to write the result to a new BED file, specify the filename here. The default option is not to create a new file and simply return a data.frame to the console.
#' @keywords bed
#' @export
#' @examples
#' set.seed(123)
#' hg19 <- fetch.genome()
#' chr <- sample(hg19[,1], 5, replace = TRUE)
#' x <- round(hg19[match(chr, hg19[,1]),2] * runif(5))
#' y <- x + 500
#' slopbed(data.frame(chr,x,y))
#' ## features will be slopped with 9 randomly selected extensions (186 ~ 964bp)
#' ## from both ends, shifted left/right following normal dist. w/ mean = 128 bp
#' #    chr         x         y           V4          V5 V6
#' #1  chr8   6667455   6668811 R00051/00428  0.11915888  .
#' #2 chr20  33283709  33285065 R00014/00428  0.03271028  .
#' #3 chr11 120481957 120483173 L00071/00358 -0.19832402  .
#' #4  chrM      8454     10780 R00229/00913  0.25082147  .
#' #5  chrX  70898462  70899818 R00064/00428  0.14953271  .

slopbed <- function(bed, reformat = TRUE, genome = NULL, read.length = 128,
	slop.range = 300:2000, bin.size = 9, output = NULL) {
	options(scipen = 999)
	read.length <- min(read.length, 99999)
	if (bin.size > length(slop.range)) {
		bin.size <- length(slop.range)
	}
	
	refGenome <- fetch.genome(genome)
	if (class(bed) == "character") {
		if (file.exists(bed)) {
			# bed is a file; read as tab-delimited
			siteBed <- read.table(file = bed, header = FALSE, as.is = TRUE, sep = "\t")
		} else {
			cat("# file not found:", bed)
			return(NA)
		}
	} else {
		siteBed <- bed
	}

	if (bin.size > 1) {
		slopSize <- round(sample(x = slop.range, size = bin.size)/2)
		slopBin <- sample(x = 1:bin.size, size = dim(siteBed)[1], replace = TRUE)
		slopShift <- sapply(slopBin, function(x) slopSize[x])
		cat("# features will be slopped with ", bin.size, " randomly selected extensions (",min(slopSize), " ~ ", max(slopSize), "bp)\n", sep = "")
		cat("# from both ends, shifted left/right following normal dist. w/ mean =", read.length, "bp\n")
	} else {
		slopSize <- round(min(slop.range)/2)
		slopShift <- slopSize
		cat("# features will be slopped with ", slopSize, "bp extended from both ends, with normally", sep = "")
		cat("# distributed left/right region shifts of mean", read.length, "bp\n")
	}

	slopCenter <- round(read.length * rnorm(dim(siteBed)[1]))
	new.start <- siteBed[,2] + slopCenter - slopShift
	new.final <- siteBed[,3] + slopCenter + slopShift
	siteBed[,2] <- siteBed[,2] + slopCenter - slopShift
	siteBed[,3] <- siteBed[,3] + slopCenter + slopShift
	
	new.start[new.start < 0] <- 0
	for (i in 1:dim(refGenome)[1]) {
		new.final[(new.final[which(siteBed[,1] %in% refGenome[i,1])]) > refGenome[i,2]] <- refGenome[i,2]
	}

	shiftDirection <- paste(paste(
		ifelse(
			test = (slopCenter < 0),
			yes = "L",
			no = ifelse(
				test = (slopCenter > 0),
				yes = "R",
				no = "N")),
		sprintf("%05d", abs(slopCenter)), sep = ""), sprintf("%05d", slopShift), sep = "/")
	
	if (reformat) {
		siteBed[,2] <- new.start
		siteBed[,3] <- new.final
		siteBed[,4] <- shiftDirection
		siteBed[,5] <- slopCenter/slopShift
		siteBed[,6] <- "."
		siteBed <- siteBed[,1:6]
	} else {
		siteBed <- data.frame(siteBed, siteBed[,1], new.start, new.final, slopCenter, slopShift, shiftDirection)
		colnames(siteBed) <- paste("V", 1:length(colnames(siteBed)), sep = "")
	}

	if (!is.null(output)) {
		# output specified - write to file
		write.table(x = siteBed, file = output, col.names = FALSE, row.names = FALSE,
			quote = FALSE, sep = "\t")
		cat("#Output:", outputName, "\n")
	}
	return(siteBed)
}