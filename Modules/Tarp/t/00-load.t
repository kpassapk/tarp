#!perl

use Test::More tests => 16;

use Carp;
$SIG{ __DIE__ } = sub { confess @_ };

BEGIN {
	use_ok( 'Tarp' );
	use_ok( 'Tarp::Config'         );

	use_ok( 'Tarp::TAS'           );
	use_ok( 'Tarp::TAS::Spec'     );
	
	use_ok( 'Tarp::Style'          );
	use_ok( 'Tarp::Style::Base'    );
	use_ok( 'Tarp::Style::ITM'      );
	use_ok( 'Tarp::Style::ITM::NLR' );

	use_ok( 'Tarp::Counter' );
	use_ok( 'Tarp::Counter::Numeric' );
	use_ok( 'Tarp::Counter::Latin' );
	use_ok( 'Tarp::Counter::Roman' );
	
	use_ok( 'Tarp::Test::Files'    );
	use_ok( 'Tarp::Test::Exceptions' );
}

diag( "Testing Tarp $Tarp::VERSION, Perl $], $^X" );

my $h = Tarp::Style->new;

isa_ok( $h, Tarp::Style );

my $t = Tarp::TAS->new;
isa_ok( $t, "Tarp::TAS" );
