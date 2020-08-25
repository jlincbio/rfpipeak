p.fisher <- function(p, full = FALSE) {
	keep <- (p > 0) & (p <= 1)
	if (sum(1L * keep) < 2) {
		# warning("Must have at least two valid p values")
		p.adj <- p[keep]
		df <- NA
		chi <- NA
		p1 <- p[keep]
	} else {
		lnp <- log(p[keep])
		chi <- (-2) * sum(lnp)
		df <- 2 * length(lnp)
		p1 <- p[keep]
		p.adj <- stats::pchisq(chi, df, lower.tail = FALSE)
	}
	if (full) {
		return(list(p.adj = p.adj, p = p1, df = df, chisq = chi))
	} else {
		return(p.adj)
	}
}