#!perl

# 05-methods.t - Test methods

use Test::More tests => 59;
use Data::Dumper;

use Tarp::LaTeXtract;

chdir( "t/t05" ) or die "Could not chdir to 't/t05': $!, stopped";

# Use default TAS file
my $ltx = Tarp::LaTeXtract->new();
isa_ok( $ltx, "Tarp::LaTeXtract" );

ok( $ltx->style()->load(), "Loaded style" )
    or diag $ltx->style()->errStr();

ok( $ltx->read( "in.tex" ), "read in.tex" )
    or diag $ltx->errStr();

use IO::File;
my $io = IO::File->new();
$io->open( '> matches.txt' )
    or die "Could not open matches.txt for writing: $!, stopped";

$ltx->dumpMatches( $io );

undef $io;

open( M, "<matches.txt" ) or die "could not open matches.txt for reading: $!";
{
    local $/;
    my $m = <M>;
    is( 0 + ( $m =~ tr/\n// ), 23, "matches.txt has 23 lines" );
}
close M and unlink "matches.txt";

ok( $ltx->exists( "01a", 0 ), "Exercse does exist" );

ok( $ltx->exists( "01", 0 ), "Non leaf item exists" );

ok( ! $ltx->exists( "01c", 0 ), "Exercise does not exist" );

ok( $ltx->isLeaf( "01a", 0 ), "isLeaf is true for 01a" );

ok( ! $ltx->isLeaf( "02", 0 ), "isLeaf false for 02" );

my $last = $ltx->maxLevel();

$ltx->maxLevel( 0 );

ok( $ltx->isLeaf( "02", 0 ), "isLeaf true for 02 after changing maxLevel" );

$ltx->maxLevel( $last );

ok( ! defined $ltx->isLeaf( "06", 0 ), "isLeaf for nonexistent ex" );

ok( $ltx->isSequential( "01b", "02", 0 ), "First sequential test OK" );

ok( $ltx->isSequential( "01b", "02a", 0 ), "Second sequential test OK");

ok( $ltx->isSequential( "01", "02", 0 ), "Third sequential test OK");

ok( $ltx->isSequential( "01", "02a", 0 ), "Fourth sequential test OK");

ok( ! $ltx->isSequential( "01a", "02", 0 ), "Fifth sequential test OK");

ok( $ltx->isSequential( "04", "05", 0 ), "Sixth sequential test OK");

ok( ! defined $ltx->isSequential( "05", "06", 0 ), "isSequential on nonexistent ex" );

ok( $ltx->isSequential( "04", "05", 0 ), "isSequential next to last -> last" );

ok( ! $ltx->isSequential( "05", "04", 0 ), "isSequential last -> next to last" );

$ltx->maxLevel( 2 );

ok( $ltx->exists( "01a", 0 ), "Exercse does exist" );

ok( $ltx->exists( "01", 0 ), "Non leaf item exists" );

$ltx->maxLevel( 0 );

ok( $ltx->exists( "01a", 0 ), "Exercse does exist" ); # 18

ok( $ltx->exists( "01", 0 ), "Non leaf item exists" );

$ltx->maxLevel( 2 );

ok( $ltx->read( "foo0301.tex" ), "read foo0301.tex" )
    or diag $ltx->errStr();

is( $ltx->style()->vars( "myEntry" ), 5, "All myEntry entries have 5 vars" )
    or diag Dumper $ltx->varsInTASentry( "myEntry" );

is( $ltx->style()->vars( "myEntry", 0 ), 3, "myEntry entry zero has three vars" )
    or diag Dumper $ltx->varsInTASentry( "myEntry", 0 );
    
is( $ltx->style()->vars( "myEntry", 1 ), 4, "myEntry entry one has four vars" )
    or diag Dumper $ltx->varsInTASentry( "myEntry", 1 );

my ( $dsc ) = $ltx->style()->interpolate( "myEntry" );

# Try the named capture buffers...

ok( "foo0301.tex" =~ /$dsc/, "Match was found" );

is( $-{BOOK}[0], "foo", "BOOK variable is foo" );

is( $-{CHAPTER}[0], "03", "Chapter is 03" );

is( $-{SECTION}[0], "01", "Section is 01" );

ok( $ltx->read( "4c03pr2a.tex" ), "read 4c03pr2a.tex" )
    or diag $ltx->errStr();

( undef, $dsc ) = $ltx->style()->interpolate( "myEntry" );

ok( "4c03pr2a.tex" =~ /$dsc/, "Match was found" );

is( $-{BOOK}[0], "4c", "BOOK variable is 4c" );

is( $-{CHAPTER}[0], "03", "Chapter is 03" );

is( $-{PROJ_NUMBER}[0], "2", "Project number is 2" );

is( $-{PROJ_LETTER}[0], "a", "Project letter is a" );

my $vars = $ltx->variables();

my $titleVar = $vars->{"title::TITLE"};

is( $titleVar->[0]{pos}, 7, "Title position OK" );

my $exVar = $vars->{"itemTag_1_::ITM"};

is( $exVar->[0]{pos}, 0, "Ex position OK" );

my ( $ex, $seq  ) = $ltx->itemOnLine( 7 );

is( $ex, "01a", "01a on line 7" );

is( $seq, 0, "sequence 0 on line 7" );

( $ex, $seq ) = $ltx->itemOnLine( 16 );

is( $ex, "02b", "02b on line 16 " );

is( $seq, 0, "sequence 0 on line 16" );

( $ex, $seq ) = $ltx->itemOnLine( 1 );

is( $ex, '', "line 1 not part of any exercise" );

is( $seq, 0, "sequence 0 on line 1" );

( $ex, $seq ) = $ltx->itemOnLine( 999 );

is( $ex, undef, "Exercise not defined for line 999" );

my $line;

# Tarp::LaTeXtract->debug( 1 );
($line, $ex, $seq) = Tarp::LaTeXtract->find( "find.tex", qr/wyxnob/ );

is( $line, 25, "wyxnob ahoy line 25" );

is( $ex, "03a", "wyxnob ahoy item 03a" );

is( $seq, 0, "wyxnob ahoy sequence 0" );

($line, $ex, $seq) = Tarp::LaTeXtract->find( "find.tex", qr/wyxnob/ );

is( $line, 33, "wyxnob ahoy line 33" );

is( $ex, "05", "wyxnob ahoy item 05" );

is( $seq, 0, "wyxnob ahoy sequence 0" );

($line, $ex, $seq) = Tarp::LaTeXtract->find( "find.tex", qr/wyxnob/ );

is( $line, 33, "wyxnob ahoy line 33" );

is( $ex, "05", "wyxnob ahoy item 05" );

is( $seq, 0, "wyxnob ahoy sequence 0" );

($line, $ex, $seq) = Tarp::LaTeXtract->find( "find.tex", qr/wyxnob/ );

is( $line, 38, "wyxnob ahoy line 38" );

is( $ex, '', "wyxnob not in an exercise" );

is( $seq, 1, "wyxnob ahoy sequence 1" );
