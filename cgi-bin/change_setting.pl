#!/usr/bin/perl -w

################################################################################
# switch some settings between release and develop version of integrationsites. release 
# version is in integrationsites directory, develop version is in integrationsites_xxx.
# Author: Wenjie Deng
# Date: 2015-08-10
################################################################################

use strict;
use File::Path;

my $usage = "perl change_setting.pl version_from version_to\n";
my $version_from = shift or die $usage;
my $version_to = shift or die $usage;
if ($version_from ne 'integrationsites' && $version_to ne 'integrationsites') {
	die "one of the versions must be integrationsites\n";
}
my @files = qw (diver.html cot.html insites.html retrieve.html tst.html);
if ($version_to eq 'integrationsites') {
	if (-e "/opt/htdocs/cgi-bin/$version_from") {
		rmtree("/opt/htdocs/cgi-bin/$version_from");
	}
}elsif ($version_from eq 'integrationsites') {
	my $path = '/opt/htdocs';
	my $cgi = "$path/cgi-bin/$version_to";
	mkdir ($cgi);
	symlink ("$path/$version_to/cgi/integrationsites.cgi", "$cgi/integrationsites.cgi");
	symlink ("$path/$version_to/cgi/integrationsites.pl", "$cgi/integrationsites.pl");
	symlink ("$path/$version_to/cgi/download.cgi", "$cgi/download.cgi");
}else {
	die "not a correct version name\n";
}

my $file = "index.html";
my $copy = $file."_copy";
system ("cp $file $copy");
open IN, $copy or die "couldn't open $copy: $!\n";
open OUT, ">$file" or die "couldn't open $file: $!\n";
while (my $line = <IN>) {	
	if ($line =~ /\/$version_from\//) {
		$line =~ s/\/$version_from\//\/$version_to\//;
	}			
	print OUT $line;
}
close IN;
close OUT;
unlink $copy;
