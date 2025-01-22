#!/usr/bin/perl

use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser);

my $id = param('id');
if ($id !~ /^\d+$/) {
	Error('open', 'file');
}
my $uploadbase = '/usr/local/apache2/htdocs/outputs';
my $files_location = "$uploadbase/$id";
my $ID = $id.'_download.txt';

%allowed_ext = (

  # archives
  'zip' => 'application/zip',
  'gz' => 'application/gz',

  # documents
  'pdf' => 'application/pdf',
  'doc' => 'application/msword',
  'xls' => 'application/vnd.ms-excel',
  'ppt' => 'application/vnd.ms-powerpoint',
  'txt' => 'application/txt',
  'fas' => 'application/fas',
  'tar' => 'application/tar',
  'tre' => 'application/tre',
  
  # executables
  'exe' => 'application/octet-stream',

  # images
  'gif' => 'image/gif',
  'png' => 'image/png',
  'jpg' => 'image/jpeg',
  'jpeg' => 'image/jpeg',

  # audio
  'mp3' => 'audio/mpeg',
  'wav' => 'audio/x-wav',

  # video
  'mpeg' => 'video/mpeg',
  'mpg' => 'video/mpeg',
  'mpe' => 'video/mpeg',
  'mov' => 'video/quicktime',
  'avi' => 'video/x-msvideo'
);

# file extension
my @fileParts = split /\./, $ID;
$fext = $fileParts[$#fileParts];

# check if allowed extension
if (!$allowed_ext{$fext}) {
  die("Not allowed file type of .$fext\n"); 
}

# get mime type
if ($allowed_ext{$fext}) {
	$mtype = $allowed_ext{$fext};
}else {
	$mtype = "application/force-download";
}

if ($ID eq '') { 
	print "Content-type: text/html\n\n"; 
	print "You must specify a file to download."; 
} else {
	$date = gmtime;
	open(DLFILE, "<", "$files_location/$ID") || Error('open', 'file'); 
	binmode DLFILE;
	@fileholder = <DLFILE>; 
	
	close (DLFILE) || Error ('close', 'file'); 
=begin
	my $remote_host = $ENV{'REMOTE_HOST'};
	my $remote_addr = $ENV{'REMOTE_ADDR'};
	open (LOG, ">>", "/opt/htdocs/logs/integrationsites.log") || Error('open', 'file');
	print LOG "$date\t$remote_addr\t$ID\n";
	close (LOG);
=cut
	print "Content-Type:$mtype\n"; 
	print "Content-Disposition:attachment;filename=$ID\n\n";
	print @fileholder;
}

sub Error {
    print "Content-type: text/html\n\n";
	print "The server can't $_[0] the $_[1]: $! \n";
	exit;
}
