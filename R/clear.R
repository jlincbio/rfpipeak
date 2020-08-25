#' Clear R Console
#'
#' This function clears the current R window by a system call hard-coded to clear consoles in OSX and Linux; Windows and IDE supports are experimental.
#' @param scrollback should the scroll buffer be retained? Defaults to FALSE (cannot scroll back to previous lines).
#' @keywords console
#' @export
#' @examples
#' clear() # enjoy an empty console window!

clear <- function(scrollback = FALSE) {
	if (Sys.info()[['sysname']] != "Windows") {
		cmd.base <- "clear"
	} else {
		# cls in command prompt in Windows
		cmd.base <- "cls"
	}
	if ((!scrollback) &
		(cmd.base == "clear") & 
		((tolower(.Platform$GUI) != "aqua") | (tolower(.Platform$GUI) != "rstudio"))) {
			cmd.base <- paste(cmd.base, "&& printf '\\033[3J'")
	}
	system(cmd.base)
	return(invisible(scrollback))
}
