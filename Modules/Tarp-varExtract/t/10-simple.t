#!/usr/bin/perl -w

use strict;

chdir "t/t10" or die "Could not chdir to t/t10: $!, stopped";

use Test::More tests => 1;
use Tarp::varExtract;

my $vex = Tarp::varExtract->new();
$vex->style()->values( "fileBase_search", 'test:\s$foo$' );

$vex->verbose( 1 );

$vex->extract();

is_deeply( $vex->vars(), {
          'test' => {
                      'foo' => 'bla'
                    }
        }, "simple test" );