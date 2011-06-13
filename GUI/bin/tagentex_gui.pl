#!/usr/bin/perl -w

use strict;

use YAML::Tiny;

use Tarp::GenTex;
use Tarp::GenTex::GUI::App;

$| = 1;

my $PKlist = $ARGV[-1];
die "GenTex requires a '.pklist' file to be open for editing, stopped"
    unless $PKlist =~ /\.pklist$/;

my $gtx = Tarp::GenTex->new( $PKlist );
my $sty = $gtx->style();

$sty->load() or die $sty->errStr() . "\nStopped";

my %vars = ();
my $s = $PKlist;

# Get a section name or number for lookup in YAML file
# plus any variables extracted from filename and transformed with "texVars"

if ( $sty->exists( "filename" ) ) {
    if ( $sty->m( "filename", $PKlist ) ) {
        $s = $sty->mParens()->[-1];
        print "Got section '$s' from filename '$PKlist'\n";
        
        %vars = %{$sty->xformVars( $sty->mVars(), "filename" => "texVars" )};
        %vars = map { $_ => $vars{$_}->[0] } keys %vars; # Just keep first value
        foreach ( keys %vars ) {
            print "Got \$$_\$ = '$vars{$_}' from filename '$PKlist'\n";
        }
    } else {
        warn "Could not get section by matching '$PKlist' against the 'filename' TAS entry";
    }
}

my $CONFIG = "CHAPT-CONFIG.yml";
if ( -e $CONFIG  ) {
    
    my $yaml = YAML::Tiny->read( $CONFIG );
    if ( $yaml ) {
        print "Loaded $CONFIG\n";
        my $yvars = $yaml->[0]->{titles}->{$s};
        if ( ref $yvars eq "HASH" ) {
            print "Got section '$s' titles from $CONFIG\n";
            @vars{keys %$yvars} = values %$yvars;
        } else {
            warn "$CONFIG contains no 'titles' entry for section '$s'.\n";
        }
    } else {
        warn "$CONFIG not loaded: " . YAML::Tiny->errstr() . "\n";
    }
} # if ( -e CHAPT_CONFIG  )

my %preVars = map { $_ => exists $vars{$_} ? $vars{$_} : '' } $gtx->vars();

my $dialog = Tarp::GenTex::GUI::App->new( "." );
$dialog->title( "Tarp GenTex" );
$dialog->PKlist( $PKlist );
$dialog->OUTfile( $gtx->OUTfile() );
$dialog->vars( \%preVars );
$dialog->create();
$dialog->args( "@ARGV" );

Tkx::MainLoop();