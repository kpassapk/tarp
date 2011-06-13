#!perl -T

use Test::More tests => 2;

BEGIN {
	# test 1
	use_ok( 'Tarp::GenPK' );
}


diag( "Testing Tarp::GenPK $Tarp::GenPK::VERSION, Perl $], $^X" );

$gpk = Tarp::GenPK->new();

# test 2
isa_ok( $gpk, "Tarp::GenPK" );
