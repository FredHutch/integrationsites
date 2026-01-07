#!/usr/bin/perl

use CGI;
use CGI::Carp 'fatalsToBrowser';
use File::Temp;
use strict;
use File::Basename;
use POSIX qw(setsid);

my $uploadBase = '/usr/local/apache2/htdocs/outputs/';
my $statsFile = '/usr/local/apache2/htdocs/stats/integrationsites.stat';

my $q = new CGI;

# flush stdout after every write
$| = 1;

print $q->header;

my $remote_ip = $ENV{'REMOTE_ADDR'};
my $rand = int (rand (90)) + 10;
my $id = $q->param("id") || time().$rand;
if ($id !~ /^\d+$/) {
	print "Invalid Id<br>";
	exit;
}
my $uploadDir = $uploadBase."$id/";
my $email = $q->param("email");
my $query = $q->param("querySeq");
my $queryFile = $q->param("queryFile");
my $trim = $q->param("trim");
my $ltr = $q->param("ltr");
my $blast = $q->param("blast");
my $hg = $q->param("hg");
my $dot = $q->param('dot') || 0;
my $remote_addr = '';

my $outFile = $uploadDir."$id.txt";
my $localDir = basename(dirname(__FILE__));
my $toggle = $uploadDir.'flag';

print <<END_HTML;

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<title>Integration Site Result</title>
	<link href="/stylesheets/isstyle.css"  rel="Stylesheet" type="text/css" />
	<link rel="stylesheet" href="/stylesheets/spin.css">
	<script type="text/javascript" src='/javascripts/sorttable.js'></script>
</head>
<body>
<div id='wrap'>
	<div id='header'>
		<div class='spacer'>&nbsp;</div>
		<span class='logo'>Integration Sites</span>
	</div>
	<div id='nav'>
		<span class='nav'><a href="/" class="nav">Home</a></span>
		<span class='nav'><a href="/contact.html" class="nav">Contact</a></span>
		<span class='nav'><a href="/docs/IS_tool_instructions.pdf" class="nav">Help</a></span>
	</div>

	<div id='indent'>

END_HTML

if ($query || $queryFile) {
	$remote_addr = $ENV{'REMOTE_ADDR'};
	if ($email =~ /^\s*$/) {
		$email = '';
	}else {
		$email =~ s/^\s+//;
		$email =~ s/\s+$//;
	}
	my @lines = ();
	my $fasta_flag = 0;
	if ($query) {
		if ($query =~ /\r\n/) {
 			$query =~ s/\r//g;
 		}elsif ($query =~ /\r/) {
 			$query =~ s/\r/\n/g;
 		}
 		@lines = split /\n/, $query;
	}elsif ($queryFile) {
		my $queryFile_handle = $q->upload("queryFile");
		while (my $line = <$queryFile_handle>) {
			$line =~ s/[\r\n]//g;
			push @lines, $line;
		}
	}
	my $uploadQueryFile = $uploadDir."$id.fasta";

	foreach my $line (@lines) {
		if ($line) {
			if ($line =~ /^>/) {
				$fasta_flag = 1;
			}else {
				$fasta_flag = 0;
			}
			last;
		}
	}
	if ($fasta_flag) {
		# upload files
		mkdir $uploadDir or print "$!<br>";
		chmod 0777, $uploadDir;

		open OUT, ">", $uploadQueryFile or die "couldn't open $uploadQueryFile: $!\n";
		foreach my $line (@lines) {
			if ($line) {
				print OUT "$line\n";
			}
		}
		close OUT;
	}else {
		print "<br><p>Error: input sequence is not in fasta format</p>";
		print "</br>";
		print "</div>";
		print "<div id='footer'>";
		print "<p class='copyright'>&copy; 2025 Fred Hutch Cancer Center. All rights reserved.</p>";
		print "</div>";
		print "</div></body></html>";
		exit;
	}

	my $hgDb = "/usr/local/apache2/htdocs/human_genome/$hg/$hg"."_genomic.fna";
	my $gffFile = "/usr/local/apache2/htdocs/human_genome/$hg/$hg"."_gene.gff";
	my $hivDb = "/usr/local/apache2/htdocs/HXB2/HXB2.fasta";
	my @params = ();
	push @params, $id, $email, $remote_addr, $uploadQueryFile, $outFile, $hgDb, $hivDb, $gffFile, $uploadDir, $localDir, $trim, $ltr, $blast;

        # First fork.
        my $pid = fork();
        die "Failed to fork: $!" unless defined $pid;

        if ($pid == 0) {
            # First child.
            setsid() or die "Can't start a new session: $!";

            # Second fork.
            my $pid2 = fork();
            die "Failed to fork second time: $!" unless defined $pid2;

            if ($pid2) {
                # First child exits immediately.
                exit(0);
            }

            # In the grandchild: close inherited file descriptors.
            close(STDOUT);
            close(STDERR);

            # Optionally, redirect STDOUT/STDERR to /dev/null.
            open(STDOUT, '>', '/dev/null') or die "Can't redirect STDOUT: $!";
            open(STDERR, '>', '/dev/null') or die "Can't redirect STDERR: $!";

            # Execute the background process.
            exec("perl", "integrationsites.pl", @params)
            or die "Exec failed: $!";
        }
        # Parent process waits for the first child.
        waitpid($pid, 0);


}
if(!-e $toggle) {
	print "<div>";
	print "<h3>Your job is being processed  </h3>";
		print "<div class=\"spinner\">";
			#print "<div class=\"circle\"></div>";
		print "</div>";
		print "</div>";
	if($email) {
		print "<p>Result will be sent to <b>$email</b> when the job finishes.";
		print "<p>You can close browser if you want.";
	}else {
		print "<p>Please wait here to watch the progress of your job.</p>";
		print "<p>This page will update itself automatically until job is done.</p>";
	}
	print "<script>";
		print "function autoRefresh() {";
			print "location.href = \"integrationsites.cgi?id=$id&email=$email\";";
		print "}";
		print "setInterval('autoRefresh()', 10000);";
	print "</script>";
}

if (-e $toggle && -s $outFile) {
	print "<script type=\"text/javascript\" src='/javascripts/cleancontent.js'></script>";
	open IN, "<", $outFile or die "couldn't open $!\n";
	print "<div id='indent'>";
	print "<h3>Integration Sites Result</h3>";
	print "<a href=download.cgi?id=$id>Download result</a><br><br>";
	print "<div><table width=100% border=1 style='font-size:10px' class='sortable'>";
	print "<thead><tr><th>Id</th><th>Chromosome</th><th>Subject</th><th>Location</th><th>Release</th><th>Genome orientation</th><th>Gene orientation</th><th>Gene</th><th>Full name</th><th>Query start hit</th><th>Identities (Query length)</th><th>Gaps</th><th>LTR</th><th>Note</th></tr></thead>";
	print "<tbody>";
	while (my $line = <IN>) {
		chomp $line;
		next if ($line =~ /^\s*$/ || $line =~ /^id/);
		my @fields = split /\t/, $line;
		print "<tr align='center'><td>$fields[0]</td><td>$fields[2]</td><td>$fields[3]</td><td>$fields[4]</td><td>$fields[5]</td><td>$fields[6]</td><td>$fields[7]</td>";
		print "<td>";
		if ($fields[11]) {
			print "<a href=$fields[11] target=_blank>$fields[8]</a>"
		}else {
			print "$fields[8]";
		}
		print "</td>";
		print "<td>$fields[9]</td><td>$fields[13]</td><td>$fields[14]</td><td>$fields[15]</td><td>$fields[16]</td><td>$fields[17]</td><tr>";
	}
	print "</tbody></table></div>";
	close IN;
}
print "</div>";
print "<br></br>";
print "<div id='footer'>";
print "<p class='copyright'>&copy; 2025 Fred Hutch Cancer Center. All rights reserved.</p>";
print "</div></body></html>";
