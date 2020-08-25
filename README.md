# *rfPIPeak*
An R package for peak calling Chem-seq data from pyrrole-imidazole (PI) polyamide affinity-enriched whole genome sequencing data using random forests. 

June 30, 2020: initial package structure uploaded (version 0.0.1000)<br>
August 25, 2020: updated Perl internals

*Note: a decision was made to merge rfPIPeak with PPSI, the previous Chem-seq peak assignment tool. The new tool will use R as the primary interface, and thus is currently undergoing a major rewrite to combine the two. As such, the codes included herein are to be continually updated and not considered fully functional until version 0.1.0000*

## System Requirements
  1. A macOS/Linux environment (WSL may also be compatible)
  2. Perl version 5.16 or above
  3. R version >3.3 (version 3.4.1 or above recommended) 
  4. gcc and GNU Fortran (version 4.8 or above should work)
  5. [CRED](https://github.com/jlincbio/cred)
  6. [htslib](http://www.htslib.org/)

### Perl Dependencies
  * `PerlIO::gzip`
  * `Parallel::ForkManager`
  * `Inline::C`
  * `File::Type`
  * `Math::CDF`
  * `Statistics::TTest`

### R Dependencies
  * `ranger`
  * `data.table`
  * `compiler`
  * `stats`
  * `parallel`
  * `ggplot2`

## Installation
__Note: from this point on all code blocks are R codes__
```
library("devtools") # install.packages("devtools")
devtools::install_github("jlincbio/rfpipeak")
```

After installation of the package, `rfPIPeak.setup()` needs to be executed to properly configure some of the non-R components. At that time there will also be a check on whether your C compiler supports OpenMP (highly recommended as part of the package uses `data.table` that can benefit from it), and if `htslib` is also installed. You also need to set an addition environmental variable named `HTSLIB` that points to the location of `htslib`.

## Miscellaneous
The current version also contains a number of convenience functions that will be removed upon the upload of the final stable version.

## Citations
J. Lin, T. Kuo, P. Horton, H. Nagase, "CRED: a rapid peak caller for Chem-seq data." *J. Open Source Softw.* 4(37): 1423, 2019. DOI: 10.21105/joss.01423

J. Lin, K. Hiraoka, T. Watanabe, T. Kuo et al, "Identification of Binding Targets of a Pyrrole-Imidazole Polyamide KR12 in the LS180 Colorectal Cancer Genome." *PLoS ONE* 11(10): e0165581, 2016. DOI: 10.1371/journal.pone.0165581

rfPIPeak also includes tidbits of code from various sources, including but not limited to:
* diffReps: L. Shen et al, *PLoS ONE* 8(6): e65598, 2013
* uthash: T. Hanson (https://github.com/troydhanson/uthash
* NuPoP: L. Xi et al, *BMC Bioinformatics* 11: 346, 2010

(List will be updated over time)

In R:
`citation("rfPIPeak")`
