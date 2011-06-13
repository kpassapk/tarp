#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;

use Tarp::LaTeXtract::App;
use Tarp::Test::Files;

my $f = 'errout.txt';

sub runTest {
    eval { Tarp::LaTeXtract::App->run() };
    open( ERR, '>', "out/errout.txt" )
        or die "Could not open out/errout.txt for writing: $!";
    print ERR $@;
    close ERR;
}

chdir ( "t/t21" ) or die "Could not cd to t/t20: $!";

my @COMMON = qw/--tas=in.tas in\/in.tex/;

my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest ] );

@ARGV = ( @COMMON, qw/ --enforce-order / );

$t->case( "Enforcing order" ); # c01

@ARGV = @COMMON;

$t->case( "Missing out-of-order exercise"); # c02

@ARGV = @COMMON;

$t->case( "TAS spec error" ); # c03

@ARGV = ( @COMMON, qw/--context=5/ );

$t->case( "t15/c10 but supplying context from command line" ); # c04
