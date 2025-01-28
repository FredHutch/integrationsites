#!/usr/bin/perl

use strict;
use File::Path;

my $dir = '/usr/local/apache2/htdocs/outputs';
opendir DIR, $dir;
while (my $subdir = readdir DIR) {
	next if $subdir =~ /^\./;
	$subdir = $dir.'/'.$subdir;
	my $rmflag = 1;
	if (-d $subdir) {
		opendir SUBDIR, $subdir;
		while (my $file = readdir SUBDIR) {
			next if $file =~ /^\./;
			if ($file eq "toggle") {
				$rmflag = 0;
				last;
			}else {
				my $fullname = $subdir."/".$file;
				if((-f $fullname) && (-M $fullname < 5)) {
					$rmflag = 0;
					last;
				}
			}
		}
		closedir SUBDIR;
		if ($rmflag) {
			rmtree($subdir);
			#print "$subdir has been removed.\n";
		}
	}	
}
closedir DIR;


