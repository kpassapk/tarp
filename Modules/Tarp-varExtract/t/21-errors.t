#!/usr/bin/perl -w
use strict;
use Test::More tests => 4;

use Tarp::varExtract;
use Tarp::Test::Exceptions;

my $case = 0;

my %errors = (
    DUP_NICK => qr/both have the same nickname/,
    USAGE => qr/check usage/i,
    WRITE => qr/error while writing/i,
);

my @exp = @errors{
    "USAGE", # c01
    "WRITE", # c02
    "DUP_NICK",
};

# Turn warnings fatal.
BEGIN { $SIG{'__WARN__'} = sub { die $_[0]; } }

chdir "t/t21" or die "Could not cd to t21: $!, stopped";

my $vex = Tarp::varExtract->new();

my $t = Tarp::Test::Exceptions->new();
$t->expected( \@exp );

$t->case( $vex, "write()" );
$t->case( $vex, "write( \"out/out.yml\" )" );

ok( $vex->style()->load( "c03/style.tas" ), "style load" )
    or diag $vex->style()->errStr();

$vex->nicknameVar( 0 );

$t->case( $vex, "extract()", "duplicate nicknames" );

#use Data::Dumper;
#print Dumper $vex->vars();
