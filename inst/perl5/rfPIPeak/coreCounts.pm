package rfPIPeak::coreCounts;

### Object implementation of core counts

use 5.016;
use strict;
use warnings;
use lib RFPIPEAK_DIR;

sub new {
    my ($class, $cpuCount) = @_;
	my $smp = 1; my $fixed = 2;
	if (defined $cpuCount) {
		$cpuCount = int $cpuCount;
		$fixed = 1;
		$smp = 0 if ($cpuCount < 2);
	} else {
		if (-e '/proc/cpuinfo') {
			open my $CPUIN, '<', '/proc/cpuinfo';
			$cpuCount = 0;
			while (<$CPUIN>) {
				$cpuCount++ if ($_ =~ m/^processor/);
			}
			close $CPUIN;
		} elsif ($^O eq 'darwin') {
			$cpuCount = `sysctl -n hw.ncpu`;
		} else {
			$cpuCount = $ENV{NUMBER_OF_PROCESSORS} // 1;
		}
		chomp $cpuCount;
		if ($cpuCount < 2) {
			$cpuCount = 0; $smp = 0;
		};
	}
	
    my $self = {
        _max =>  $cpuCount,
        _min =>  int ($cpuCount/$fixed),
        _cur =>  $cpuCount,
		_idx => -1,
		_smp =>  $smp,
		_opt =>  $fixed
    };
    bless $self, $class;
    return $self;
}

sub nosmp {
	my $self = shift;
	# set to 0 to adhere to Parallell::ForkManager debug mode 
	$self->{_cur} = 0;
	$self->{_smp} = 0;
	$self->{_max} = 0;
	$self->{_min} = 0;
}

sub gomax {
	my $self = shift;
	if ($self->{_opt} > 1) {
		if ($self->{_smp} > 0) {
			$self->{_cur} = $self->{_max};
		}
	}
}

sub gomin {
	my $self = shift;
	if ($self->{_opt} > 1) {
		if ($self->{_smp} > 0) {
			$self->{_cur} = $self->{_min};
		}
	}
}

sub current {
	my $self = shift;
	my $now = $self->{_cur};
	return $now;
}

sub min {
	my $self = shift;
	my $now = $self->{_min};
	return $now;
}

sub max {
	my $self = shift;
	my $now = $self->{_max};
	return $now;
}

sub update {
	my ($self, $mx) = @_; my $now;
	if ($self->{_opt} > 1) {
		if ($self->{_smp} > 0) {
			if (defined $mx) {
				$now = $mx;
			} else {
				my $uptime = `uptime`; chomp $uptime;
				$uptime =~ s/\,//g;
				my @load = split ' ', $uptime;
				if ($self->{_idx} < 0) {
					for my $i (0..$#load) {
						if ($load[$i] =~ m/average/) {
							$self->{_idx} = $i;
							last;		
						}
					}
					$now = sprintf "%.0f", $self->{_max} - ($load[$self->{_idx} + 1] + $load[$self->{_idx} + 2])/2;
				} else {
					$now = $self->{_min};
				}
			}
	
			if ($now < ($self->{_min})) {
				$self->{_cur} = $self->{_min};
			} else {
				$self->{_cur} = $now;
			}
		} else {
			$self->{_cur} = 0;
		}
	}
}

sub limit_by_ram {
	my ($self, $file) = @_;
	my $filesize = 3157608038; # hg19 standard
	$filesize = (-s $file) if ((defined $file) && (-e $file) && (-s $file));
		
	my $memLimit = 0;
    if (-e '/proc/meminfo') {
		open my $RAMIN, '<', '/proc/meminfo';
		while (<$RAMIN>) {
			next unless ($_ =~ m/^Mem/);
			chomp $_; my @l = split ' ', $_;
			my $memLine = $l[1] * 1024;
			$memLimit = $memLine if ($memLimit < $memLine);
   		}
   		close $RAMIN;
		
	} elsif ($^O eq 'darwin') {
		$memLimit = `sysctl -n hw.memsize`; chomp $memLimit;
	} else {
		$memLimit = $filesize * $self->{_max};
	}
		
	my $ramLimit = ($memLimit * 0.90) / $filesize;	
	if ($ramLimit > 0) {
		if (($ramLimit > 2) && ($ramLimit < 3)) {
			$self->{_max} = 3;
			$self->{_min} = 2;
			$self->{_cur} = 2;
		} elsif ($self->{_max} > $ramLimit) {
			$self->{_max} = int $ramLimit;
			$self->{_min} = int ($ramLimit * 0.6);
			$self->{_cur} = $self->{_min};
		} 
	}
}

1;