#!perl

use Test::More tests => 2;
use Test::Differences;

use IO::File;

use Tarp::MasterAlloc;
use Tarp::Test::Files;

chdir ( "t/t30" ) or die "Could not chdir to t30: $!";

my $case = 1;

sub runTest {
	my $x = shift;
	my $c = "c" . sprintf( "%0*d", 2, $case++ );

	chdir $c or die "Could not chdir to $c: $!, stopped";

	$x->nextMaster( "42" );
	$x->getExData( "in/in.tex" );

        my $io = IO::File->new;
        $io->open( ">out/out.tex" )
                or die "Could not open out/out.tex for writing: $!";
	$x->printLineBuffer( $io );
        
        undef $io;

	Tarp::Test::Files->asExpected( "out.tex", "$c output" );
	
	chdir "..";
}

my $x = Tarp::MasterAlloc->new();
$x->style()->load()
	or die "Could not load style: " . $x->style()->errStr();

&runTest( $x ); # c01
&runTest( $x ); # c02