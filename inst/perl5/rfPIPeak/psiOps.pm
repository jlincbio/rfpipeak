package rfPIPeak::psiOps;

use 5.016;
use strict;
use warnings;
use lib RFPIPEAK_DIR;
use PerlIO::gzip;
use File::Type;
use rfPIPeak::Constants qw(:all);
use rfPIPeak::natsort;
use Exporter 'import';
use Scalar::Util 'looks_like_number';
our @EXPORT_OK = qw(
	qfaidx which write_gene_list read_hash_bed write_hash_bed correlate_microarray
	randomString fetch_indels check_gzip reScaleReads quickname
	binChildren upperLimit mean var diffRepsToBed vcfToBed extractMotif
	letterExpand readSeq stringToMotif fastaToMotifBed motifBedFromArray);
our %EXPORT_TAGS = ('all' => \@EXPORT_OK);

my %alphabet_expansion = (
	'A' => 'A',
	'C' => 'C',
	'G' => 'G',
	'T' => 'T',
	'M' => '{A,C}',
	'R' => '{A,G}',
	'W' => '{A,T}',
	'S' => '{C,G}',
	'Y' => '{C,T}',
	'K' => '{G,T}',
	'V' => '{A,C,G}',
	'H' => '{A,C,T}',
	'D' => '{A,G,T}',
	'B' => '{C,G,T}',
	'N' => '{A,C,G,T}'
);

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
sub reScaleReads {
	my ($meth, $fact, $reads) = @_;  
	my @x = @{$reads};
	my $mean_x = mean(@x);
	my $min_x = min(@x);
	my $max_x = max(@x);
	my $scale = $max_x - $min_x;
	my @y = (EPS_ZERO) x (scalar @x);
	if ($scale > EPS) {
		# nonempty reads
		if ($meth eq 'unity') {
			$scale = $scale + EPS_ZERO;
			@y = map {(($_ + EPS_ZERO) - $min_x)/$scale} @x;
		} else {
			$mean_x = $mean_x + EPS_ZERO;
			@y = map {(($_ + EPS_ZERO) * $fact)/$mean_x} @x;
		}
	}	
	return @y;
}
sub binChildren {
	my ($array, $opCores) = @_;
	my $poolsize = scalar @{$array};
	my %bins;
	if ($opCores > 0) {
		my $binCount = int (0.99 + $poolsize/$opCores);
		foreach my $i (0..($opCores - 1)) {
			my %range;
			$range{'head'} = $binCount * $i;
			if ($i == ($opCores - 1)) {
				# last bin only goes to the last candidate
				$range{'tail'} = $poolsize - 1;
			} else {
				$range{'tail'} = $binCount * ($i + 1) - 1;
			}
			$bins{$i} = \%range;
		}
	} else {
		# no multithreading; one bin contains all candidate sites
		my %range = (
			'head' => 0,
			'tail' => $poolsize - 1);
		$bins{0} = \%range;
	}
	return %bins;
}
sub upperLimit {
	my $x = shift;
	(my $i = $x) =~ s/^.*\.//;
	my $d = (length $i) + 1;
	return $x + 5/(10 ** $d); 
}

sub mean {
	my @array = @_;
	my $count = scalar @array; my $sum = 0;
	if ($count >= 1) {
		foreach my $i (@array) {
			$sum = $sum + $i;
		}
		return ($sum/$count);
	}
	return NA;
}
sub var {
	my @array = @_;
	my $count = scalar @array;
	if (scalar @array > 1) {
		my $mean = mean(@array);
		my $ssq = 0;
		foreach my $y (@array) {
			$ssq += ($y - $mean) ** 2;
		}
		return ($ssq/($count - 1));
	}
	return 0;   
}
sub diffRepsToBed {
	my ($darray, $outputName) = @_; 
	my $index = 0; my @outputBed;
	
	foreach my $k (@{$darray}) {
		open my $INPUT_DREPS, '<', $k;
		while (<$INPUT_DREPS>) {
			if (m/^chr/) {
				chomp;
				my @myLine = split "\t", $_;
				$myLine[14]--;
				$index++;
				if ($myLine[16] > 0) {
					$myLine[16] = 10000 if ($myLine[16] > 10000); # change Inf here
					# chr start end feature_index fold_change q_value
					my $newLine = join "\t", $myLine[0], $myLine[14], $myLine[15], $index, $myLine[16], $myLine[18];
					push @outputBed, $newLine;
				}
			}
		}
		close $INPUT_DREPS;
	}
	open my $OUTPUT_BED, '>', $outputName or return 0;
	print $OUTPUT_BED "$_\n" for @outputBed;
	close $OUTPUT_BED;
	return 1;
}
sub vcfToBed {
	my ($inputName, $genomeFile, $motif, $lengthMotif, $refPath_bedtools, $path_work) = @_;
	$path_work = '.' unless (defined $path_work);
	my $strsuffix = randomString(11);
	my $tmp_outindels = "$path_work\/siteIndels\_$strsuffix\.bed";
	my $vcf_counts = 0;
	
	my (@bedLeadingStart, @bedLeadingFinal, @bedLaggingStart, @bedLaggingFinal);
	if ((-s $inputName) && (-e $inputName)) {
		my (@chrName, @basePos, @orgSeqChar, @mutSeqChar, @mutSeq);
		my $mode_input = check_gzip($inputName, '<');
		open my $INPUT_VCF, $mode_input, $inputName or die "Error: cannot open $inputName!\n";
		while (<$INPUT_VCF>){
			# split up truncated vcf table
			my @splitLine = split "\t", $_; chomp @splitLine;
			
			# detect and split comma-separated alternative alleles
			# $countMutSeq is the number of alt. alleles
			my @mutSeqAtPos = split ',', $splitLine[4];
			my $countMutSeq = scalar @mutSeqAtPos;
	
			# assign values into each respective array;
			# if more than one alt. allele is present, push multiple times
			push @mutSeq, @mutSeqAtPos;
			push @chrName, ($splitLine[0]) x $countMutSeq;
			push @basePos, ($splitLine[1]) x $countMutSeq;
			push @orgSeqChar, (length($splitLine[3])) x $countMutSeq;
			
			# looping through each alt allele and count number of characters
			foreach my $charMutSeq (@mutSeqAtPos) {
				push @mutSeqChar, length($charMutSeq);
			}
			
			push @bedLeadingStart, ($splitLine[1] - $lengthMotif - 1) x $countMutSeq;
			push @bedLeadingFinal, ($splitLine[1] - 1) x $countMutSeq;
			push @bedLaggingStart, ($splitLine[1] + length($splitLine[3]) - 1) x $countMutSeq;
			push @bedLaggingFinal, ($splitLine[1] + length($splitLine[3]) - 1 + $lengthMotif) x $countMutSeq; 		
		}   
		
		my $tmp_bedlead = "$path_work\/testbedLeading\_$strsuffix\.bed";
		my $tmp_bedlag  = "$path_work\/testbedLagging\_$strsuffix\.bed";
		open my $OUTPUT_LEADBED, '>', $tmp_bedlead or return 0;
		open my $OUTPUT_LAGBED,  '>', $tmp_bedlag  or return 0;
		foreach my $i (0 .. $#chrName) {
			print $OUTPUT_LEADBED "$chrName[$i]\t$bedLeadingStart[$i]\t$bedLeadingFinal[$i]\n";
			print $OUTPUT_LAGBED "$chrName[$i]\t$bedLaggingStart[$i]\t$bedLaggingFinal[$i]\n";
		}
		close $OUTPUT_LEADBED; close $OUTPUT_LAGBED;
		
		my @seqLead = `$refPath_bedtools getfasta -fi $genomeFile -bed $tmp_bedlead -tab`;
		my @seqLag  = `$refPath_bedtools getfasta -fi $genomeFile -bed $tmp_bedlag  -tab`;
		chomp @seqLead; chomp @seqLag; my @seqOutput;
		
		foreach my $j (0..$#mutSeq) {
			my @seq_head = split "\t", $seqLead[$j];
			my @seq_tail = split "\t", $seqLag[$j];
			my $seq_seg = join '', $seq_head[1], $mutSeq[$j], $seq_tail[$j];
			push @seqOutput, $seq_seg;
		}
		
		my $indelPosRef = motifBedFromArray(\@seqOutput, $motif);
		my (@indelID, @indelStart, @indelFinal, @indelMotif);

		foreach my $indel (@{$indelPosRef}) {
			my @indelLine = split "\t", $indel;
			push @indelID, $indelLine[0];
			push @indelStart, $indelLine[1];
			push @indelFinal, ($indelLine[2] - 1);
			push @indelMotif, $indelLine[3];
		}
		my (@motifStart, @motifFinal, @motifChrom);

		# build a map of coordinates extracted for mapping
		# orgRegion: coordinates of the original, from indel point
		# mutRegion: coordinates of the extracted area, flanked by leading and lagging strands,
		# with the center region being the length of indel, filled with coordinates from the original.
		foreach my $w (0 .. $#indelID) {
			# $i is the id corresponding to entry i in mutSeq
			my $i = $indelID[$w];
			my $endRegion = $basePos[$i] + $orgSeqChar[$i] - 1;
			my @orgRegion = $basePos[$i]..$endRegion;
			if ($mutSeqChar[$i] > $orgSeqChar[$i]) {
				push @orgRegion, (max(@orgRegion)) x ($mutSeqChar[$i] - $orgSeqChar[$i]);
			}
			my @midRegion = @orgRegion[0..($mutSeqChar[$i] - 1)];
			# brings BED starting coordinates back to 1-based abs. genomic coordinate 
			my @mutRegion = ((($bedLeadingStart[$i] + 1)..$bedLeadingFinal[$i]), @midRegion, (($bedLaggingStart[$i] + 1)..$bedLaggingFinal[$i]));
			$motifStart[$w] = $mutRegion[($indelStart[$w])] - 1; # -1 to adjust for bed coordinates
			$motifFinal[$w] = $mutRegion[$indelFinal[$w]];
			$motifChrom[$w] = $chrName[$i];
		}
		
		open my $OUTPUT_INDELS, '>', $tmp_outindels or die "I/O error creating $tmp_outindels!\n";
		foreach my $l (0 .. $#motifStart) {
			print $OUTPUT_INDELS "$motifChrom[$l]\t$motifStart[$l]\t$motifFinal[$l]\t$indelMotif[$l]\n";
		}
		close $OUTPUT_INDELS;
		
		# report indel ratios
		$vcf_counts = sprintf("%.5f", (scalar @motifStart)/(scalar @chrName)) if (scalar @chrName > 1);
	}
	return ($vcf_counts, $tmp_outindels);
}
sub letterExpand {
	my $motif = shift; my $output;
	my @m = split '', $motif;
	foreach my $i (@m) {
		$output .= $alphabet_expansion{$i};
	}
	return $output;
}
sub readSeq {
   my ($FH_SEQ, $fasta) = @_; my $file_not_empty = 0; 
   $fasta->{seq} = undef; # clear out previous sequence and put header in place
   $fasta->{header} = $fasta->{next_header} if ($fasta->{next_header});
   while (<$FH_SEQ>) {
      $file_not_empty = 1;
      next if /^\s*$/;  # skip blank lines
      chomp;    

      if (/^>/) { # fasta header line
	  	(my $h = $_) =~ s/^>//;
		if ($fasta->{header}) {
			$fasta->{next_header} = $h;
			return $fasta;
		} else { # first time through only
			$fasta->{header} = $h;
		}              
      } else {
		  s/\s+//;  # remove any white space
		  $fasta->{seq} .= $_;
      }         
   }    
   return $fasta if ($file_not_empty);
   $fasta->{header} = $fasta->{seq} = $fasta->{next_header} = undef; # cleanup
   return;       
}
sub stringToMotif {
	my $hashRef = shift; my %bankHash = %{$hashRef};
	my %expMotif;
	foreach my $inMotif (keys %bankHash) {
		my $fe_motif = $bankHash{$inMotif};
		$inMotif = uc $inMotif; my $rcMotif = reverse $inMotif;
		$rcMotif =~ tr/ACGTRYKMBVDH/TGCAYRMKVBHD/;
		$inMotif = letterExpand($inMotif);
		$rcMotif = letterExpand($rcMotif);
		my @motifs = (glob($inMotif), glob($rcMotif));
		foreach my $key (@motifs) {
			$expMotif{$key} = $fe_motif;
		}
	}
	return \%expMotif;
}
sub fastaToMotifBed {
	# modified to allow pre-saves and simply report counts
	my ($fasta_filename, $ref_motif, $output_motifBed, $allow_blockwrites, $only_counts) = @_;
	my (%seqbank, %motifBank, @array_motifKey);
	if (ref($ref_motif) eq 'ARRAY') {
		@array_motifKey = @{$ref_motif};
	} elsif (ref($ref_motif) eq 'HASH'){
		@array_motifKey = keys %{$ref_motif};
	} else {
		die "Error: improper motif entry detected!\n";
	}
	
	# $allow_blockwrites: integer indicate how many entries to save	
	my $BED_TEMP; my $lineCount = 0;
	if (defined $allow_blockwrites) {
		my $output_tempBed = '.'.randomString(12).'.bed';
		open $BED_TEMP, '>', $output_tempBed;
	}
	
	# $only_counts: just add number without preparing bed
	my $mode_input = check_gzip($fasta_filename, '<');
	open my $FASTA_INPUT, $mode_input, $fasta_filename or die "Error: cannot open $fasta_filename!\n";
	while (readSeq($FASTA_INPUT, \%seqbank)) {
		foreach my $key (@array_motifKey) {
			if (defined $allow_blockwrites) {
				if ($lineCount >= $allow_blockwrites) {
					print $BED_TEMP "$_\n" for keys %motifBank;
					$lineCount = 0;
				}
			}
			(my $coordinate = $seqbank{header}) =~ s/\:/\-/g;
			my @header = split /\-/, $coordinate;
			# process header; proper format should be chrN:n1-n2, otherwise reset
			$header[0] = $seqbank{header} unless (scalar @header == 3);
			$header[1] = 0 unless ((defined $header[1]) && looks_like_number($header[1]));
			my $sequence = uc($seqbank{seq});
			my $offset = 0; my @keyBed;
			my $pos = index($sequence, $key, $offset);
			while($pos != -1) {
				my $l = sprintf "%s\t%u\t%u\t%s", $header[0], $header[1] + $pos, $header[1] + $pos + length($key), $key;
				$motifBank{$l}++; $lineCount++;
				$offset = $pos + 1; $pos = index($sequence, $key, $offset);
			}			
		}
	}
	close $FASTA_INPUT;
	
	my @motifBed = natsort(keys %motifBank);
	if (defined $output_motifBed) {
		open my $BED_OUTPUT, '>', $output_motifBed or die "Error: cannot open $output_motifBed\n";
		print $BED_OUTPUT "$_\n" for @motifBed;
		return 1;
	} else {
		return \@motifBed;
	}
}
sub motifBedFromArray {
	my ($ref_array, $ref_motif) = @_;
	my @motifBed; my $i = 0;
	
	foreach my $seq (@{$ref_array}) {
		foreach my $key (keys %{$ref_motif}) {
			my $sequence = uc($seq);
			my $offset = 0; my @keyBed;
			my $pos = index($sequence, $key, $offset);
			while($pos != -1) {
				my $l = sprintf "%s\t%u\t%u\t%s", $i, $pos, $pos + length($key), $key;
				push @motifBed, $l;
				$offset = $pos + 1; $pos = index($sequence, $key, $offset);
			}
		}
		$i++;
	}
	@motifBed = natsort @motifBed;
	return \@motifBed;
}
sub fetch_indels {
	my ($vcfInput, $vcfOutput) = @_; my @vcf_output;
	my $mode_input = check_gzip($vcfInput, '<');
	open my $INPUT_VCF, $mode_input, $vcfInput or die "Error: cannot open $vcfInput!\n";
	while (<$INPUT_VCF>){
		next if ($_ =~ m/^\#/);
		next unless ($_ =~ m/\tINDEL/);
		chomp $_; my @i = split "\t", $_;
		my $l = sprintf "%s\t%u\t%s\t%s\t%s", $i[0], $i[1], $i[2], uc($i[3]), uc($i[4]);
		push @vcf_output, $l;
	}
	close $INPUT_VCF;
	open my $OUTPUT_VCF, '>', $vcfOutput or return 0;
	print $OUTPUT_VCF "$_\n" for @vcf_output;
	close $OUTPUT_VCF;
	return 1;
}
sub check_gzip {
	my ($file, $mode) = @_;
	my $test = File::Type->new->checktype_filename($file);
	return "$mode\:gzip" if ($test =~ m/gzip/);
	return $mode;
}
sub extractMotif {
	my $file_input = shift; my (%motifs, @lengthMotif);
	my $mode_input = check_gzip($file_input, '<');
	open my $INPUT_MOTIF, $mode_input, $file_input or die "I/O error: $file_input!\n";
	while (<$INPUT_MOTIF>) {
		chomp $_; next if ($_ =~ m/^\#/);
		die "Error: $file_input not properly formatted.\n" unless ($_ =~ m/^[AaCcGgTt]/);
		my @l = split "\t", $_;
		$motifs{$l[0]} = $l[1];
		push @lengthMotif, length $l[0];
	}
	close $INPUT_MOTIF;
	my $motifLength = min(@lengthMotif);
	unlink $file_input if ($file_input ne $file_input);
	return ($motifLength, \%motifs);
}
sub randomString {
	my $n = shift;
	my @ascii = (48..57, 65..90, 97..122); # ASCII bank
	my $string; $string .= chr($ascii[rand @ascii]) for 1..$n;
	return $string;
}
sub read_hash_bed {
	my ($filename, $sep, $col, $check_col, $check_exp, $check_cond, $scr_reset, $id_col) = @_;
	$sep = "\t" unless (defined $sep);
	my (@table, %output); my $mode_input = "<";
	$mode_input = check_gzip($filename, '<');
	open my $INPUT_TABLE, $mode_input, $filename or die "I/O error: $filename!\n";
	while (<$INPUT_TABLE>) {
		chomp;
		my @row = split $sep, $_;
		if (defined $check_col) {
			if ($check_exp eq '<') {
				next if ($row[$check_col] < $check_cond);
			} else {
				next if ($row[$check_col] > $check_cond);
			}
		}
		$col = $#row unless (defined $col);
		$row[4] = $scr_reset if (defined $scr_reset);
		@row = @row[0..$col];
		push @table, \@row;
	}
	close $INPUT_TABLE; @table = uniq(@table);
	foreach my $i (0..$#table) {
		my $key = $i;
		if (defined $id_col) {
			my @row = @{$table[$i]};
			$key = $row[$id_col];
		}
		$output{$key} = $table[$i];
	}
	return \%output;
}
sub write_hash_bed {
	my ($filename, $bed) = @_;
	my @indices = sort {$a <=> $b} keys %{$bed};
	open my $OUTPUT_TABLE, '>', $filename or return 0;
	foreach my $i (@indices) {
		my @row = @{${$bed}{$i}};
		local $" = "\t";
		print $OUTPUT_TABLE "@row\n";
	}
	close $OUTPUT_TABLE or return 0;
	return 1;
}
sub correlate_microarray {
	my ($microarray, $kegg_list, $pip_sites) = @_;
	my @output; my %exp_array;
	my (@geneKegg, %geneSort);
	foreach my $k (@{$pip_sites}) {
		next if ($k eq 'Intergenic');
		$k =~ s/Promoter_//g;
		my @l = split '/', $k;
		foreach my $g (@l) {
			$geneSort{$g}++;
		}
	}
	my @geneList = keys %geneSort; undef %geneSort;
	if (defined $kegg_list) {
		# generate list of pip-bound genes within a supplied pathway
		open my $INPUT_GENELIST, '<', $kegg_list or die "I/O error: $!\n";
		while (<$INPUT_GENELIST>) {
			chomp $_; push @geneKegg, $_;
		}
		close $INPUT_GENELIST;
		printf "%u entries in supplied pathway gene list processed.\n", scalar @geneKegg;
	} 
	my (%arrayFC, %arrayFreq, %arrayMeanFC);
	open my $INPUT_ARRAY, '<', $microarray or die "I/O error: $!\n";
	my $header = <$INPUT_ARRAY>;
	while (<$INPUT_ARRAY>) {
		chomp; my @entry = split "\t", $_;
		$arrayFC{$entry[3]} += $entry[5];
		$arrayFreq{$entry[3]}++;
	}
	close $INPUT_ARRAY;
	my @geneArray = keys %arrayFC;
	my ($pipBound, $pipUnbound) = divide_array(\@geneArray, \@geneList);	
	my ($bound_keggIn, $bound_keggOut);
	
	foreach my $k (keys %arrayFC) {
		$arrayMeanFC{$k} = $arrayFC{$k}/$arrayFreq{$k};
	}
	
	my (@fc_bound_keggIn, @fc_bound_keggOut, @fc_bound, @fc_unbound);
	if (@geneArray) {
		foreach my $k (@{$pipBound}) {
			push @fc_bound, $arrayMeanFC{$k} if (defined $arrayMeanFC{$k}); 
		}
		foreach my $k (@{$pipUnbound}) {
			push @fc_unbound, $arrayMeanFC{$k} if (defined $arrayMeanFC{$k}); 
		}
		my $t_sites = new Statistics::TTest;
		$t_sites->load_data(\@fc_bound,\@fc_unbound);  
		push @output, sprintf("Mean FC of PIP-bound genes: %.5f", $t_sites->{s1}->{mean});
		push @output, sprintf("Mean FC of  unbound  genes: %.5f", $t_sites->{s2}->{mean});
		push @output, sprintf("Variance in FC of PIP-bound genes: %.5f", $t_sites->{s1}->{variance});
		push @output, sprintf("Variance in FC of  unbound  genes: %.5f", $t_sites->{s2}->{variance});
		push @output, sprintf("Num. of   bound genes with FC data: %u", scalar @fc_bound);
		push @output, sprintf("Num. of unbound genes with FC data: %u", scalar @fc_unbound);
		push @output, sprintf("Significance of differences in FC (t-test, two-tailed p): %.5f", $t_sites->{t_prob});
		push @output, sprintf("F-statistic of differences in FC: %.5f", $t_sites->{f_statistic});
	}
	
	if (@geneKegg) {
		($bound_keggIn, $bound_keggOut) = divide_array(\@geneList, \@geneKegg);
		foreach my $k (@{$bound_keggIn}) {
			push @fc_bound_keggIn, $arrayMeanFC{$k} if (defined $arrayMeanFC{$k}); 
		}
		foreach my $k (@{$bound_keggOut}) {
			push @fc_bound_keggOut, $arrayMeanFC{$k} if (defined $arrayMeanFC{$k}); 
		}
		if (@fc_bound_keggIn && @fc_bound_keggOut) {
			my $t_pathway = new Statistics::TTest;
			$t_pathway->load_data(\@fc_bound_keggIn,\@fc_bound_keggOut);
			push @output, sprintf("Mean FC of bound genes within pathway: %.5f", $t_pathway->{s1}->{mean});
			push @output, sprintf("Mean FC of bound genes beyond pathway: %.5f", $t_pathway->{s2}->{mean});
			push @output, sprintf("Variance in FC of bound genes within pathway: %.5f", $t_pathway->{s1}->{variance});
			push @output, sprintf("Variance in FC of bound genes beyond pathway: %.5f", $t_pathway->{s2}->{variance});
			push @output, sprintf("Num. of bound genes within pathway: %u", scalar @fc_bound_keggIn);
			push @output, sprintf("Num. of bound genes beyond pathway: %u", scalar @fc_bound_keggOut);
			push @output, sprintf("Significance of differences in FC (t-test, two-tailed p): %.5f", $t_pathway->{t_prob});
			push @output, sprintf("F-statistic of differences in FC: %.5f", $t_pathway->{f_statistic});
		} else {
			$bound_keggIn = undef;
		}
	}
	return (\@output, \@geneList, $bound_keggIn, \%arrayMeanFC);
}
sub divide_array {
	my ($x, $bank) = @_;
	my %i = map {$_ => 1} @{$bank};
	my (@match, @nomatch);
	foreach my $q (@{$x}) {
		if (exists $i{$q}) {
			push @match, $q;
		} else {
			push @nomatch, $q;
		}
	}
	return (\@match, \@nomatch);
}
sub write_gene_list {
	my ($list, $file) = @_;
	open my $OUTPUT_COMPGENE, '>', $file  or die "I/O error: $!\n";
	print $OUTPUT_COMPGENE "$_\n" for @{$list};
	close $OUTPUT_COMPGENE and return 1;
	return 0;
}
sub qfaidx {
	my $fasta = shift; my $charcount = 0;
	my $output = join '.', $fasta, 'fai';
	if (-e $output) {
		print "Skipping: $output already exists!\n";
		return $output;
	}
	print "Indexing $fasta...\n";
	my (@orders, %cLength, %cOffset, %cBases, %cWidth);
	open my $INPUT, '<', $fasta or die "Error: Can't open $fasta!\n";
	my ($ckey, $lkey, $nl1, $nl2);
	while (<$INPUT>) {
		my $line = $_;
		my $lenLine = length $line;
		my $base = $line; chomp $base;
		my $lenBase = length $base;
		$charcount = $charcount + $lenLine;
		if ($line =~ m/^\>/) {
			# header line; make key
			(my $header = $line) =~ s/^\>//;
			chomp $header;
			my @s = split ' ', $header;
			$ckey = shift @s;
			push @orders, $ckey;
			$cOffset{$ckey} = $charcount;
			$lkey = 1;
			$nl1 = 0;
			$nl2 = 0;
		} else {
			#print "Line: $base\n";
			if ($lkey > 2) {
				#print "At line $lkey for $ckey\n";
				# check length in previous 2 lines
				if (($lenBase > 0) && ($nl1 != $nl2)) {
					die "Mismatch bases!\n";
				}
			}
		
			# sequence read, count bases
			if (exists $cLength{$ckey}) {
				$cLength{$ckey} = $cLength{$ckey} + $lenBase;
				if ($lenBase > 0) {
					# not empty; store measurements of previous 2 lines
					$nl1 = $nl2;
				}
			} else {
				# initialize fasta statistics
				$cWidth{$ckey} = $lenLine;
				$cLength{$ckey} = $lenBase;
				$cBases{$ckey} = $lenBase;
				#$pBases{$ckey} = $base;
			}
			$nl2 = $lenBase;
			$lkey++;
		}
	}
	close $INPUT;
	open my $FAIDX, '>', $output or die "Error: Can't write index file!\n";
	foreach my $k (@orders) {
		print $FAIDX "$k\t$cLength{$k}\t$cOffset{$k}\t$cBases{$k}\t$cWidth{$k}\n";
	}
	close $FAIDX;
	return $output;
}
sub quickname {
	my ($prefix, $suffix, $fine) = @_;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	$year = ($year % 100);
	$mon = sprintf "%02u", $mon + 1;
	my $day = sprintf "%02u", $mday;
	my $strtime = join '', $mon, $day, $year;
	if (defined $fine) {
		# include hours and minutes
		$strtime = $strtime.$hour.$min;
	}
	my $name = $prefix.'_'.$strtime.'.'.$suffix;
	return $name;
}
## NOT EXPORTED
sub uniq {
  my %x;
  return grep {!$x{$_}++} @_;
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
1;