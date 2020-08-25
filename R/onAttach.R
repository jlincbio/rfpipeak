.onAttach <- function(libname, pkgname) {
	check.postconfig <- system.file("check.postconfig", package = "rfPIPeak")
	if (check.postconfig == "") {
		# not run before; initialize rfPIPeak.setup()
		message("Warning: setup is not complete - run rfPIPeak.setup()")
	}
}

.onUnload <- function (libpath) {
  library.dynam.unload("rfPIPeak", libpath)
}