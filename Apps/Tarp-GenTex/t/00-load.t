#!perl

use Test::More tests => 2;

BEGIN {
	use_ok( 'Tarp::GenTex' );
}

diag( "Testing Tarp::GenTex $Tarp::GenTex::VERSION, Perl $], $^X" );

my $gtx = Tarp::GenTex->new( "foo.pklist" );

isa_ok( $gtx, "Tarp::GenTex" );
