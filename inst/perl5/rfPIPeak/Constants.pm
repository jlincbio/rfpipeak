package rfPIPeak::Constants;

use 5.016;
use strict;
use warnings;
use lib RFPIPEAK_DIR;
use Exporter 'import';

our @EXPORT = ();
our %EXPORT_TAGS = (
	'all' => [qw(NA EPS EPS_LOGMIN EPS_LOGMAX EPS_LOG EPS_ZERO EPS_ITER TRK_SEED FMIN FMAX FMAX_SAMP REF_KEGGDB INFINITE refgenome_hg19 get_rfPIPeak_config)]);
our @EXPORT_OK = (@{$EXPORT_TAGS{all}});

use constant NA         => 'NA';
use constant EPS        => 2.220446e-16;
use constant EPS_LOG    => -36.04365;
use constant EPS_LOGMIN => -999;
use constant EPS_LOGMAX => 999;
use constant EPS_ZERO   => 0.00001;
use constant EPS_ITER   => 0.00000001;
use constant INFINITE   => 'Inf';
use constant TRK_SEED   => SEED_DEFAULT;
use constant FMAX_SAMP  => 100000;
use constant FMIN       => 1/65535;
use constant FMAX       => 65535;
use constant REF_KEGGDB => 'KEGG_DATASET_PREFIX';

my %psi_config = (
	pSource   => 'CONFIG_SOURCE',
	pSuppl    => 'CONFIG_SUPPL',
	pNupop    => 'CONFIG_NUPOP',
	pSort     => 'PATH_SORT',
	pAwk      => 'PATH_AWK',
	pGzip     => 'PATH_GZIP',
	pGunzip   => 'PATH_GUNZIP',
	pBedtools => 'PATH_BEDTOOLS',
	pJava     => 'PATH_JAVA',
	pCred     => 'PATH_CRED',
	pPerl     => 'PATH_PERL',
	pGfortran => 'OPT_GFORTRAN'
);

my %r_hg19 = (
	chr1  => 249250621, chr2  => 243199373, chr3  => 198022430,  
	chr4  => 191154276, chr5  => 180915260, chr6  => 171115067, 
	chr7  => 159138663, chr8  => 146364022, chr9  => 141213431, 
	chr10 => 135534747, chr11 => 135006516, chr12 => 133851895, 
	chr13 => 115169878, chr14 => 107349540, chr15 => 102531392,
	chr16 =>  90354753, chr17 =>  81195210, chr18 =>  78077248, 
	chr19 =>  59128983, chr20 =>  63025520, chr21 =>  48129895, 
	chr22 =>  51304566, chrX  => 155270560, chrY  =>  59373566, 
	chrM  =>  16571);

sub refgenome_hg19 {
	my $return_keys = shift;
	if ($return_keys) {
		return (keys %r_hg19);
	}
	return \%r_hg19;
}

sub get_rfPIPeak_config {
	my $keep_alive = shift;
	my $err = 0;
	foreach my $k (keys %psi_config) {
		if ($psi_config{$k} eq '') {
			$err++;
			last;
		}
	}
	if ($err > 0) {
		unless (defined $keep_alive) {
			die "Error: configurations missing! Rerun the R command \"rfPIPeak.setup()\"!\n";
			return undef;
		}
	}
	return %psi_config;
} 

1;