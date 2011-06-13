#!/usr/bin/perl -w
use strict;

use YAML::Tiny;
use Tarp::Style;

my %pkFiles => ();

$| = 1; # I want to see output messages while the GUI is running.

use Tarp::LaTeXcombine::GUI::App;

my $PKlist = $ARGV[-1];
die "LaTeXcombine requires a '.pklist' file to be open for editing, stopped"
    unless $PKlist =~ /\.pklist$/;

Tarp::Style->import( "Tarp::Style::ITM" );
my $sty = Tarp::Style->new();
$sty->load() or die $sty->errStr() . "\nStopped";

my $s = $PKlist;

if ( $sty->exists( "filename" ) ) {
    if ( $sty->m( "filename", $PKlist ) ) {
        $s = $sty->mParens()->[-1];
        print "Got section '$s' from filename '$PKlist'\n";
    } else {
        warn "Could not get section by matching '$PKlist' against the 'filename' TAS entry";
    }
}

my $CONFIG = "CHAPT-CONFIG.yml";
if ( -e $CONFIG ) {

    my $yaml = YAML::Tiny->read( $CONFIG );
    
    if ( $yaml ) {
        my $pickups = $yaml->[0]->{'Pickup files'};
        if ( my $sectPickups = $pickups->{$s} ) {
            print "Found section '$s' pickups in $CONFIG\n";
            %pkFiles = %$sectPickups;
        }
    } else {
        warn "Could not read $CONFIG: " . YAML::Tiny->errstr . "\n";
    }
}

my $ltx = Tarp::LaTeXcombine::GUI::App->new();
$ltx->title( "Tarp LaTeXcombine" );
$ltx->PKlist( $PKlist );
$ltx->pkFiles( \%pkFiles );

$ltx->create();

Tkx::MainLoop();
