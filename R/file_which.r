#' Find path to an executable file 
#'
#' A utility functional analog of "which" that searches through $PATH for the first instance of a particular executable, or returns NULL if one cannot be found. 
#' @param  x filename of the executable file as a string; required.
#' @keywords which
#' @export
#' @examples
#' file.which("R") # find your copy of R executable
#' file.which("Supercalifragilisticexpialidocious") # should return NULL unless you do have a file with this name

file.which <- function(x) {
	# path dividers depending on OS type
	if (Sys.info()[["sysname"]] == "Windows") {
		my.sep <- ";"
	} else {
		# Unix-like
		my.sep <- ":"
	}
	
    my.path <- unlist(strsplit(Sys.getenv("PATH"), split = my.sep))
    path.found <- vector(mode = "character", length = length(my.path))
    for (i in 1:length(my.path)) {
        tmp.path <- paste(my.path[i], x, sep = "/")
        if (file.access(tmp.path, mode = 1) == 0) {
            path.found[i] <- tmp.path
        } else {
            path.found[i] <- NA
        }
    }
    path.found <- path.found[!is.na(path.found)]
    if (length(path.found) < 1) {
        return(NULL)
    }
    return(path.found[1])
}