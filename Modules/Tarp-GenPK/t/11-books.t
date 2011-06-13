#!/usr/bin/perl -w

use strict;
use Tarp::GenPK;

use Test::More tests => 1;

chdir "t/t11" or die "Could not chdir to 't/t11': $!, stopped";

my $gpk = Tarp::GenPK->new();

$gpk->readCorrelation();

is_deeply( $gpk->pickups(), {
          '01' => {
                    'Book1' => 'Book10101.tex',
                    'Book3' => 'Book30101.tex',
                    'Book2' => 'Book20101.tex',
                    'new' => '(virtual)'
                  }
        }, "pickups() ok" );

