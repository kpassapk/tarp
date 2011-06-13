#!perl

use Test::More tests => 1;

use Tarp::GenTex;
use Tarp::Test::Files;

chdir ( "t/t20" ) or die "Could not chdir to t20: $!";

sub runTest {
	my $x = shift;
	my $vars = shift;
	$x->gen( %$vars );
}

my $x = Tarp::GenTex->new( "in/3c0102.pklist" );
$x->OUTfile( "out/dataout.tex" );
my %vars = (
	CHAP => [ "1" ],
	SECT => [ "2" ],
	CHAP_TITLE => [ "Learning Perl" ],
	SECT_TITLE  => [ "How to Use Variables" ],
);

my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest, $x, \%vars ] );

$t->case(); # c01
