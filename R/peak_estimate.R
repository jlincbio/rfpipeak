#' Estimate Peaks
#'
#' R wrapper function to call CRED to estimate possible peak regions
#' @param treatment Path to the treatment ("pulldown") track [BAM].
#' @param control Path to the control ("input") Chem-seq track [BAM]
#' @param p Significance level [default 0.0001]
#' @param q Minimum MAPQ quality for reads to count [default 30]
#' @param w Size of differential windows [default 1200 bp]
#' @param t Should the t-test be used instead of Kolmogorov-Smirnov?
#' @keywords cred
#' @export
#' @examples
#' estimate.peaks("treatment.bam", "control.bam")
 
estimate.peaks <- function(treatment, control, p = 0.0001, q = 30, w = 1200, t = TRUE) {
	cmd <- sprintf("%s -p %f -q %d -w %d %s -t %s -c %s",
		"cred", p, 
		round(q, digits = 0), 
		round(w, digits = 0),
		ifelse(t, yes = "", no = "-k"),
		treatment, control)
	peaks <- system(cmd, intern = TRUE)
	return(bed.format(peaks, bed.nc = 7))
}