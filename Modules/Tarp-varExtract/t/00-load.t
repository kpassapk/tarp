#!perl -T

use Test::More tests => 5;

BEGIN {
	use_ok( 'Tarp::varExtract' );
}

my $vex = Tarp::varExtract->new();

isa_ok( $vex, "Tarp::varExtract" );

$vex = Tarp::varExtract->new();

$vex->nicknameVar( 1 );

isa_ok( $vex, "Tarp::varExtract" );

is( $vex->nicknameVar(), 1 );

$vex = Tarp::varExtract->new( foo => "bar" );

ok( ! $vex, "Null object" );

diag( "Testing Tarp::varExtract $Tarp::varExtract::VERSION, Perl $], $^X" );
