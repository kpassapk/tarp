#!perl

use Test::More tests => 19;

use Carp;
# $SIG{ __DIE__ } = sub { confess @_ };

eval "use Tarp::LaTeXtract";
plan skip_all => $@ if $@;

diag( "Testing Tarp::LaTeXtract $Tarp::LaTeXtract::VERSION, Perl $], $^X" );

use_ok( "Tarp::LaTeXtract::Loader" );

my @Loaders = qw/ sequenceRestart beginTag endTag List itemTag /;

foreach ( map { "Tarp::LaTeXtract::Loader::$_" } @Loaders ) {
	use_ok( $_ );
}

use_ok( "Tarp::LaTeXtract::App" );
use_ok( "Tarp::LaTeXtract::Style" );

chdir( "t/t00" );

my $ltx = Tarp::LaTeXtract->new();

isa_ok( $ltx, "Tarp::LaTeXtract" );

is( $ltx->style()->file(), undef, "style() method OK" );

ok( $ltx->style()->load(), "Loaded default OK" )
	or diag $ltx->style()->errStr();

is( $ltx->style()->file(), "TASfile", "style()->file() method has default" );

$ltx->style()->file( "foo.tas" ); # foo.tas does not exist.

ok( ! $ltx->style()->load(), "Could not load foo.tas" );

like( $ltx->style()->errStr(), qr/File 'foo.tas' does not exist/, "Setting to nonexistent TAS file OK" );

$ltx->style()->file( "TASfile" );

ok( $ltx->style()->load(), "Loaded TASfile again OK" );

is( $ltx->style()->file(), "TASfile", "And the get method works again" );

is ( $ltx->maxLevel(), -1, "maxLevel method OK" );

$ltx->maxLevel( 42 );

is( $ltx->maxLevel(), 42, "maxLevel set OK" );

eval { $ltx->foo() };

like( $@, qr/Can't access/, "Invalid method OK" );
