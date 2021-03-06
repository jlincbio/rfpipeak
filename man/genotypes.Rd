% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/bed_annot.R
\name{genotype.matrix}
\alias{genotype.matrix}
\title{Reformats a matrix into a genotype-class data frame for LDheatmap}
\usage{
genotype.matrix(x)
}
\arguments{
\item{x}{input; required.}
}
\description{
Convenience function to convert a matrix (or data frame) to the proper class format for LDheatmap.
}
\examples{
library(LDheatmap) # loads LDheatmap
data("CEUData") # loads sample data
h1 <- LDheatmap(CEUSNP, CEUDist, LDmeasure="r")
snp2 <- genotype.matrix(shuffle(CEUSNP, along.row = TRUE)) # shuffle along columns 
h2 <- LDheatmap(snp2, CEUDist, LDmeasure="r") # basically same as h1
}
\keyword{vectors}