use 5.016;
use strict;
use warnings;
use Cwd 'realpath';

my ($openmp, $pkgdir) = @ARGV;

# r_config.pl, modified 06/30/20
# configuration files for rfPIPeak

# A copy of realpath for OSX can be found here, although not necessary
# https://github.com/harto/realpath-osx

sub rpath {
	my $q = shift;
	my $cmd = `which $q`; chomp $cmd;
	die "$q cannot be located!\n" if ($cmd eq '');
	my $path = realpath $cmd;
	chomp $path;
	return $path;
}

sub bpfix {
	my $q = shift;
	my $path = `brew --prefix $q`; chomp $path;
	die "$q cannot be located!\n" if ($path eq '');
	return $path;
}

sub check_pkg {
  my $check_module = shift;
  eval "use $check_module";
  return 0 if (($@) && ($@ =~ m/^Can\'t\ locate/));
  return 1;
}

# modified 09/05/18
print STDERR "Checking for required Perl packages...\n";
my $err = 0;
my @ppa = qw(Sort::Key::Natural Compress::Raw::Zlib PerlIO::gzip XML::Parser XML::Twig Spreadsheet::ParseXLSX);
foreach my $k (@ppa) {
	if (check_pkg($k) < 1) {
		$err++;
		print STDERR "Missing: $k\n";
	}
}

my $ostype = lc $^O;
if (($ostype eq 'darwin') && ($openmp > 0)) {
	use Sort::Key::Natural 'natsort';
	# OSX native clang does not have OpenMP, build a Makevars file for Homebrew GCC
	# find gcc from /usr/local/bin
	my @gcc = (rpath('gcc'));
	foreach my $i (`find /usr/local/bin \| grep \"\/gcc\"`) {
		chomp $i;
		if ($i =~ m/gcc\-[0-9]/) {
			push @gcc, $i;
		}
	}
	@gcc = natsort @gcc;

	my @gpp = (rpath('g++'));
	foreach my $i (`find /usr/local/bin \| grep \"\/g\+\+\"`) {
		chomp $i;
		if ($i =~ m/g\+\+\-[0-9]/) {
			push @gpp, $i;
		}
	}
	@gpp = natsort @gpp;

	my $ugcc = pop @gcc;
	my $ugpp = pop @gpp;
	
	print STDERR "Locating libraries...\n";
	my %config = (
		'BGCC' => rpath($ugcc),
		'BGXX' => rpath($ugpp),
		'LTXT' => bpfix('gettext'),
		'LGCC' => bpfix('gcc')
	);
	
	my @makevars = (
		"CC=$config{BGCC} -fopenmp",
		"CXX=$config{BGXX} -fopenmp",
		"CFLAGS=-g -O3 -Wall -pedantic -std=gnu99 -mtune=native -pipe",
		"CXXFLAGS=-g -O3 -Wall -pedantic -std=c++11 -mtune=native -pipe",
		"LDFLAGS=-L$config{LTXT}/lib -L$config{LGCC}/lib -Wl,-rpath,$config{LGCC}/lib",
		"CPPFLAGS=-I$config{LTXT}/include -I$config{LGCC}/include"
	);
	
	my $rdir = $ENV{HOME}.'/.R/Makevars';
	print STDERR "For OpenMP, you should copy and paste the text below to \'$rdir\':\n";
	print STDERR "********************************************************************************\n\n";
	print STDERR "$_\n" for @makevars;
	print STDERR "\n";
	print STDERR "********************************************************************************\n";
}

if (defined $openmp) {
	if ($openmp > 0) {
		# fixing permissions for packages.html; find file and go
		print STDERR "Setting permissions for packages.html...\n";
		my $bin_path = rpath('R');
		(my $lib_path = $bin_path) =~ s/\/bin.*//;
		my @r_help = `find $lib_path \| grep \"packages\.html\$\"`; chomp @r_help; 
		chmod 0777, @r_help;
	}
}

if ($err == 0) {
	print STDERR "Post-installation for R should now be complete.\n";
	if (defined $pkgdir) {
		# being called from R; create checkbit file
		my $log_output = join '/', $pkgdir, 'check.postconfig';
		open my $LOUTPUT, '>', $log_output;
		my $ntime = time; print $LOUTPUT $ntime;
		close $LOUTPUT;
	}
	exit $err;
}
print STDERR "You have missing Perl packages; please install them before proceeding.\n";
exit $err;