\name{clear}
\alias{clear}
\title{Clear R Console}
\usage{
clear(scrollback = FALSE)
}
\arguments{
\item{scrollback}{should the scroll buffer be retained? Defaults to FALSE (cannot scroll back to previous lines).}
}
\description{
This function clears the current R window by a system call hard-coded to clear consoles in OSX and Linux; Windows and IDE supports are experimental.
}
\examples{
clear() # enjoy an empty console window!
}
\keyword{console}
