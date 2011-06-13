#!perl

BEGIN {
	use Cwd;
	our $directory = cwd;
}

use lib "$directory/t/t10";

use strict;
use Test::More tests => 8;
use Test::Differences;
use IO::File;

use Tarp::PullCSV;
use Tarp::Test::Files;

my $cc = 1;

sub runTest {
	my $case = "c" . sprintf( "%02d", $cc++ );
	my $x = shift;
	
	chdir ( $case ) or die "Could not cd to $case: $!, stopped";
	ok( $x->style()->load(), "$case style load" )
		or diag $x->style()->errStr();
	$x->getColumnData( "in/in.tex" );

	my $OUT = IO::File->new();
	$OUT->open( ">out/out.csv" )
		or die "Could not open out/out.csv for writing: $!, stopped";

	$x->write( $OUT, Tarp::PullCSV::PRINT_HEADINGS );

	undef $OUT;

	Tarp::Test::Files->asExpected( "out.csv", "$case output" );
	
	chdir "..";
}

chdir ( "t/t10" ) or die "Could not chdir to t10: $!";

my $x = Tarp::PullCSV->new();

runTest( $x ); # c01

use FortyTwo;

my $f42 = FortyTwo->new( $x );

runTest( $x ); # c02	

use MasterCol;

MasterCol->new( $x );

runTest( $x ); # c03

$x->takeColumn( $f42 );

runTest( $x ); # c04




