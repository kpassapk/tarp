#!/usr/bin/perl -w
use strict;
use Test::More tests => 20;
use Tarp::Style;

chdir "t/t05" or die "Could not chdir to t/t05: $!, stopped";

Tarp::Style->import( "Tarp::GenSkel::Style" );

eval 'Tarp::Style->new()';

like( $@, qr/must be imported along with 'Tarp::LaTeXtract::Style/, "import err1" );

Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
Tarp::Style->import( "Tarp::LaTeXtract::Style" );

my $sty = Tarp::Style->new();

ok( $sty->save( "out.tas" ), "style save" );

my $sty2 = Tarp::Style->new();

ok( $sty2->load( "out.tas" ), "style load" )
    or diag $sty2->errStr();

unlink "out.tas";

is_deeply( $sty->{_TAS}, $sty2->{_TAS}, "data structures are the same" );

my @qrs = $sty->qr("itemTag_2_");

ok( 'a' =~ $qrs[1], "itemTag_2_ matches" );

ok( $sty->load( "good.tas" ), "load good.tas" );

ok( '\item(1)' =~ ( $sty->qr("itemTag_1_") )[1], "itemTag_1_ matches" );
ok( '\item(a)' =~ ( $sty->qr("itemTag_2_") ) [1], "itemTag_2_ matches" );
ok( '\item(ix)' =~ ( $sty->qr("itemTag_3_") )[1], "itemTag_3_ matches" );
ok( '\begin{enumerate}' =~ ( $sty->qr("beginTag") )[1], "beginTag matches" );
ok( '\end{enumerate}' =~ ( $sty->qr("endTag") )[1], "endTag matches" );

ok( ! ( 'item(1)' =~ ( $sty->qr("itemTag_1_") )[1] ), "itemTag_1_ no match" );
ok( ! ( 'item(a)' =~ ( $sty->qr("itemTag_2_") )[1] ), "itemTag_2_ no match" );
ok( ! ( 'item(ix)' =~ ( $sty->qr("itemTag_3_") )[1] ) , "itemTag_3_ no match" );
ok( ! ( 'begin{enumerate}' =~ ( $sty->qr("beginTag") )[1] ) , "beginTag no match" );
ok( ! ( 'end{enumerate}' =~ ( $sty->qr("endTag") )[1] ) , "endTag no match" );

ok( ! $sty->load( "bad.tas" ), "bad.tas load" );

like( $sty->errStr(), qr/beginTag.*contains non printable characters/, "beginTag np" );
like( $sty->errStr(), qr/itemTag\[2\].*contains non printable characters/, "itemTag_2_ np" );
like( $sty->errStr(), qr/itemTag\[3\].*contains non printable characters/, "itemTag_3_ np" );

