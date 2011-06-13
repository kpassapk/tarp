#!/usr/bin/perl -w

use strict;
use Tarp::Style;
use Test::More tests => 17;

chdir "t/t05" or die "could not chdir to t/t05: $!, stopped";

eval 'Tarp::Style->import( "Tarp::MasterAlloc::Style" )';
ok( ! $@, "style import" );

ok( my $s = Tarp::Style->new(), "style new()" );

is( $s->entries(), 2, "two entries" );

is_deeply( [ $s->values( "masterRef" ) ], [ qw/$MASTER$/ ], "masterRef entry" );

is_deeply( [ $s->values( "masterRef\::MASTER" ) ], [ "\\d+" ], "masterRef::MASTER" );

ok( ! $s->load( "empty.tas" ), "load empty.tas" );

like( $s->errStr(), qr/masterRef.*not found/i );

ok( $s->save( "out.tas" ), "saved OK" );

my $s2 = Tarp::Style->new();

ok( $s2->load( "out.tas" ), "loaded OK" );

is_deeply( $s->{_TAS}, $s2->{_TAS}, "TAS data is the same" );

ok( ! $s->load( "badrex.tas" ), "load badrex.tas" );

# diag $s->errStr();
like( $s->errStr(), qr/masterRef .*Regexp Error/, "masterRef error" );
like( $s->errStr(), qr/masterRef::MASTER.*Regexp Error/, "masterRef::MASTER error" );

ok( ! $s->load( "novar.tas" ), "load novar.tas" );

like( $s->errStr(), qr/novar.*should contain '\$MASTER\$/, "novar error" );

ok( ! $s->load( "novardef.tas" ), "load novardef.tas" );

like( $s->errStr(), qr/masterRef::MASTER.*not defined/, "novardef error" );
