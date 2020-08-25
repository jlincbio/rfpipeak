\name{bed.annot}
\alias{bed.annot}
\title{Annotate a BED file with entries in another BED file}
\usage{
bed.annot(a, b, opt = "wao", match.only = TRUE)
}
\arguments{
\item{a}{input BED; required.}
\item{b}{database BED; required.}
\item{opt}{BEDTools options; if unspecified, wao will be used.}
\item{match.only}{should only matched entries be returned?}
}
\description{
Intersects two BED files with bedtools, and parses the data into a data.frame
}
\keyword{genome}
\keyword{bedtools}
