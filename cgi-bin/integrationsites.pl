#!/usr/bin/perl

use strict;
use warnings;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Email::Simple;
use Email::Simple::Creator; # For creating the email

my $id              = shift;
my $emailAddr       = shift;
my $remote_addr     = shift; 
my $uploadQueryFile = shift;
my $outFile         = shift;
my $hgDb            = shift;
my $hivDb           = shift;
my $gffFile         = shift;
my $uploadDir       = shift;
my $localDir        = shift;
my $trim            = shift;
my $ltr             = shift;
my $blast             = shift;
my $downloadfile    = $uploadDir.$id.'_download.txt';
my $logFile = $uploadDir.$id.'.log';

open LOG, ">", $logFile or die "couldn't open $logFile: $!\n";
print LOG "id: $id\n";
print LOG "email: $emailAddr\n";
print LOG "remote_addr: $remote_addr\n";
print LOG "uploadQueryFile: $uploadQueryFile\n";
print LOG "outFile: $outFile\n";
print LOG "blast algorithm: $blast\n";
print LOG "hgDb: $hgDb\n";
print LOG "hivDb: $hivDb\n";
print LOG "gffFile: $gffFile\n";
print LOG "uploadDir: $uploadDir\n";
print LOG "trim: $trim\n";

my (%chromoRegion, %chromoGeneStart, %chromoGeneEnd, %chromoGeneDir, %chromoGeneDesc, %chromoGeneId);
open GFF, $gffFile or die "couldn't open $gffFile: $!\n";
while (my $line = <GFF>) {
	chomp $line;
	next if $line =~ /^#/;
	my @fields = split /\t/, $line;
	if ($fields[2] eq "region") {
		if ($fields[8] =~ /;chromosome=(.*?);/) {
			$chromoRegion{$fields[0]} = $1;
		}
	}elsif ($fields[2] eq "gene") {
		my $gene = my $desc = '';
		my $geneId = 0;
		my $attribute = $fields[8];
		if ($attribute =~ /;Name=(.*?);/) {
			$gene = $1;
		}
		if ($attribute =~ /;description=(.*?);/) {
			$desc = $1;
			$desc =~ s/\%2C/,/g;
		}
		if ($attribute =~ /GeneID:(\d+)/) {
			$geneId = $1;
		}
		$chromoGeneStart{$fields[0]}{$gene} = $fields[3];
		$chromoGeneEnd{$fields[0]}{$gene} = $fields[4];
		$chromoGeneDir{$fields[0]}{$gene} = $fields[6];
		$chromoGeneDesc{$fields[0]}{$gene} = $desc;
		$chromoGeneId{$fields[0]}{$gene} = $geneId;		
	}
}
close GFF;
my $count = my $humanCount = my $hivCount = my $noMatchCount = 0;
my $cutoff = 0.9;
my $seqname = '';
my (@seqnames, %nameseq);
open STAT, ">", $outFile or die "couldn't open $outFile: $!\n";
open DWLD, ">", $downloadfile or die "couldn't open $downloadfile: $!\n";
print STAT "id\ttag\tchromo\trefid\tloc\trelease\tWRT chr\tWRT gene\tgene\tfull name\tdescription\thttp\tsequence\tqStart\tidentity\tgaps\tltr\tnote\n";
print DWLD "id\ttag\tchromo\trefid\tloc\trelease\tWRT chr\tWRT gene\tgene\tfull name\tdescription\thttp\tsequence\tqStart\tidentity\tgaps\tltr\tnote\n";
open IN, "<", $uploadQueryFile or die "couldn't open $uploadQueryFile: $!\n";
while (<IN>) {
	chomp $_;
	if ($_ =~ /^>(.*)$/) {
		$seqname = $1;
		push @seqnames, $seqname;
		++$count;
	}else {
		$nameseq{$seqname} .= $_;
	}	
}
close IN;
foreach my $name (@seqnames) {
	my $seq = $nameseq{$name};
	my $trimmsg = '';
	print LOG "*** Processing $name ***\n";
	if ($trim) {
		my $ltrseq = "";
		if ($ltr == 3) {
			$ltrseq = "TCTCTAGCA";
		}else {
			$ltrseq = "GCCCTTCCA";
		}
		my $idx = index($seq, $ltrseq);
		if ($idx == -1) {
			$trimmsg = "couldn't find LTR sequence $ltrseq";
		}else {
			my $start = $idx + 9;
			$seq = substr($seq, $start);
			$nameseq{$name} = $seq;
		}
	}
	my $startNs = 0;
	my @nts = split //, $seq;
	if ($seq =~ /^N/) {
		for (my $i = 0; $i < scalar @nts; $i++) {
			if ($nts[$i] ne "N") {
				$startNs = $i;
				last;
			}
		}
	}
	if ($startNs > 10) {
		print STAT "$name\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tleading Ns are greater than 10bp\n";
		print DWLD "$name\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tleading Ns are greater than 10bp\n";
		next;
	}
	if (length $seq < 20) {
		print STAT "$name\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tQuery sequence is less than 20bp, blastn will not been performed\n";
		print DWLD "$name\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tQuery sequence is less than 20bp, blastn will not been performed\n";
		next;
	}
	# run blastn against human_genomic
	my $standardname = $name;
	$standardname =~ s/\W/_/g;
	my $blastpath = "/usr/local/apache2/htdocs/ncbi-blast/bin/blastn";
	my $tmpFile = $uploadDir.$standardname.".fasta";
	my $xmlFile = $uploadDir.$standardname."_hg.xml";
	open TMP, ">", $tmpFile or die "couldn't open $!\n";	
	print TMP ">$name\n$seq\n";
	close TMP;	
	system($blastpath, "-task", $blast, "-db", $hgDb, "-query", $tmpFile, "-out", $xmlFile, "-outfmt", 5, "-max_target_seqs", 10);
	my @genomeInfo = parseGenomeXML($xmlFile, $ltr, $hgDb);
	unlink($xmlFile);
	if (scalar @genomeInfo == 0) {
		# run blastn against HIV-1 genome (HXB2)
		my $hivXmlFile = $uploadDir.$standardname."_hxb2.xml";
		system($blastpath, "-task", "blastn", "-db", $hivDb, "-query", $tmpFile, "-out", $hivXmlFile, "-outfmt", 5, "-max_target_seqs", 10);
		# parse blastn xml file to get info
		my @hivInfo = parseHIVXML($hivXmlFile);
		unlink($hivXmlFile);
		unlink($tmpFile);
		if (scalar @hivInfo > 4) {
			# write result to output file		
			my $tag = $hivInfo[7]."-".$hivInfo[8];
			my $alignSeqLen = $hivInfo[6] - $hivInfo[5] + 1;
			print STAT $name,"\t",$tag,"\t\t$hivInfo[4]\t",$hivInfo[7],"\t","\t";
			print STAT $hivInfo[9],"\t\tHIV\t\t\t\t",$nameseq{$name},"\t",$hivInfo[5],"\t";
			print STAT $hivInfo[10],"/",$alignSeqLen,"(",$hivInfo[3],")","\t";
			print STAT $hivInfo[11],"/",$alignSeqLen,"(",$hivInfo[3],")","\t";
			print STAT "$ltr\tMatch to HXB2";
			print DWLD $name,"\t",$tag,"\t\t$hivInfo[4]\t",$hivInfo[7],"\t","\t";
			print DWLD $hivInfo[9],"\t\tHIV\t\t\t\t",$nameseq{$name},"\t",$hivInfo[5],"\t";
			print DWLD $hivInfo[10],"/",$alignSeqLen,"(",$hivInfo[3],")","\t";
			print DWLD $hivInfo[11],"/",$alignSeqLen,"(",$hivInfo[3],")","\t";
			print DWLD "$ltr\tMatch to HXB2";
			if ($trimmsg) {
				print STAT " ($trimmsg)";
				print DWLD " ($trimmsg)";
			}
			print STAT "\n";
			print DWLD "\n";
			++$hivCount;
			next;
		}else {
			print STAT "$name\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tNo significant match\n";
			print DWLD "$name\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tNo significant match\n";
			++$noMatchCount;
			next;
		}
	} 
	unlink($tmpFile);
	# map gene
	foreach my $info (@genomeInfo) {
		my $chromo = $info->[1];
		my $chrinfo = $chromoRegion{$chromo};
		my $hStart = $info->[6];
		print LOG "chrinfo: $chrinfo\nassemblyinfo: $info->[2]\nassembly: $info->[3]\n";
		print LOG "qfrom: $info->[4]\nqto: $info->[5]\nhfrom: $info->[6]\nhto: $info->[7]\n";
		print LOG "hframe: $info->[8]\nidentity: $info->[9]\ngap: $info->[10]\n";
		my @geneNames = ();
		foreach my $gene (keys %{$chromoGeneStart{$chromo}}) {
			if ($hStart >= $chromoGeneStart{$chromo}{$gene} && $hStart <= $chromoGeneEnd{$chromo}{$gene}) {
				push @geneNames, $gene;
			}
		}
		# write result to output file		
		my $tag = $chrinfo.'-'.$chromo."-".$info->[6];
		my $alignSeqLen = $info->[5] - $info->[4] + 1;	
		if (@geneNames) {
			foreach my $gene (@geneNames) {
				my $desc = $chromoGeneDesc{$chromo}{$gene};
				my $dir = $chromoGeneDir{$chromo}{$gene};
				my $geneId = $chromoGeneId{$chromo}{$gene};
				if ($info->[8] eq "F") {
					if ($dir eq "+") {
						$dir = "F";
					}elsif ($dir eq "-") {
						$dir = "R";
					}
				}elsif ($info->[8] eq "R") {
					if ($dir eq "+") {
						$dir = "R";
					}elsif ($dir eq "-") {
						$dir = "F";
					}
				}
				print STAT $name,"\t",$tag,"\t",$chrinfo,"\t",$chromo,"\t",$info->[6],"\t",$info->[3],"\t",$info->[8],"\t";
				print STAT $dir,"\t",$gene,"\t",$desc,"\t\t";
				print DWLD $name,"\t",$tag,"\t",$chrinfo,"\t",$chromo,"\t",$info->[6],"\t",$info->[3],"\t",$info->[8],"\t";
				print DWLD $dir,"\t",$gene,"\t",$desc,"\t\t";
				if ($geneId) {
					print STAT "https://www.ncbi.nlm.nih.gov/gene/$geneId";
					print DWLD "https://www.ncbi.nlm.nih.gov/gene/$geneId";
				}
				print STAT "\t",$nameseq{$name},"\t",$info->[4],"\t",$info->[9],"/",$alignSeqLen,"(",$info->[0],")","\t";
				print STAT $info->[10],"/",$alignSeqLen,"(",$info->[0],")","\t",$ltr,"\t",$info->[2];
				print DWLD "\t",$nameseq{$name},"\t",$info->[4],"\t",$info->[9],"/",$alignSeqLen,"(",$info->[0],")","\t";
				print DWLD $info->[10],"/",$alignSeqLen,"(",$info->[0],")","\t",$ltr,"\t",$info->[2];
				if ($trimmsg) {
					print STAT " ($trimmsg)";
					print DWLD " ($trimmsg)";
				}
				print STAT "\n";
				print DWLD "\n";	
			}
		}else {	
			my $upDist = my $downDist = my $upGeneid = my $downGeneid = 0;
			my $upGene = my $downGene = 'N/A';
			foreach my $gene (sort {$chromoGeneEnd{$chromo}{$b} <=> $chromoGeneEnd{$chromo}{$a}} keys %{$chromoGeneEnd{$chromo}}) {
				if ($info->[6] > $chromoGeneEnd{$chromo}{$gene}) {
					$upDist = ($info->[6] - $chromoGeneEnd{$chromo}{$gene}) / 1000;
					$upGene = $gene;
					$upGeneid = $chromoGeneId{$chromo}{$upGene};
					last;
				}
			}
			foreach my $gene (sort {$chromoGeneStart{$chromo}{$a} <=> $chromoGeneStart{$chromo}{$b}} keys %{$chromoGeneStart{$chromo}}) {
				if ($chromoGeneStart{$chromo}{$gene} > $info->[6]) {
					$downDist = ($chromoGeneStart{$chromo}{$gene} - $info->[6]) / 1000;
					$downGene = $gene;
					$downGeneid = $chromoGeneId{$chromo}{$downGene};
					last;
				}
			}
		
			print STAT $name,"\t",$tag,"\t",$chrinfo,"\t",$chromo,"\t",$info->[6],"\t",$info->[3],"\t",$info->[8],"\t";
			print STAT "\tUpstream: ";
			print DWLD $name,"\t",$tag,"\t",$chrinfo,"\t",$chromo,"\t",$info->[6],"\t",$info->[3],"\t",$info->[8],"\t";
			print DWLD "\tUpstream: ";
			if ($upGeneid) {
				print STAT "<a href=https://www.ncbi.nlm.nih.gov/gene/$upGeneid target=_blank>$upGene</a>";
				print DWLD "$upGene";
			}else {
				print STAT $upGene;
				print DWLD $upGene;
			}
			print STAT " ($upDist kb); Downstream: ";
			print DWLD " ($upDist kb); Downstream: ";
			if ($downGeneid) {
				print STAT "<a href=https://www.ncbi.nlm.nih.gov/gene/$downGeneid target=_blank>$downGene</a>";
				print DWLD "$downGene";
			}else {
				print STAT $downGene;
				print DWLD $downGene;
			}
			print STAT " ($downDist kb)\t\t\t";
			print STAT "\t",$nameseq{$name},"\t",$info->[4],"\t",$info->[9],"/",$alignSeqLen,"(",$info->[0],")","\t";
			print STAT $info->[10],"/",$alignSeqLen,"(",$info->[0],")","\t",$ltr,"\t",$info->[2];
			print DWLD " ($downDist kb)\t\t\t";
			print DWLD "\t",$nameseq{$name},"\t",$info->[4],"\t",$info->[9],"/",$alignSeqLen,"(",$info->[0],")","\t";
			print DWLD $info->[10],"/",$alignSeqLen,"(",$info->[0],")","\t",$ltr,"\t",$info->[2];
			if ($trimmsg) {
				print STAT " ($trimmsg)";
				print DWLD " ($trimmsg)";
			}
			print STAT "\n";
			print DWLD "\n";
		}				
		++$humanCount;
	}
}
close STAT;
close DWLD;
close LOG;
my $toggleFile = $uploadDir.'flag';
open TOGGLE, ">", $toggleFile or die "couldn't open $!\n";
close TOGGLE;

my $finishTime = localtime();
chomp $finishTime;
my $statFile = "/usr/local/apache2/htdocs/stats/integrationsites.stat";
open STAT, ">>", $statFile or die "couldn't open $statFile: $!\n";
print STAT "$finishTime\t$id\t$remote_addr\t$emailAddr\n";
close STAT;

if ($emailAddr) {
	my $body = "<p>Your job #$id has finished on our server. Please click <a href=https://integrationsites.fredhutch.org/cgi-bin/integrationsites.cgi?id=$id>
	here</a> to get result.</p><p>If the link does not work, please copy and paste following URL to your browser to get your result: 
	<a href=https://integrationsites.fredhutch.org/cgi-bin/integrationsites.cgi?id=$id>https://integrationsites.fredhutch.org/cgi-bin/integrationsites.cgi?id=$id
	</a></p><p>The result will be kept for 5 days after this message was sent.</p>
	<p>If you have any questions please email to mullspt\@uw.edu. Thanks.</p>";

	# Create the email
	my $email = Email::Simple->create(
		header => [
			#To => '"Recipient Name" <recipient@fredhutch.org>',
			#From => '"Sender Name" <sender@fredhutch.org>',
			To => $emailAddr,
			From => 'integrationsites@fredhutch.org',
			Subject => "Your Web Integration Sites #$id Results",
		],
		body => $body,
	);
	$email->header_set( 'Content-Type' => 'Text/html' );
	$email->header_set( 'Reply-To' => 'mullspt@uw.edu' );
	
	# Configure the SMTP transport
	my $transport = Email::Sender::Transport::SMTP->new({
		host => 'mx.fhcrc.org', # Your SMTP server address
		port => 25, # Common ports are 25, 465, or 587
		ssl => 0, # Set to 1 if SSL is required
		# sasl_username => 'your_username', # Your SMTP username
		#sasl_password => 'your_password', # Your SMTP password
	});
	
	# Send the email
	eval {
		sendmail($email, { transport => $transport });
		print "Email sent successfully!\n";
	};
	if ($@) {
		die "Failed to send email: $@\n";
	}

=begin
	my $sendEmail = Email::Simple->create(
		header => [
			To => $emailAddr,
			From => 'IntegrationSites@uw.edu',
			Subject => "Your Web Integration Sites #$id Results",
		],
		body => $body,
	);
	$sendEmail->header_set( 'Content-Type' => 'Text/html' );
	$sendEmail->header_set( 'Reply-To' => 'mullspt@uw.edu' );
	sendmail($sendEmail);
=cut
}


sub parseGenomeXML {
	my $xml = shift;
	my $ltr = shift;
	my $hgDb = shift;
	my $hitDef = my $chromoid = my $asblinfo = my $asblid = my $hframe = '';	
	my $bitscore = my $primarymaxscore = my $alternatemaxscore = my $unplacemaxscore = 0;
	my $qlen = my $identity = my $qfrom = my $qto = my $hfrom = my $hto = my $gaps = 0;
	my $scoreflag = my $pflag = my $aflag = my $uflag = 0;
	my (@primaryinfo, @alternateinfo, @unplaceinfo);	
	open XML, $xml or die "couldn't open $xml: $!\n";
	while (my $line = <XML>) {
		chomp $line;
		next if $line =~ /^\s*$/;
		if ($line =~ /<Iteration_query-len>(\d+)<\/Iteration_query-len>/) {
			$qlen = $1;
		}elsif ($line =~ /<Hit_num>\d+<\/Hit_num>/) {	# this is a hit.
			$hitDef = $chromoid = $asblinfo = $asblid = '';
		}elsif ($line =~ /<Hit_def>(.*)<\/Hit_def>/) {
			$hitDef = $1;
			if ($hitDef =~ /^(\S+) (.*?), (\S+) /) {
				$chromoid = $1;
				$asblinfo = $2;
				$asblid = $3;
			}
#			if ($hgDb =~ /GRCh37/) {
#				if ($chromoid =~ /ref\|(.*?)\|/) {
#					$chromoid = $1;
#				}else {
#					die "Unrecognized chromosome $chromoid\n";
#				}
#			}
		}elsif ($line =~ /<Hsp_num>\d+<\/Hsp_num>/) {
			$bitscore = $scoreflag = $qfrom = $qto = $hfrom = $hto = $identity = $gaps = 0;
			$pflag = $aflag = $uflag = 0;
			$hframe = '';
		}elsif ($line =~ /<Hsp_bit-score>(.*?)<\/Hsp_bit-score>/) { 
			$bitscore = $1;			
			if ($chromoid =~ /^NC_0000/) {
				if ($bitscore >= $primarymaxscore) {
					$primarymaxscore = $bitscore;
					$pflag = $scoreflag = 1;
				}
			}elsif ($chromoRegion{$chromoid} eq 'Unknown') {
				if ($bitscore >= $unplacemaxscore) {
					$unplacemaxscore = $bitscore;
					$uflag = $scoreflag = 1;		
				}																				
			}else {
				if ($bitscore >= $alternatemaxscore) {
					$alternatemaxscore = $bitscore;
					$aflag = $scoreflag = 1;
				}				
			}	
		}elsif ($scoreflag && $line =~ /<Hsp_query-from>(\d+)<\/Hsp_query-from>/) {
			$qfrom = $1;
		}elsif ($scoreflag && $line =~ /<Hsp_query-to>(\d+)<\/Hsp_query-to>/) {
			$qto = $1;
		}elsif ($scoreflag && $line =~ /<Hsp_hit-from>(\d+)<\/Hsp_hit-from>/) {
			$hfrom = $1;
		}elsif ($scoreflag && $line =~ /<Hsp_hit-to>(\d+)<\/Hsp_hit-to>/) {
			$hto = $1;
		}elsif ($scoreflag && $line =~ /<Hsp_hit-frame>(.*)<\/Hsp_hit-frame>/) {
			my $frame = $1;		
			if ($frame == 1) {
				if ($ltr == 3) {
					$hframe = 'F';
				}else {
					$hframe = 'R';
				}				
			}elsif ($frame == -1) {
				if ($ltr == 3) {
					$hframe = 'R';
				}else {
					$hframe = 'F';
				}				
			}else {
				die "unrecognized frame of $frame\n";
			}		
		}elsif ($scoreflag && $line =~ /<Hsp_identity>(.*)<\/Hsp_identity>/) {
			$identity = $1;
		}elsif ($scoreflag && $line =~ /<Hsp_gaps>(.*)<\/Hsp_gaps>/) {
			$gaps = $1;
#			if ($identity/$qlen >= $cutoff) {
				my @info = ();
				push @info, $qlen, $chromoid, $asblinfo, $asblid, $qfrom, $qto, $hfrom, $hto, $hframe, $identity, $gaps;
				if ($pflag) {					
					push @primaryinfo, \@info;
				}elsif ($aflag) {
					push @alternateinfo, \@info;
				}elsif ($uflag) {
					push @unplaceinfo, \@info;
				}
#			}
		}
	}
	close XML;	
	if (@primaryinfo && $primarymaxscore >= $cutoff * $alternatemaxscore && $primarymaxscore >= $cutoff * $unplacemaxscore) {
		return @primaryinfo;
	}elsif (@alternateinfo && $alternatemaxscore >= $cutoff * $unplacemaxscore) {
		return @alternateinfo;
	}else {
		return @unplaceinfo;
	}
}

sub parseHIVXML {
	my $xml = shift;
	my $hitFlag = my $genomeFlag = 0;
	my @genomeInfo = ();
	my $hitId = '';
	open XML, $xml or die "couldn't open $xml: $!\n";
	while (my $line = <XML>) {
		chomp $line;
		next if $line =~ /^\s*$/;
		if ($line =~ /<BlastOutput_version>(.*)<\/BlastOutput_version>/) {
			push @genomeInfo, $1;
		}elsif ($line =~ /<BlastOutput_db>(.*)<\/BlastOutput_db>/) {
			push @genomeInfo, $1;
		}elsif ($line =~ /<Iteration_query-def>(.*)<\/Iteration_query-def>/) {
			push @genomeInfo, $1;
		}elsif ($line =~ /<Iteration_query-len>(\d+)<\/Iteration_query-len>/) {
			push @genomeInfo, $1;
		}elsif ($line =~ /<Hit_num>1<\/Hit_num>/) {	# this is the first hit.
			$hitFlag = 1;	
		}elsif ($hitFlag && $line =~ /<Hit_def>(.*)<\/Hit_def>/) {
			push @genomeInfo, $1;
		}elsif ($hitFlag && $line =~ /<Hsp_query-from>(\d+)<\/Hsp_query-from>/) {
			push @genomeInfo, $1;
		}elsif ($hitFlag && $line =~ /<Hsp_query-to>(\d+)<\/Hsp_query-to>/) {
			push @genomeInfo, $1;
		}elsif ($hitFlag && $line =~ /<Hsp_hit-from>(\d+)<\/Hsp_hit-from>/) {
			push @genomeInfo, $1;
		}elsif ($hitFlag && $line =~ /<Hsp_hit-to>(\d+)<\/Hsp_hit-to>/) {
			push @genomeInfo, $1;
		}elsif ($hitFlag && $line =~ /<Hsp_hit-frame>(.*)<\/Hsp_hit-frame>/) {
			my $frame = $1;		
			if ($frame == 1) {
				push @genomeInfo, "F";
			}elsif ($frame == -1) {
				push @genomeInfo, "R";
			}else {
				die "unrecognized frame of $frame\n";
			}		
		}elsif ($hitFlag && $line =~ /<Hsp_identity>(.*)<\/Hsp_identity>/) {
			push @genomeInfo, $1;
		}elsif ($hitFlag && $line =~ /<Hsp_gaps>(.*)<\/Hsp_gaps>/) {
			push @genomeInfo, $1;
		}elsif ($hitFlag && $line =~ /<Hsp_qseq>(.*)<\/Hsp_qseq>/) {
			push @genomeInfo, $1;
			last;
		}
	}
	close XML;
	return @genomeInfo;
}
