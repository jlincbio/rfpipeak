#' Generate an array from a string of text
#'
#' Similar to Perl's qw function, this array converts a whitespace-delimited string into a character or numeric array. 
#' @param x string input.
#' @param as.is keeps numeric entries as characters (defaults to TRUE); to coerce data into numeric values, set this to FALSE.
#' @param na.list character vector of strings that are equivalent to NA (case-sensitive).
#' @keywords qw
#' @export
#' @examples
#' qw("hello world! I can't believe this is not Perl!")
#' # [1] "hello" "world!" "I" "can't" "believe" "this" "is" "not" "Perl!"  
#' qw(1:10)
#' # [1] "1"  "2"  "3"  "4"  "5"  "6"  "7"  "8"  "9"  "10"
#' qw(1:10, as.is = FALSE) # an integer vector from 1 to 10
#' # [1]  1  2  3  4  5  6  7  8  9 10

qw <- function(x = "", as.is = TRUE, na.list = c("NA", "nan", "N/A", "n/a", "na")) {
	y <- unlist(strsplit(trimws(x, which = "both"), "[[:space:]]+"))
	na.counts <- y %in% na.list
	y[na.counts] <- NA
	if (!as.is) {
		z <- suppressWarnings(as.numeric(y))
		if (sum(is.na(z) - is.nan(z)) == sum(na.counts)) {
			return(z)
		}
	}
	return(y)
}