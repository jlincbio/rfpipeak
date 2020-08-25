#' Refine Peaks
#'
#' Refine peaks estimated by CRED with random forest models
#' @param treatment Path to the treatment ("pulldown") track [BAM].
#' @param control Path to the control ("input") Chem-seq track [BAM]
#' @param est data frame containing CRED results (by `estimate.peaks`)
#' @param ... additional parameters for random forest model
#' @keywords rfPIPeak
#' @export
#' @examples
#' refine.peaks("treatment.bam", "control.bam", results)

refine.peaks <- function(treatment, control, est, ...) {
	return(NA)
}