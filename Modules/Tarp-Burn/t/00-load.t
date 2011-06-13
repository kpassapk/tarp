#!perl -T

use Test::More tests => 3;

BEGIN {
	use_ok( 'Tarp::Burn' );
}

diag( "Testing Tarp::Burn $Tarp::Burn::VERSION, Perl $], $^X" );

my $burn = Tarp::Burn->new();

isa_ok( $burn, "Tarp::Burn" );

ok( $burn->can( "bulkRename" ), "bulkRename method" );
