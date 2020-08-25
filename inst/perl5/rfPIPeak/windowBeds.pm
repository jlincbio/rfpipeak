package rfPIPeak::windowBeds;

# windowBeds.pm: trial implementation to reduce memory and iterations during coverage calculation

use 5.016;
use strict;
use warnings;
use lib RFPIPEAK_DIR;
use rfPIPeak::psiOps 'check_gzip';

sub new {
    my ($class, $file, $motif, $window) = @_; 
	
	my $l = 0; my $record = 0;
	my $sumRun = 0; my $sumPip = 0; my ($siteid, $chromPos);
	my (@basecov, %windows, @heads, @tails, %chrom, %sumWindows, %sumMotifs);
	my $mode_input = check_gzip($file, '<'); 
	open my $INPUT_BED, $mode_input, $file or die "Error!\n";
	while (<$INPUT_BED>) {
		chomp $_; my @entry = split "\t", $_;
		if ($l == 0) {
			$siteid = $entry[3];
			$chromPos = sprintf("%s\:%u\-%u", $entry[0], $entry[1], $entry[2]);
		}
		if (($entry[4] == 1) || eof) {
			push(@heads, $l) if ($entry[4] == 1);
			if (($l > 1)) {
				# start a new record at head and write old one;
				if (eof) {
					push @tails, $l;
				} else {
					push @tails, ($l - 1)
				}
				$windows{$siteid} = [@basecov];
				$sumWindows{$siteid} = $sumRun;
				$sumMotifs{$siteid} = $sumPip;
				$chrom{$siteid} = $chromPos;
				undef @basecov; $sumRun = 0; $sumPip = 0;
				$siteid = $entry[3];
				$chromPos = sprintf("%s\:%u\-%u", $entry[0], $entry[1], $entry[2]);
			}
		}
		
		if (($entry[4] > $window) && ($entry[4] <= ($window + $motif))) {
			$sumPip = $sumPip + $entry[5];
		}
		push @basecov, $entry[5];
		$sumRun = $sumRun + $entry[5];
		$l++;
	}
	close $INPUT_BED;
	#printf "head count: %u and tail count %u\n", scalar @heads, scalar @tails;
	#print "$_ " for @heads;
	#print "\n";
	
	my @keys = keys %windows;
    my $self = {
        reads => \%windows,
		sites => scalar keys %windows,
        heads => \@heads,
		tails => \@tails,
		chrom => \%chrom,
		match => \@keys,
		wsum  => \%sumWindows,
		msum  => \%sumMotifs
	};
	
    bless $self, $class;
    return $self;
}

sub get_reads {
	my ($self, $k) = @_;
	return $self->{reads}->{$k};
} 

sub indices {
	my $self = shift;
	my $keys = $self->{match};
	return $keys;
}

sub counts {
	my $self = shift;
	return $self->{sites};
}

sub get_heads {
	my $self = shift;
	my $keys = $self->{heads};
	return $keys;
}

sub len_reads {
	my ($self, $k) = @_;
	my $reads = $self->{reads}->{$k};
	return scalar @{$reads};
}

sub has_reads {
	my ($self, $k) = @_;
	if (defined $k) {
		return ((defined $self->{reads}->{$k}) && (($self->{wsum}->{$k}) > 0));
	}
	return 0;
}

sub get_pos {
	my ($self, $k) = shift;
	my $pos = $self->{chrom}->{$k};
	return $pos if (defined $pos);
	return '';
}

sub inclusion {
	my ($self, $k, $min) = @_;
	my $window = $self->{wsum}->{$k};
	my $motif = $self->{msum}->{$k};
	return (($window > 0) && ($motif >= $min));
}

1;