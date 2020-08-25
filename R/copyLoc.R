#' Extract coordinates from a Quartz window
#'
#' Extract coordinates from a Quartz/X11 device via clipboard access; allows point-and-click access on figure to return in console a list of coordinates(in string format) on the graphic device. pbcopy (OSX) or xclip (Linux) is required for operation.
#' @param n number of coordinates to detect and identify; defaults to 1.
#' @param digits number of significant figures for the coordinates; defaults to 2 (e.g. 1.00).
#' @param format should the coordinates be expressed as a string for output? if TRUE (default), "x = c(x1, x2, ...), y = c(y1, y2, ...)" is returned so the string can be copied and pasted as part of a subsequent plotting calls. If FALSE, a (n * 2) matrix containing n pairs of x and y coordinates is returned.
#' @param clipboards a list of clipboard bridges to check. To use a bridging program, specify it as a string. 
#' @keywords clipboard quartz x11
#' @export
#' @examples
#' plot(rnorm(20), rnorm(20))
#' g <- copyLoc(n = 1, clipboards = "hello kitty")
#' # should get NA unless your clipboard file happens to be called hello
#' # ('kitty' is treated as the argument)
#' g <- copyLoc(2)
#' # [1] "x = c(3.97, 3.71), y = c(6.41, 6.88)"

copyLoc <- function(n = 1, digits = 2, format = TRUE, clipboards = c("pbcopy", "xclip")) {
	prog.clipboard <- unlist(sapply(clipboards, file.which))
	if (is.null(prog.clipboard)) {
		message("Error: no accessible clipboard interface can be found!")
		if (format) {
			return(NA)
		} else {
			return(matrix(NA, nrow = n, ncol = 2))
		}
	} else {
		prog.clipboard <- prog.clipboard[1]
	}
	
	if (prog.clipboard == "xclip") {
		prog.clipboard <- paste(prog.clipboard, "-selection clipboard")
	}
	
    data <- locator(n)
	data$x <- round(data$x, digits)
	data$y <- round(data$y, digits)
	if (format) {
		if (n > 1) {
			# format as vector
			collapse <- ", "
			head <- "c("
			tail <- ")"
		} else {
			collapse <- head <- tail <- ""
		}
		x <- paste(data$x, collapse = collapse)
		y <- paste(data$y, collapse = collapse)
		cstr <- paste("x = ", head, x, tail, ", y = ", head, y, tail, sep = "")
	} else {
		cstr <- cbind(data$x, data$y)
	}
	clip <- pipe(prog.clipboard, "w")
    write.table(cstr, file = clip, col.names = FALSE, row.names = FALSE)
    close(clip)
	return(cstr)
}