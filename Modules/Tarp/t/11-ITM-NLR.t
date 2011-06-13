#!/usr/bin/perl -w

use strict;

use Test::More tests => 83;

use Tarp::Style;
Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );

chdir "t/t11" or die "Could not chdir to t11: $!, stopped";

# 2.  Get interpolated regexp
# 3.  Match against it and get variables. %- is equivalent to data structure.
# 4.  Convert by running %- through a converter function.
# 5.  Get the value from the return as usual.

my $hlp = Tarp::Style->new();

ok( $hlp, "constructor returned something" );
isa_ok( $hlp, "Tarp::Style" );

# Check built in entries

use Data::Dumper;

is( scalar $hlp->entries( 0 ), 7, "7 entries" )
    or diag "Got these entries: " . Dumper [ $hlp->entries( 0 ) ];

ok( $hlp->exists( "itemTag_0_" ), "itemTag_0_ exists" );
ok( $hlp->exists( "itemTag_1_" ), "itemTag_0_ exists" );
ok( $hlp->exists( "itemTag_2_" ), "itemTag_0_ exists" );
ok( $hlp->exists( "itemTag_3_" ), "itemTag_0_ exists" );

ok( $hlp->exists( "itemString" ), "itemString exists" );
ok( $hlp->exists( "itemStack" ), "itemString exists" );
ok( $hlp->exists( "itemSplit" ), "itemSplit exists" );

ok(   $hlp->m( itemTag_1_ => "1"    ), "single digit itemTag_1_" );
ok(   $hlp->m( itemTag_1_ => "12"   ), "two digit itemTag_1_" );
ok(   $hlp->m( itemTag_1_ => "121"  ), "three digit itemTag_1_" );
ok( ! $hlp->m( itemTag_1_ => "1212" ), "four digit itemTag_1_" );
ok( ! $hlp->m( itemTag_1_ => "a"    ), "letter itemTag_1_" );
ok( ! $hlp->m( itemTag_1_ => "iv"   ), "roman itemTag_1_" );

ok(   $hlp->m( itemTag_2_ => "a"    ), "single letter itemTag_2_" );
ok( ! $hlp->m( itemTag_2_ => "az"   ), "double letter itemTag_2_" );
ok( ! $hlp->m( itemTag_2_ => "1"    ), "number itemTag_2_" );

ok(   $hlp->m( itemTag_3_ => "i"    ), "i itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "ii"   ), "ii itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "iii"  ), "iii itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "iv"   ), "iv itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "v"    ), "v itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "vi"   ), "vi itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "vii"  ), "vii itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "viii" ), "viii itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "ix"   ), "ix itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "x"    ), "x itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "xi"   ), "xi itemTag_3_" );
ok(   $hlp->m( itemTag_3_ => "xii"  ), "xii itemTag_3_" );
ok( ! $hlp->m( itemTag_3_ => "di"   ), "di itemTag_3_" );

ok( ! $hlp->m( "itemString", "1iv" ), "itemString matched" );
ok( ! $hlp->m( "itemString", "iv" ), "itemString matched" );
ok( ! $hlp->m( "itemString", "1" ), "itemString matched" );
ok(   $hlp->m( "itemString", "01" ), "itemString matched" );
ok(   $hlp->m( "itemString", "01a" ), "itemString matched" );
ok(   $hlp->m( "itemString", "01aiv" ), "itemString matched" );

my %m = %{ $hlp->mVars };

my $itemStack    = $hlp->xformVars( \%m, "itemString", "itemStack" );
my $exTag        = $hlp->xformVars( \%m, "itemString", "itemTag_1_" );
my $partTag      = $hlp->xformVars( \%m, "itemString", "itemTag_2_" );
my $subPartTag   = $hlp->xformVars( \%m, "itemString", "itemTag_3_" );

is_deeply( $itemStack, {
          'ITM' => [
                    1,
                    1,
                    4
                  ]
        }, "itemStack ok" );

is_deeply( $exTag, {
          'ITM' => [
                    1
                  ]
        }, "exTag okay" );

is_deeply( $partTag, {
          'ITM' => [
                    'a'
                  ]
        }, "partTag okay" );

is_deeply( $subPartTag, {
          'ITM' => [
                    'iv'
                  ]
        }, "subPartTag okay" );

my @qrs = $hlp->qr( "itemString" );

ok( ! ( '01AIV' =~ $qrs[0] ), "Case sensitive by default" );

$hlp->values( "itemString::ITM::CSENS", 0 );

ok ( '01AIV' =~ ( $hlp->qr( "itemString" ) )[0], "Now turned case insensitive" );

$hlp->values( "myTag", qw/ d e f / );

ok( $hlp->save( "out.tas" ), "saved out.tas" )
    or diag $hlp->errStr();

is( scalar $hlp->entries( 0 ), 8, "8 entries" )
    or diag "Got these entries: " . Dumper [ $hlp->entries( 0 ) ];

my $hlp2 = Tarp::Style->new();

$hlp2->load( "out.tas" )
    or diag "Could not load out.tas: " . $hlp2->errStr();

# This does not get saved
$hlp2->values( "itemString::ITM::CSENS", 0 );

is_deeply( $hlp->{_TAS}, $hlp2->{_TAS}, "Data structures are the same" );

SKIP: {
    eval 'use Test::Differences';
    skip( "Test::Differences required for these tests", 1 ) if $@;

    eq_or_diff( [ $hlp->values( "myTag" ) ], [ qw/d e f/ ], "loaded myTag ok" );
}

ok( '01aiv' =~ ($hlp->qr( "itemString" ))[0], "itemString still matches" );

ok( my ( $ierp ) = $hlp->interpolateVars( 'e$ITM$ p$ITM$ t$ITM$', { %- } ), "interpolateValues" )
    or diag $hlp->errStr();

is( $ierp, 'e01 pa tiv', "Interpolate %-" );

# itemString longhand
is( join( '', @{ $hlp->xformVars( { ITM => [ 1, 1, 4 ] },
        "itemStack" => "itemString" )->{ITM} } ), "01aiv", "itemString longhand" );

# itemString shorthand
is( $hlp->itemString( [1, 1, 4] ), "01aiv", "itemString shorthand" );

# itemStack longhand
ok( $hlp->m( "itemString" => "01aiv" ), "m itemString 01aiv" );
is_deeply( $hlp->xformVars( $hlp->mVars(), "itemString" => "itemStack" )->{ITM}
          , [ qw/1 1 4/ ], "itemStack longhand" );

# itemstack shorthand
is_deeply( $hlp->itemStack( "01aiv" ), [ qw/1 1 4/ ], "itemStack of three elements" );


is( $hlp->itemStack( "foo"), undef, "itemStack of bad exercise" );

is( $hlp->greatestCommonLevel( "01", "02" ), -1, "gcl -1" );

is( $hlp->greatestCommonLevel( "01aix", "01" ), 0, "gcl 0" );

is( $hlp->greatestCommonLevel( "01aiv", "01ai" ), 1, "gcl 1" );

is( $hlp->greatestCommonLevel( "01aiv", "01aiv" ), 2, "gcl 2" );

#is( $hlp->parseString( "01aiv" ), 1 , "parse good exercise" );

ok( $hlp->m( itemString => "01aiv" ), "parse good exercise" );
  
#ok( ! $hlp->parseString( "foo" ), "parse bad exercise" );

ok( ! $hlp->m( itemString => "foo" ), "parse bad exercise" );

# ok( ! $hlp->parseString( undef ), "parse undef" );

# Tests for parentEx:

# Returns the parent exercise.
is( $hlp->parentEx( "01aiv" ), "01a", "parentEx seems okay" );

is( $hlp->parentEx( "foobar" ), undef, "parent of bad ex okay" );

# If a zero-level exercise is given, an empty string is returned
is( $hlp->parentEx( "03" ), '', "parent of level zero okay" );

# If an invalid exercise is given, C<undef> is returned.
is( $hlp->parentEx( "01a" ), "01", "Another parent ex okay" );

# Tests for isChild:

# Returns C<1> if the exercise given as a first argument is child
# of the exercise given as a second argument...
is( $hlp->isChild( "01aiv", "01a" ), 1, "example isChild okay" );

# ... and the empty string otherwise.
is( $hlp->isChild( "01aiv", "02" ), '', "isChild false for non-child" );

# isInOrder

ok( $hlp->isInOrder( "01", "02" ), "isInOrder same level zero" );

ok( $hlp->isInOrder( "01a", "01b" ), "isInOrder same level one" );

ok( $hlp->isInOrder( "01ai", "01aii" ), "isInOrder ok same level two" );

ok( $hlp->isInOrder( "01", "01a" ), "isInOrder down one level 0->1" );

ok( $hlp->isInOrder( "01a", "02" ), "isInOrder down lone level 1->2" );

ok( ! $hlp->isInOrder( "01", "01ai" ), "isInOrder down two levels 0->2" );

ok( $hlp->isInOrder( "01ai", "01b" ), "isInOrder ok up one level 2->1" );

ok( $hlp->isInOrder( "01ai", "02" ), "isInOrder ok up two levels 2->0" );

ok( $hlp->isInOrder( "101", "102" ), "isInOrder ok for 101, 102" );

ok( ! $hlp->isInOrder( "02", "01"), "isInOrder ok for 02, 01" );

ok( ! $hlp->isInOrder( "102", "101" ), "isInOrder ok for 102, 101" );

ok( $hlp->isInOrder( "01aiv", "01av" ), "isInOrder ok for 01aiv, 01av" );

ok( ! $hlp->isInOrder( "01aiv", "01avi" ), "isInOrder ok for 01aiv, 01avi" );

SKIP: {
    eval 'use Test::Differences';
    skip( "Test::Differences required for these tests", 1 ) if $@;

    my @outOfOrder = ( qw/01a 03b 100 21aiv 20axv/ );
    
    my @inOrder = $hlp->sort( @outOfOrder );
    
    my @exp = ( qw/01a 03b 20axv 21aiv 100/ );
    
    eq_or_diff( \@inOrder, \@exp, "sort ok" );

}