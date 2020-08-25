% Please edit documentation in R/copyLoc.R
\name{copyLoc}
\alias{copyLoc}
\title{Extract coordinates from a Quartz window}
\usage{
copyLoc(n = 1, digits = 2, format = TRUE, clipboards = c("pbcopy",
  "xclip"))
}
\arguments{
\item{n}{number of coordinates to detect and identify; defaults to 1.}

\item{digits}{number of significant figures for the coordinates; defaults to 2 (e.g. 1.00).}

\item{format}{should the coordinates be expressed as a string for output? if TRUE (default), "x = c(x1, x2, ...), y = c(y1, y2, ...)" is returned so the string can be copied and pasted as part of a subsequent plotting calls. If FALSE, a (n * 2) matrix containing n pairs of x and y coordinates is returned.}

\item{clipboards}{a list of clipboard bridges to check. To use a bridging program, specify it as a string.}
}
\description{
Extract coordinates from a Quartz/X11 device via clipboard access; allows point-and-click access on figure to return in console a list of coordinates(in string format) on the graphic device. pbcopy (OSX) or xclip (Linux) is required for operation.
}
\examples{
plot(rnorm(20), rnorm(20))
g <- copyLoc(n = 1, clipboards = "hello kitty")
# should get NA unless your clipboard file happens to be called hello
# ('kitty' is treated as the argument)
g <- copyLoc(2)
# [1] "x = c(3.97, 3.71), y = c(6.41, 6.88)"
}
\keyword{clipboard}
\keyword{quartz}
\keyword{x11}
