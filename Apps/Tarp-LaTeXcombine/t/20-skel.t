#!perl

use strict;
use Test::More tests => 3;
use Tarp::Test::Files;
use IO::File;

use Tarp::LaTeXcombine;
use Tarp::LaTeXcombine::PickupFile;

chdir "t/t20" or die "Could not chdir to t/t20: $!, stopped";

my $f = Tarp::LaTeXcombine->new();
ok( $f->style()->load( "in.tas" ), "load in.tas" )
    or diag $f->style()->errStr();

my @is = (
    [ qw/01a foo 01a/ ],
    [ qw/01b foo 01b/ ],
    [ qw/01c foo 01c/ ],    
);

for ( @is ) {
    $f->instruction( @$_ );
}

my $foo = Tarp::LaTeXcombine::PickupFile->new( "in/foo.tex" );

eval '$f->combine( foo => $foo )';
ok( ! $@, "combine w/o errors" ) or diag $@;

my $OUT = IO::File->new;
$OUT->open( "> out/skel.txt" )
        or die "Could not open out/skel.txt: $!, stopped";

$f->printSkel( $OUT );

undef $OUT;

Tarp::Test::Files->asExpected( "skel.txt", "Skeleton with one file OK" );
