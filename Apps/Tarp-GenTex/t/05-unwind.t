#!perl

use strict;
use Test::More tests => 2;
use Test::Differences;
use Tarp::GenTex::Unwind;

my $uw = Tarp::GenTex::Unwind->new();

my @l = $uw->unwind( qw/01a 01b 01c 02 03a 03b/ );

eq_or_diff( \@l, [ qw/1 a b c 2 3 a b/ ], "simple test" );

@l = $uw->unwind( qw/01ai 01aii 01aiii 01aiv 01b 01bi 01bii 02/ );

eq_or_diff( \@l, [ qw/1 a i ii iii iv b i ii 2/ ], "subpart test" );
