#include <stdio.h>
#ifdef _OPENMP
	#include <omp.h>
	#define HAS_OPENMP 1
#else
	#define HAS_OPENMP 0
#endif

// checks if 

void openmp(int *r) {
	if (HAS_OPENMP > 0) {
		printf("OpenMP is available.\n");
	} else {
		printf("OpenMP is not available with this compiler.\n");
	}
	*r = (int) HAS_OPENMP;
	// *r = (int) HAS_OPENMP;
}

