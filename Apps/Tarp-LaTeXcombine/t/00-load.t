#!perl

use Test::More tests => 2;

BEGIN {
	use_ok( 'Tarp::LaTeXcombine' );
}

chdir "t" or die "Could not chdir to t: $!, stopped";

{

	my $f = Tarp::LaTeXcombine->new;

	isa_ok( $f, "Tarp::LaTeXcombine" );
}

diag( "Testing Tarp::LaTeXcombine $Tarp::LaTeXcombine::VERSION, Perl $], $^X" );
