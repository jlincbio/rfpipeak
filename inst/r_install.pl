use 5.016;
use strict;
use warnings;
use File::Fetch;
use File::Basename;
use File::Copy qw(copy move);
use File::Temp qw(tempdir tempfile);

## ERROR CODES:
# 1 -> Windows system
# 2 -> Perl library path not writeable
# 3 -> Missing HTSLIB
# 4 -> Missing components

my $EXEC_OVERWRITE = 1; # SET TO 1 FOR PACKAGE DISTRIBUTION, 0 FOR DEBUG

my ($opt_path, $opt_gzip, $opt_perl, $opt_cred, $opt_seed) = @ARGV;
# $opt_path is the root for perlpkgs

die "Error: working directory not specified!\n" unless (defined $opt_path);
my $rlib_path = $opt_path.'/data';

$File::Fetch::WARN = 0;

unless (($^O eq 'darwin') || ($^O eq 'linux')) {
	print STDERR "rfPIPeak cannot be installed on this system.\n";
	exit 1;
}

unless (defined $opt_seed) {
	# redefined to allow more variations in value instead of epoch time
	my %nbank;
	foreach my $i (split('', time)) {
		my $k = join '.', time, $i;
		$nbank{$k} = $i;
	}
	my $smax = join '', values %nbank;
	$opt_seed = int rand($smax)/3;
}

my %pkgPath = (
	bin  => $opt_path,
	lib  => $opt_path.'/perl5', # perl library path for rfPIPeak
	data => $opt_path.'/data'  # prebuilt data file directory
);

#print STDERR "Please press <RETURN> to continue or Ctrl-C to exit: "; <STDIN>;

## CHECKING PREREQUISITES
print STDERR "Checking required Perl modules...\n";
my (@mod_perl, @inst_perl, @req_perl);
while (<DATA>) {
	chomp;
	if ($_ =~ m/^\#/) {
		# files that need to be updated
		(my $s = $_) =~ s/^\#\.\/inst/$opt_path/;
		push @mod_perl, $s;
	} else {
		push @req_perl, $_;
	}
}
# print STDERR "MODIFY: $_\n" for @mod_perl;

foreach my $key_module (@req_perl) {
	my $key_install = check_pkgs($key_module);
	unless ($key_install) {
		print STDERR "\nMISSING: $key_module";
		push @inst_perl, $key_install;
	} 
}
print STDERR "Checking required applications and current configurations...\n";

unless (defined $ENV{HTSLIB}) {
	print STDERR "Path to HTSLIB is not specified in your shell environment.\n";
	print STDERR "This is required for installation. To install HTSLIB, try this:\n";
	print STDERR "git clone https://github.com/samtools/htslib.git\n";
	print STDERR "cd htslib\n";
	print STDERR "make && make prefix=\$HOME install\n";
	print STDERR "echo \'export HTSLIB=\$HOME\' >> ~/.bash_profile\n";
	exit 3;
}

my %def_config = (
	CONFIG_SOURCE => $opt_path,
	CONFIG_NUPOP  => $opt_path.'/npPsi_bin',
	CONFIG_SUPPL  => $pkgPath{data},
	PATH_SORT     => check_sort($opt_path),
	PATH_AWK      => where('awk'),
	PATH_GZIP     => where('gzip', $opt_gzip),
	PATH_GUNZIP   => where('gunzip'),
	PATH_PERL     => where('perl', $opt_perl),
	PATH_CRED     => $opt_cred,
	SEED_DEFAULT  => $opt_seed,
	OPT_GFORTRAN  => where('gfortran')
);

foreach my $p (values %def_config) {
	exit 4 unless (defined $p);
	exit 4 if ($p eq '');
}

# R config section removed as package checks will be integrated with R package
# my $cmd_rscr = "$def_config{'OPT_RSCRIPT'} -e " if ($def_config{'OPT_RSCRIPT'} ne '');

## INSTALLING PREREQUISITES
my @log_uninstall; my @log_rmdir;
# modifying interpretative directives for existing scripts
# R will automatically copy data files to data, no need to move
print STDERR "\nUpdating environmental parameters...";
sleep 1 and print STDERR "\n";
#my $wktdir = tempdir(CLEANUP => 1);

my $perl_exec = '!'.$def_config{PATH_PERL};
foreach my $f (@mod_perl) {
	swap_from_file($f, 'UPDATE_PERLEXEC_DIRECTIVE', $perl_exec, $EXEC_OVERWRITE);
	swap_from_file($f, 'RFPIPEAK_DIR', "\'$pkgPath{lib}\'", $EXEC_OVERWRITE);
}

my $nupop_source = $opt_path.'/npPsi14.f90';
if ((-e $nupop_source) && (-e $pkgPath{data}.'/MANIFEST')) {
	#print STDERR "Preparing files for nucleosome positioning...\n";
	my $nupop_bin = $opt_path.'/npPsi_bin';
	swap_from_file($nupop_source, 'npParameters/', $pkgPath{data}.'/', $EXEC_OVERWRITE);
	
	my $cmd_compile = sprintf "%s -O3 %s -o %s", $def_config{OPT_GFORTRAN}, $nupop_source, $nupop_bin;
	if ($EXEC_OVERWRITE > 0) {
		my $status_gfortran = 1;
		if ($def_config{OPT_GFORTRAN} ne '') {
			$status_gfortran = system $cmd_compile;
			chmod 0755, $nupop_bin;
		}
		if ($status_gfortran > 0) {
			print STDERR "ERROR: unexpected errors countered during the Fortran compilation stage.\n";
		}
	}
}

my $file_constants = $pkgPath{lib}.'/rfPIPeak/Constants.pm';
#my $kegg_dbprefix = $pkgPath{data}.'/kegg_hsa';
#swap_from_file($file_constants, 'KEGG_DATASET_PREFIX', $kegg_dbprefix, $EXEC_OVERWRITE);
foreach my $k (keys %def_config) {
	swap_from_file($file_constants, $k, $def_config{$k}, $EXEC_OVERWRITE);
}

exit 0;

## SUBROUTINES
sub check_pkgs {
  my $check_module = shift;
  eval "use $check_module";
  return 0 if (($@) && ($@ =~ m/^Can\'t\ locate/));
  return 1;
}
sub which {
	my $f = shift; chomp $f;
	my $test_path;
	my $check_which = `which which`; chomp $check_which;
	if (-e $check_which) {
		$test_path = `which $f`;
		chomp $test_path;
		if ($test_path =~ m/^\//) {
			return $test_path;
		} else {
			return undef;
		}
	} else {
		my @list_path = split /:/, $ENV{'PATH'};
			foreach my $check_path (@list_path) {
			$test_path = join '/', $check_path, $f;
			if (-e $test_path) {
				return "$test_path";
				last;
			}
		}
		return undef;
	}
}
sub where {
	my ($p, $alt) = @_;
	if (defined $alt) {
		if ($alt ne '') {
			# possible parameters are mixed in, parse and remove
			my $dir = dirname $alt;
			my $exe = basename $alt; $exe =~ s/\s-.*$//;
			return $alt if (-e $dir.'/'.$exe); 
		}
	}
	my $q = which($p);
	if (defined $q) {
		return $q;
	}
	print STDERR "ERROR: Cannot locate $p - please check your PATH settings!\n";
	return undef;
}
sub check_sort {
	my $path = shift;
	my $TESTSORT = File::Temp->new(UNLINK => 0);
	my $tmp_fout = $TESTSORT->filename;
	my @test_array = qw(1 02 09 3.14 30);
	print $TESTSORT "$_\n" for @test_array;
	close $TESTSORT;
	my %sortpath = (nsort => where('sort'));
	my $sortconf;
	foreach my $s (keys %sortpath) {
		if ($sortpath{$s} ne '') {
			my $testsort = `$sortpath{$s} -V $tmp_fout`; 
			chomp $testsort; $testsort =~ s/\s/\-/g;
			if ($testsort eq '1-02-3.14-09-30') {
				print STDERR "Sorting will be performed with $sortpath{$s}\.\n";
				$sortconf = join ' ', $sortpath{$s}, '-V';
				last;
			}
		}
	}
	unlink $tmp_fout;
	return $sortconf if (defined $sortconf);
	return "$path/r_natsort.pl";
}
sub swap_from_file {
	my ($file, $original, $replacement, $exec_write) = @_;
	my @contents;
	open my $INPUT, '<', $file or return 2;
	$replacement = '' unless (defined $replacement);
	my $n_changes = 0; my $cur_line = 0;
	while (<$INPUT>) {
		my $l = $_; chomp $l;
		$cur_line++;
		if ($l =~ m/$original/) {
			$n_changes++;
			$l =~ s/$original/$replacement/;
			if ($exec_write < 1) {
				# debug mode, print out which line is modified
				print STDERR "CHANGE: $file (line $cur_line):\n   ---> $l\n";
			}
		}
		push @contents, $l;
	}
	close $INPUT;
	if ($exec_write > 0) {
		if ($n_changes > 0) {
			open my $OUTPUT, '>', $file or return 3;
			print $OUTPUT "$_\n" for @contents; 
			close $OUTPUT;
		}
	}
	return 1;
}
sub find_perl_lib {
	# Figure out which Perl directory is writeable -> option orpahaned for now
	my $perl_lib; 
	if (defined $ENV{PERL5LIB}) {
		my @z = split ':', $ENV{PERL5LIB};
		$perl_lib = shift @z;
	} else {
		# manually search for a place to write rfPIPeak module
		my $f_temp = rand;
		my @p_temp;
		print "$_\n" for @INC;
		foreach my $p (@INC) {
			my $z = $p.'/'.$f_temp;
			push @p_temp, $z;
			my $t = open my $F_TESTWRITE, '>', $z;
			if ($t == 1) {
				# define $perl_lib
				unless (defined $perl_lib) {
					$perl_lib = $p;
					last;
				}
			}
		}
		unlink $_ for @p_temp;
	
	}

	if (defined $perl_lib) {
		print STDERR "Library path selected to be $perl_lib\n";
		return $perl_lib;
	} else {
		print STDERR "Error: your Perl installation does not have an accessible library path!\n";
		print STDERR "Install \'local::lib\' from CPAN, set a valid \$PERL5LIB and try again.\n";
		exit 2;
	}
}

# DATA section: manifest of files to be modified and required Perl modules
__DATA__
File::Type
File::Find
Getopt::Long
File::Basename
File::Temp
Inline::C
Math::CDF
Parallel::ForkManager
PerlIO::gzip
Scalar::Util
Statistics::TTest
Storable
#./inst/r_config.pl
#./inst/npPsi14.f90
#./inst/perl5/rfPIPeak/Constants.pm
#./inst/perl5/rfPIPeak/psiOps.pm
#./inst/perl5/rfPIPeak/sam2bed.pm
#./inst/perl5/rfPIPeak/vectorOps.pm
#./inst/perl5/rfPIPeak/coreCounts.pm
#./inst/perl5/rfPIPeak/windowBeds.pm
#./inst/r_natsort.pl
#./inst/generate_coordinates.pl