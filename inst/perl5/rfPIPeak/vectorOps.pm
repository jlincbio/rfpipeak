package rfPIPeak::vectorOps;

use 5.016;
use strict;
use warnings;
use lib RFPIPEAK_DIR;
use Exporter 'import';
use Scalar::Util qw(looks_like_number);
use PerlIO::gzip;
use rfPIPeak::Constants qw(:all);
use rfPIPeak::psiOps 'check_gzip';
our @EXPORT_OK = qw(read_table write_table seq basename nona uniq log2 median var mean sum min max);
our @EXPORT_MATH = qw(log2 median var mean sum min max);
our %EXPORT_TAGS = (
	'all' => \@EXPORT_OK,
	'math' => \@EXPORT_MATH);

## Simple Perl implementations of R-like table/vector operations
## Note: headers are treated as entries in a table; as such dimensions can be tricky

## Syntax:
#  read_table(FILENAME, SEPARATOR):
# 		read text file as 2D array
#		read.table(FILENAME, sep = SEPARATOR, as.is = TRUE, header = FALSE)
#  write_table(FILENAME, TABLE, HEADER): 
#  		write table as tab-delimited text file
#		write.table(TABLE, file = FILENAME, quote = FALSE, col.names = FALSE, row.names = FALSE, sep = "\t")
## Other implementations
#  basename(FILENAME)
#		prints out only the filename in a full path.
#  seq(FROM, TO, LENGTH.OUT, ROUNDED)
#		generates an integer array of LENGTH.OUT elements ranging FROM..TO
#		caveat: ROUNDED is analogous to "step size", so for diffReps where
#				a minimum step size of 10 is required, set ROUNDED to 10.
#  nona(X)
#		X[!is.na(X)]
#  shuffle_vector(\@ARRAY, N):
# 		Generate an array of N elements from ARRAY; based on Fisher-Yates sampling

sub read_table {
	my ($filename, $sep, $ext_col) = @_;
	$sep = "\t" unless (defined $sep);
	my (@table, @ext); my $i = 0; my $mode_input = "<";
	$mode_input = check_gzip($filename, '<');
	open my $INPUT_TABLE, $mode_input, $filename or return 0;
	while (<$INPUT_TABLE>) {
		chomp;
		my @row = split $sep, $_;
		push @ext, $row[$ext_col] if (defined $ext_col);
		foreach my $j (0..$#row) {
			$table[$i][$j] = $row[$j];
		}
		$i++;
	}
	close $INPUT_TABLE or return 0;
	return (\@table, \@ext) if (defined $ext_col); 
	return @table;
}
sub write_table {
	my ($filename, $matrix, $header) = @_;
	my @table = @{$matrix}; undef $matrix;
	my $n = $#table;
	open my $OUTPUT_TABLE, '>', $filename or return 0;
	if (defined $header) {
		my @headerLine = @{$header};
		my $printHeader = join "\t", @headerLine;
		print $OUTPUT_TABLE "$printHeader\n";
	}
	
	my @r; my $rn = 0; # temp row
	foreach my $i (0..$n) {
		if (defined $table[$i]) {
			# update rn if different to prevent dimensional errors
			@r = @{$table[$i]};
			$rn = $#r unless ($rn == $#r);
			foreach my $j (0..$#r) {
				$r[$j] = NA unless (defined $r[$j]);
			}
		} else {
			# uninitialized row; print rn NA elements
			if (defined $rn) {
				@r = (NA) x $rn;
			} else {
				@r = (' ');
			}
		}
		local $" = "\t";
		print $OUTPUT_TABLE "@r\n";
	}
	close $OUTPUT_TABLE or return 0;
	return 1;
}

sub seq {
	my ($from, $to, $n, $min) = (@_);
	$min = 1 unless (defined $min);
	my $h = $min * int ((($to - $from) / ($n - 1))/$min);
	
	my @s; my $j = $from; push @s, $j;
	while ($j < $to) {
		$j = $j + $h;
		if ($j > $to) {
			push @s, $to;
		} else {
			push @s, $j;
		}
	}
	return @s;
}
sub basename {
	my $f = shift;
	$f =~ s/\\/\//g;
	my @names = split '/', $f;
	my $b = pop @names;
	return $b;  
}
sub nona {
	my @array = @_;
	my @array_na = grep !/NA/, @array;
	return @array_na;
}
sub min {
	my @y = @_; my $y_min = $y[0];
	foreach my $i (@y) {
		if ($i < $y_min) {
			$y_min = $i;
		}
	}
	return $y_min;
}
sub max {
	my @y = @_; my $y_max = $y[0];
	foreach my $i (@y) {
		if ($i > $y_max) {
			$y_max = $i;
		}
	}
	return $y_max;
}
sub uniq {
  my %x;
  return grep {!$x{$_}++} @_;
}
sub sum {
	my @x = @_; my $s = 0;
	if (@x) {
		foreach my $i (@x) {
			$s = $s + $i;
		}
		return $s;
	}
	return undef;
}
sub mean {
	my @x = @_; my $s = 0; my $n = 0;
	if (@x) {
		foreach my $i (@x) {
			$s = $s + $i;
			$n++;
		}
		return $s/$n;
	}
	return undef;
}
sub var {
	my @x = @_; my $m;
	my $s = 0; my $n = 0;
	if (@x) {
		$m = mean(@x);
		foreach my $i (@x) {
			$s = $s + ($i - $m)**2;
			$n++;
		}
		return ($m / ($n - 1));
	}
	return undef;
}
sub median {
	my @x = @_;
	if (@x) {
		my @sorted = sort {$a <=> $b} @x;
		if (@sorted % 2 == 1) {
			return $sorted[int(@sorted/2)];
		}
		return ($sorted[int(@sorted/2)]+$sorted[int(@sorted/2)-1])/2;
	}
	return undef;
}
sub log2 {
	my $n = shift;
	if ($n == 0) {
		return EPS_LOGMIN;
	}
	return log($n)/log(2);
}

1;