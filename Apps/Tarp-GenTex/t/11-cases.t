#!perl

use Test::More tests => 2;
use Tarp::Test::Files;

use Tarp::GenTex;

chdir ( "t/t10" ) or die "Could not chdir to t/t10: $!";

sub runTest {
    my $x = shift;
    $x->gen();
}

# Tarp::Style->debug( 1 );
# Tarp::LaTeXtract->debug( 1 );
my $x = Tarp::GenTex->new( "in/in.pklist" );
$x->OUTfile( "out/out.tex" );
ok( $x->style()->load(), "style load" ) or diag $x->style()->errStr();
my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest, $x ] );

$t->case( "out.tex", "out of order pklist" ); # c01

