#!perl

use Test::More tests => 1;
use Test::Differences;
use Tarp::Test::Files;

use Tarp::LaTeXcombine;
use Tarp::LaTeXcombine::PickupFile;

chdir "t/t10" or die "Could not chdir to t/t10: $!, stopped";

$SIG{__DIE__} = sub {
    die @_;
};
# Tarp::Style->debug( 1 );
#Tarp::LaTeXtract->debug( 1 );
#$Carp::Verbose = 1;

my $f = Tarp::LaTeXcombine->new();
$f->style()->load( "in.tas" ) or die $f->style()->errStr();

$f->instruction( qw/01a foo 01a/ );
$f->instruction( qw/01b foo 01b/ );
$f->instruction( qw/01c foo 01c/ );

my $foo = Tarp::LaTeXcombine::PickupFile->new( "in/foo.tex" );

$f->combine( foo => $foo );

my $out = IO::File->new();

$out->open( ">out/dataout.tex" )
        or die "Could not open out/dataout.txt for writing: $!, stopped";

$f->printChunks( $out );

undef $out;

Tarp::Test::Files->asExpected( "dataout.tex",
	"Simple test with one file" );
