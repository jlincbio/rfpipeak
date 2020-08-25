#' Natural sort
#'
#' Performs natural sorting on a character vector with Perl 
#' @keywords perl
#' @export
#' @param alg path to an external sorter executable; defaults to the internal Perl version if unspecified.
#' @param coerce should values that look like numbers or NA's be converted likewise? defaults to FALSE.
#' @param ... data to be passed to natsort() and sorted
#' @examples
#' g <- c("1.1.11", NA, "02.3", "11.7v", "na")
#' sort(g)
#' # [1] "02.3"   "1.1.11" "11.7v"  "na"
#' natsort(g)
#' # [1] "1.1.11" "02.3"   "11.7v"  "na"     NA
#' natsort(g, alg = alg, coerce = TRUE)
#' # [1] "1.1.11" "02.3"   "11.7v"  NA       NA      

natsort <- function(..., alg = NULL, coerce = FALSE) {
	if (is.null(alg)) {
		perl.natsort <- system.file("r_natsort.pl", package = "rfPIPeak")
	} else {
		perl.natsort <- alg
	}
	
	presort <- c(...)
	if (coerce) {
		na.string <- c("NA", "na", "n/a", "nan", "NaN")
		presort[presort %in% na.string] <- NA
	}
	presort.na <- length(which(is.na(presort)))
	presort <- presort[!is.na(presort)]
	# cat(presort)
	check.path <- (perl.natsort != "")
	check.num <- length(which(is.numeric(presort)))
	# message("Number of numeric elements: ", check.num)
	if (check.path) {
		 output.sorted <- system2(command = perl.natsort, args = presort, stdout = TRUE)
		 if (presort.na >= 1) {
			 # NAs present, append to end
			 output.sorted <- c(output.sorted, rep(NA, times = presort.na))
		 }
		 if (coerce) {
			 if (length(output.sorted) == check.num) {
				 return(as.numeric(output.sorted))
			 }
		 }
		 return(output.sorted)
	} else {
		message("Error: sorter cannot be found; run rfPIPeak.setup() to install one or specify \'alg\'")
	}
}