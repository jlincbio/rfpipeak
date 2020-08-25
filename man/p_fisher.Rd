\name{p.fisher}
\alias{p.fisher}
\alias{Fisher's method}
\title{Combination of p-values by Fisher's sum of logs method
}
\description{Combine p-values by Fisher's ("sum of logs") method.}
\usage{
p.fisher(p, full = FALSE)
}
\arguments{
  \item{p}{Vector of p-values.}
  \item{full}{Should full statistics be returned instead of adjusted p-value alone? Defaults to \code{FALSE}.}
}
\description{
The method is based on the observation that extreme value probabilities can be combined into a test statistic as the sum of their logs (multiplied by -2). In situations where individual p-values are small, this test statistic is large, implying that the null hypotheses will not be true for every test performed; on the other hand, in the case when all the null hypotheses are true, this statistic approximately follows the chi-squared distribution with degree of freedom being equal twice the number of individual p-values. As such, an associated p-value can be summarily inferred from p-values of individual hypothesis testing events in this manner.  

However, please note that since generally there is some positive dependence among tests of similar nature (for instance, validation of the significance of enrichment in a genomic region with different sized sliding windows), the assumption of independence may not always hold, and in cases of marginal significance, the evidence (and subsequently the associated p-value) against the null hypothesis is generally overstated.
}
\value{
Returns either a single associated p-value, or in the case \code{full = TRUE}, a list containing
  \item{chisq}{Value of chi-squared statistic}
  \item{df}{Associated degrees of freedom}
  \item{p.adj}{Associated \mjseqn{p}-value}
  \item{p}{Vector of p-values used for evaluating the associated p-value}
}
\references{
Dewey M (2020). metap: meta-analysis of significance values. R package version 1.4.
}
\author{Jason Lin}
\examples{
p.fisher(c(0.0001, 0.0001, 0.9999, 0.9999)) # is significant
}
\keyword{chisq.test}