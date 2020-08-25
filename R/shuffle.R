#' Shuffle a vector or matrix for randomization
#'
#' Randomly rearranges elements in a vector or matrix
#' @param x input; required.
#' @param along.row should the rows be shuffled instead? Defaults to FALSE
#' @keywords vectors
#' @export
shuffle <- function(x, along.row = FALSE) {
	if (along.row) {
		if (!is.null(dim(x))) {
			return(x[sample(1:dim(x)[1], dim(x)[1], replace = FALSE),])
		}
	}
	return(x[sample(seq_along(x), length(x), replace = FALSE)])
}