# BED operations - not exported
bed.format <- function(x, bed.nr = length(x), bed.nc = 7) {
	bed.mat <- matrix(NA, nrow = bed.nr, ncol = bed.nc)
	for (i in 1:bed.nr) {
		cur.row <- as.vector(unlist(strsplit(x[i], "\t")))
		if (length(cur.row) >= bed.nc) {
			bed.mat[i,] <- cur.row[1:bed.nc]
		} else {
			bed.mat[i,1:length(cur.row)] <- cur.row
		}
	}
	bed.mat <- as.data.frame(bed.mat)
	colnames(bed.mat) <- c("Chrom", "Start", "End", "Peak", "FE", "Strand", "p")
	bed.mat$Start <- as.numeric(bed.mat$Start)
	bed.mat$End <- as.numeric(bed.mat$End)
	bed.mat$FE <- as.numeric(bed.mat$FE)
	bed.mat$p <- as.numeric(bed.mat$p)
	return(bed.mat)
}
bed.coordinates <- function(treatment, control) {
	z <- tempfile()	
	x <- run.perl(cmd = "generate_coordinates.pl", perl = NULL, 
		treatment, control, z)
	return(bed.format(x, bed.nc = 6))
}
set.perl <- function(perl, silent = TRUE) {
	if (missing(perl) || is.null(perl)) {
		perl <- "perl"
	}
	
	perl <- Sys.which(perl)
	if (perl == "" || perl == "perl") {
		stop("Perl executable cannot be located; specify the location with \'perl = \'")
	}
	
	if (.Platform$OS == "windows") {
		if (length(grep("rtools", tolower(perl))) > 0) {
			perl.ftype <- shell("ftype perl", intern = TRUE)
			if (length(grep("^perl=", perl.ftype)) > 0) {
				perl <- sub('^perl="([^"]*)".*', "\\1", perl.ftype)
			}
		}
	}
	
	if (!silent) {
		cat("Path to Perl binary: ", perl, "\n")
	}
	return(perl)
}
run.perl <- function(cmd, perl = NULL, ...) {
	if (is.null(perl)) {
		perl.path <- set.perl(perl = NULL)
	}
	cmd.path <- system.file(cmd, package = "rfPIPeak")
	cmd.args <- paste(c(cmd.path, ...), collapse = " ")
	cmd.results <- system(command = sprintf("%s %s", perl.path, cmd.args), intern = TRUE)
	return(cmd.results)
}