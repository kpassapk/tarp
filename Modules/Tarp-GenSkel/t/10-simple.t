#!perl

use Test::More tests => 1;
use IO::File;
use Tarp::Test::Files;

use Tarp::GenSkel;

chdir "t/t10" or die "Could not cd to t10: $!, stopped";

my $g = Tarp::GenSkel->new();

$g->style()->load( "in.tas" ) or die "Could not load style";

$g->addChunk( "01a", "01a" );
$g->addChunk( "01ai", "01ai" );
$g->addChunk( "01aii", "01aii" );
$g->addChunk( "01b", "01b" );

my $out = IO::File->new;
$out->open( "> out/skel.txt" )
        or die "Could not open out/skel.txt for writing: $!";

$g->printSkel( $out );

undef $out;

Tarp::Test::Files->asExpected( "skel.txt", "Simple output OK" );

unlink "out/skel.txt";
