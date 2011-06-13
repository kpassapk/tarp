#!/usr/bin/perl -w
use strict;

use Tarp::Config;
use Tarp::Style;
use Tarp::LaTeXtract::App;

# This program works like "talatextract" except that it
# checks for a default .tas file in the current directory and
# pops up a Tkx dialog to copy one over from your Resource directory
# if it does not exist.

# You cannot use the --tas option with this program.

die "check options" unless @ARGV;

foreach ( @ARGV ) {
    die "Use 'talatextract' from the command line for the --tas option"
        if /--tas/;
}

my $TEXfile = $ARGV[-1];
die "LaTeXtract requires a '.tex' file to be open for editing, stopped"
    unless $TEXfile =~ /\.tex$/;

sub getTAS {
    eval 'use Tkx';
    die "Tkx not installed!" if $@;
    use File::Copy;

    my $resDir = Tarp::Config->ResourceDir();
    
    die "Tarp resource directory '$resDir' not installed!\n" unless -e $resDir;

    if ( my $f = Tkx::tk___getOpenFile(
            -initialdir => File::Spec->catfile( $resDir, "TASfiles" ),
            -title => "Please select a working TAS file",
            ) ) {
        copy $f, "TASfile.tas" or die "Could not copy $f to 'TASfile.tas': $!, stopped";
    }
}

my $sty = Tarp::Style->new();

if ( ! $sty->defaultTASfile() ) {
    &getTAS();
}

$| = 1; # Flush buffers so the "print" thing below appears first, then stderr.

print "Executing 'talatextract @ARGV'\n";
Tarp::LaTeXtract::App->run();