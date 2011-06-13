#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Tarp::PullCSV' );
}

diag( "Testing Tarp::PullCSV $Tarp::PullCSV::VERSION, Perl $], $^X" );
