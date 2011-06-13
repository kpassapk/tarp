#!perl -T

use Test::More tests => 4;

BEGIN {
	use_ok( 'Tarp::MasterAlloc' );
}

diag( "Testing Tarp::MasterAlloc $Tarp::MasterAlloc::VERSION, Perl $], $^X" );

use_ok( "Tarp::MasterAlloc::Style" );
use_ok( "Tarp::MasterAlloc::NewMasterAttribute" );
use_ok( "Tarp::MasterAlloc::App" );

