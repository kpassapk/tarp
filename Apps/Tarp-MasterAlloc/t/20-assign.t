#!perl

use Test::More tests => 3;
use Tarp::MasterAlloc;
use Tarp::Test::Files;

my $case = 1;


sub runTest {
	my $x = shift;
	my $c = "c" . sprintf( "%0*d", 2, $case++ );

	chdir $c or die "Could not chdir to $c: $!, stopped";

	$x->nextMaster( "42" );

	$x->getExData( "in/in.tex" );
	
	open( OUT, '>', "out/out.txt" )
		or die "Could not open $c/out/out.txt: $!, stopped";
	
	select( OUT );
	$x->printExData( [ { exercise => "Problem" },
			   { masterNumber => "MasterID" } ]);
	select( STDOUT );
	close( OUT ) or die "Could not close $c/out/out.txt: $!, stopped";

	Tarp::Test::Files->asExpected( "out.txt" );

	chdir "..";
}

chdir ( "t/t20" ) or die "Could not chdir to t20: $!";

my $exm = Tarp::MasterAlloc->new();
ok( $exm->style()->load() )
	or diag $exm->style()->errStr();

&runTest( $exm ); # c01

&runTest( $exm ); # c02




