#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;

use Tarp::varExtract;
use Tarp::Test::Files;

chdir "t/t20" or die "Could not cd to t20: $!, stopped";

# Diag the warnings
BEGIN { $SIG{'__WARN__'} = sub { diag $_[0]; } }

sub runTest {
    my $vex = shift;
    my $nick = shift;
    
    $vex->nicknameVar( $nick );
    ok( $vex->style()->load(), "style load" )
        or diag $vex->style()->errStr();
    
    $vex->extract();
    
    $vex->write( "out/out.yml" );
}

my $vex = Tarp::varExtract->new();

my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest, $vex, -1 ] );

$t->case(); # c01
diag "Next line should be a warning about the same nickname";
$t->generator( [ \&runTest, $vex, 0 ] );
$t->case(); # c02
