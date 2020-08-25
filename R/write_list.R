#' Write to a List
#'
#' This function write a list to file in plain-text format
#' @param x name of the list. Required.
#' @param filename name of the list. Required.
#' @keywords cats
#' @export
#' @examples
#' write.list()

write.list <- function(x, filename = "data", append = FALSE, closefile = TRUE, outfile) {
# write.list: originally from marray; modified to not print quotes	
    if (!append) {
        outfile <- file(filename, "w")
        cat(file = outfile, append = append)
    }
    for (i in 1:length(x)) {
        
		cat(paste(names(x)[i], "\n----------"), file = outfile, append = TRUE)
        cat("\n", file = outfile, append = TRUE)
        if (!is.null(x[[i]])) {
            switch(data.class(x[[i]]), matrix = write.table(x[[i]], 
                sep = "\t", file = outfile, append = TRUE, quote = FALSE), table = if (!is.null(names(x[[i]]))) {
                write.table(rbind(names(x[[i]]), x[[i]]), file = outfile, 
                  append = TRUE, row.names = FALSE, col.names = FALSE, 
                  sep = "\t", quote = FALSE)
            } else {
                write(x[[i]], file = outfile, append = TRUE)
            }, list = write.list(x[[i]], outfile = outfile, append = TRUE, 
                closefile = FALSE), if (!is.null(names(x[[i]]))) {
                write.table(rbind(names(x[[i]]), x[[i]]), file = outfile, 
                  append = TRUE, row.names = FALSE, col.names = FALSE, 
                  sep = "\t", quote = FALSE)
            } else {
                write(x[[i]], ncolumns = length(x[[i]]), file = outfile, 
                  append = TRUE)
            })
        }
        cat("\n", file = outfile, append = TRUE)
    }
    if (closefile) 
        close(outfile)
}