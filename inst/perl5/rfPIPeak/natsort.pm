package rfPIPeak::natsort;

use 5.016;
use strict;
use warnings;
use lib RFPIPEAK_DIR;
use Exporter 'import';
our @EXPORT = qw(natsort);

## rfPIPeak::natsort
## Version sorting via the alphanum algorithm
## Reference: http://www.DaveKoelle.com

## Note: this algorithm will give different results than GNU sort
##.      (invoked by sort -V) if the input begins with non-alphanumeric
##		 letters, e.g. literal ^, >, # characters, in which GNU sort
##		 does not sort those ahead of alphanumerics despite their
##		 ASCII codes being numerically smaller.

# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

sub natsort {
	my @sorted;
	if (@_) {
		if ((scalar @_ == 1) && (ref $_[0] eq 'ARRAY')) {
			# array reference provided;
			my $array = shift;
			@sorted = sort {natsort_cmpfun($a,$b)} @{$array};
			return \@sorted;
		} else {
			# assume array passed to natsort
			@sorted = sort {natsort_cmpfun($a,$b)} @_;
		}
	}
	return @sorted;
}

sub natsort_cmpfun {
	# split strings into chunks
	my @a = natsort_split($_[0]);
	my @b = natsort_split($_[1]);
	
	while (@a && @b) {
		my $a_chunk = shift @a;
		my $b_chunk = shift @b;
		# comparison test: if $a and $b numeric, treat as so;
		# otherwise compare as strings, return result if unequal
		my $test =
			(($a_chunk =~ /\d/) && ($b_chunk =~ /\d/)) ? 
			$a_chunk <=> $b_chunk :
			$a_chunk cmp $b_chunk ;  
		return $test if ($test != 0);
	}
	return @a <=> @b; # return longer string.
}

# splitting function for numeric/non-numeric transitions
sub natsort_split {
	# split conditions:
	# zero width, digit preceded by non-digit or otherwise
	my @chunks = split m{
		(?=
		(?<=\D)\d |
		(?<=\d)\D)
	}x, $_[0];
	return @chunks;
}
1;