#!perl

use Test::More tests => 2;
use Tarp::Test::Files;

# $Carp::Verbose = 1;
use Tarp::MasterAlloc;

my $case = 1;
# Tarp::Style->debug( 1 );
# $Carp::Verbose = 1;
sub runTest {
	my $c = "c" . sprintf( "%0*d", 2, $case );
	my $x = shift;
	
	chdir $c or die "Could not chdir to $c: $!, stopped";
		
	$x->getExData( "in/datain.tex" );
	
	open( OUT, '>', "out/dataout.txt" );

	select OUT;
	
	$x->printExData([
		{ exercise     => "Problem"  },
		{ masterNumber => "MasterID" }
	]);

	select STDOUT;
	close OUT;

	Tarp::Test::Files->asExpected( "dataout.txt" );
	
	chdir "..";
	
}

chdir ( "t/t10" ) or die "Could not chdir to t10: $!";

# Default TAS file etc
my $x = Tarp::MasterAlloc->new();

ok( $x->style()->load( "TASfile" ) )
	or diag $x->style()->errStr();

&runTest( $x ); # c01
