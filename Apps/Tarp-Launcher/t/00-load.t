#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Tarp::Launcher' );
}

diag( "Testing Tarp::Launcher $Tarp::Launcher::VERSION, Perl $], $^X" );
