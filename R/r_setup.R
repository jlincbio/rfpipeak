#' Post-installation configuration for rfPIPeak
#'
#' This function attempt to check and install the necessary Perl modules and configure data.table for OpenMP
#' @keywords rfPIPeak
#' @export
rfPIPeak.setup <- function(silent = TRUE, seed = NULL, gzip = NULL, cred = NULL) {
	perl.postconfig <- system.file("r_config.pl", package = "rfPIPeak")
	perl.pkgdir <- dirname(perl.postconfig)
	perl.path <- Sys.which("perl")
	
	openmp <- as.numeric(.C("openmp", PACKAGE = "rfPIPeak", as.logical(1)))
	
	if (perl.path != "") {
		cmd1.stats <- system2(command = perl.path, 
			args = c(perl.postconfig, openmp, perl.pkgdir))
	}
	# section 2
	if (is.null(seed)) {
		# randomly generate a seed
		seed <- abs(ceiling((as.numeric(Sys.time())/360000) * rnorm(1)))
	}
	
	if (is.null(gzip)) {
		# export R settings
		path.gzip <- Sys.getenv("R_GZIPCMD")
		if (path.gzip == "") {
			path.gzip <- Sys.which("gzip")
		}
	}
	
	if (is.null(cred)) {
		path.cred <- Sys.which("cred")
		if (path.cred == "") {
			stop("CRED does not seem to be installed!")
		}
	}
	
	perl.install <- system.file("r_install.pl", package = "rfPIPeak")
	cmd2.install <- sprintf("%s %s \'%s\' \'%s\' \'%s\' \'%s\' %d", 
		perl.path, perl.install, perl.pkgdir, path.gzip, perl.path, path.cred, seed)
	cmd2.stats <- system(cmd2.install)
	
	if (!silent) {
		return(!as.logical(max(cmd1.stats, cmd2.stats)))
	}
}