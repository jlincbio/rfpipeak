#UPDATE_PERLEXEC_DIRECTIVE
use 5.016;
use strict;
use warnings;
use lib RFPIPEAK_DIR;
use PerlIO::gzip;

# generate flat BED files from compressed GZip archives

my ($f_treatment, $f_control, $f_output) = @ARGV;

if (-e $f_treatment) {
	print STDERR "Reading treatment track...";
	open my $CPULLDOWN, '<:gzip', $f_treatment;
	my %btreatment; my %binput;
	while (<$CPULLDOWN>) {
	    chomp;
	    my @line = split "\t", $_;
	    my $dp = pop @line;
	    my $key = join "\t", @line;
	    $btreatment{$key} = $dp;
	}
	close $CPULLDOWN;
	print STDERR "\n";
} else {
	die "Error: cannot read treatment BED file!\n";
}


if (-e $f_control) {
	print STDERR "Reading input...";
	open my $CINPUT, '<:gzip', $f_control;
	while (<$CINPUT>) {
		chomp;
		my @line = split "\t", $_;
		my $dp = pop @line;
		my $key = join "\t", @line;
		$binput{$key} = $dp;
	}
	close $CINPUT;
	print STDERR "\n";
} else {
	die "Error: cannot read control BED file!\n";
}

print STDERR "Generating coordinates...";
my @k = keys %btreatment;
push @k, keys %binput;
print STDERR "\n";

print STDERR "Combining BEDs...";
my %combined;
foreach my $i (@k) {
    next if (exists $combined{$i});
    my $x = -1;
    my $y = -1;
    $x = $btreatment{$i} if (exists $btreatment{$i});
    $y = $binput{$i} if (exists $binput{$i});
    $combined{$i} = join("\t", $x, $y);
}
print STDERR "\n";
undef %btreatment;
undef %binput;

print STDERR "Writing output...";
open my $WRITEOUT, '>', $f_output;
undef @k; my @l = keys %combined;
foreach my $j (@l) {
    print $WRITEOUT "$j\t$combined{$j}\n";
}
close $WRITEOUT;
print STDERR "\n";

exit 0;