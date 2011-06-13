#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Tarp::GenSkel' );
}

diag( "Testing Tarp::GenSkel $Tarp::GenSkel::VERSION, Perl $], $^X" );
