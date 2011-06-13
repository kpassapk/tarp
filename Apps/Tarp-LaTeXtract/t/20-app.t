#!/usr/bin/perl -w
use strict;

use Test::More;

use Tarp::LaTeXtract::App;
use Tarp::Test::Files;

plan tests => 3;

chdir ( "t/t20" ) or die "Could not cd to t/t20: $!";

ok( ! -e "TASfile.tas", "no tasfile" );
@ARGV = ( qw/--gen-tas/ );
Tarp::LaTeXtract::App->run();

ok( -e "TASfile.tas", "tasfile exists" ) and unlink "TASfile.tas";

sub runTest {
    open( OUT, '>', "out/dataout.txt" )
        or die "Could not open out/dataout.txt for writing: $!";
    select OUT;
    eval { Tarp::LaTeXtract::App->run };
    select STDOUT;
    close OUT;
    diag $@ if $@;
}

my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest ] );

my @COMMON = qw/--tas=in.tas/;

@ARGV = ( @COMMON, qw/in\/in.tex/ );

$t->case( "t21/c01 but not enforcing order" ); # c01

