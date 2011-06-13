#!/usr/bin/perl -w
use strict;

# This script adds a little header to the .pod files in each
# subdirectory and converts them to html.

require Tarp::Config;
use Pod::Html;

my $installDir = Tarp::Config->InstallDir();

opendir(DIR, '.') || die "can't opendir '.': $!";
my @dirs = grep { /_gui$/ } readdir(DIR);
closedir DIR;

foreach my $dir ( @dirs ) {
    my $prog = $dir;
    $prog =~ s/_gui//;
    chdir $dir or die "Could not chdir to '$dir': $!, stopped";
    open IDX, "index.pod" or die "Could not open 'index.pod' for reading: $!, stopped";
    open TMP, ">index_tmp.pod" or die "Could not open 'index_tmp.pod' for writing: $!, stopped";
    
    print TMP <<END_OF_HEADING;

=for html <center><img src="file:///$installDir/tarp.png"></center>

END_OF_HEADING
    local $_;
    while ( <IDX> ) {
        print TMP $_;
    }
    close TMP;
    close IDX;
    
    pod2html(
             "--infile=index_tmp.pod",
             "--outfile=index.html",
             "--title=\"$prog in Komodo\"");
    unlink 'index_tmp.pod';
    unlink 'pod2htmi.tmp';
    unlink 'pod2htmd.tmp';
    chdir "..";
}
