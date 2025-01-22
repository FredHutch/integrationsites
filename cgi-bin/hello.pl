#!/usr/bin/perl
use strict;
use warnings;

print "Content-type: text/html\n\n";
print "<html><head><link rel='stylesheet' type='text/css' href='/static/style.css'></head><body>";
print "<h1>Hello from Perl CGI inside Docker!</h1>";
print "<script src='/static/script.js'></script>";
print "</body></html>";
