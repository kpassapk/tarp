#!perl -T

use Test::More tests => 8;

BEGIN {
	use_ok( 'Tarp::Itexam' );
	use_ok( 'Tarp::Itexam::Attribute' );
	use_ok( 'Tarp::Itexam::Attribute::Line' );
	use_ok( 'Tarp::Itexam::Attribute::Master' );	
}

diag( "Testing Tarp::Itexam $Tarp::Itexam::VERSION, Perl $], $^X" );

chdir ( "t/t00" ) or die "Could not chdir to test directory, stopped";

$foo = Tarp::Itexam->new;

isa_ok( $foo, "Tarp::Itexam" );

$attr = Tarp::Itexam::Attribute->new( "attr", $foo );

isa_ok( $attr, 'Tarp::Itexam::Attribute' );

$attr = Tarp::Itexam::Attribute::Line->new( "attr", $foo );

isa_ok( $attr, 'Tarp::Itexam::Attribute::Line' );

$attr = Tarp::Itexam::Attribute::Master->new( "attr", $foo );

isa_ok( $attr, 'Tarp::Itexam::Attribute::Master' );


