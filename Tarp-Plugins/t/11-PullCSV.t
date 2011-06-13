#!/usr/bin/perl -w
use strict;
use Cwd;
use Test::More;

use File::Copy qw/move/;

use Tarp::PullCSV::App;
use Tarp::Test::Files;

my $plugDir = "plugins/Tarp/PullCSV";
my @gPlugs = qw/ exercise /; # "global" plugins for all test cases

my @plugs  = ( qw/ tec gcalc gcalc book book book chapter chapter section section/,
#    case:         01   02    03    04   05   06     07     08       09     10
             qw/ master / );
#    case:         11

my $icase = 1;

sub runTest {
    my $plug = $plugs[ $icase - 1 ];
    my $case = "c" . sprintf( "%02d", $icase++ );
    chdir $case or die "Could not cd to $case: $!, stopped";
    
    enable( @gPlugs, $plug );
    Tarp::PullCSV::App->run();
    disable( @gPlugs, $plug );
    
    Tarp::Test::Files->asExpected( "dataout.csv", "$case output" );
    
    chdir "..";
}

sub enable {
    while ( my $m = shift ) {
#        diag "enabling $m";
        move "$plugDir/$m.p_" , "$plugDir/$m.pm";
        die "Could not enable $plugDir/$m: $!, stopped"
            unless -e "$plugDir/$m.pm";
    }
}

sub disable {
    while ( my $m = shift ) {
#        diag "disabling $m";
        move "$plugDir/$m.pm" , "$plugDir/$m.p_";
        die "Could not disable $plugDir/$m: $!, stopped"
            unless -e "$plugDir/$m.p_";
    }
}

chdir "t" or die "Could not chdir to t: $!, stopped";

$ENV{TECHARTS_TOOLKIT_DIR} = cwd();
$plugDir = cwd() . "/" . $plugDir;

chdir "t11" or die "Could not chdir to t11: $!, stopped";

my @ts = <c*>;
my $ts = @ts;
plan tests => $ts;

my @ARGV_COMMON = (
    "--force",
    "--silent",
    "--out=out/dataout.csv",
);

@ARGV = (
    @ARGV_COMMON,
    "in/datain.tex"
);

runTest(); # c01

@ARGV = (
    @ARGV_COMMON,
    "in/datain.tex"
);

# gCalc in exercise
runTest(); # c02

@ARGV = (
    @ARGV_COMMON,
    "in/datain.tex"
);

# Now gCalc comes from instructions
runTest(); # c03

@ARGV = (
    @ARGV_COMMON,
    "--col=exercise",
    "--col=book;my_book",
    "in/datain.tex"
);

# Book is extracted from argument above
runTest(); # c04

@ARGV = (
    @ARGV_COMMON,
    "in/my_book.tex"
);

# Book is extracted from filename
runTest(); # c05

@ARGV = (
    @ARGV_COMMON,
    "in/4c.tex"
);

# Book is extracted from filename and transformed
runTest(); # c06

@ARGV = (
    @ARGV_COMMON,
    "in/my_chapter.tex"
);

# Chapter is extracted from filename
runTest(); # c07

@ARGV = (
    @ARGV_COMMON,
    "in/apdx.tex"
);

# Chapter is extracted from filename and transformed
runTest(); # c08

@ARGV = (
    @ARGV_COMMON,
    "--col=section;a,b,c",
    "in/datain.tex"
);

diag "There should be a warning coming up";
runTest(); # c09

@ARGV = (
    @ARGV_COMMON,
    "in/r.tex"
);

runTest(); # c10

@ARGV = (
    @ARGV_COMMON,
    "in/datain.tex"
);

runTest(); # c11