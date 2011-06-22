#!/usr/bin/perl -w

use strict;

use Test::More tests => 38;
use Test::Differences;

use Tarp::TAS;

$Carp::Verbose = 1;

chdir "t/t10" or die "Could not chdir to t/t10: $!, stopped";

is( Tarp::TAS->errStr, '', "No initial errStr" );

eval { Tarp::TAS->readString() };

ok( $@, "errStr - readString no arg" );

my $tas;
ok ( $tas = Tarp::TAS->readString( '' ), "read empty string" );
ok( ! Tarp::TAS->errStr, "errStr not set" );

is_deeply( $tas, {}, "empty string empty tas" );

my $simple = <<END_OF_TAS;
entry = value
END_OF_TAS

$tas = Tarp::TAS->readString( $simple );

ok( defined $tas->{entry}, "Loaded entry" );
is_deeply( $tas->{entry}, [ "value", {} ], "entry is value" );
is_deeply( $tas->values( "entry" ), [ "value", {} ], "same with values method" );

ok( ! $tas->values( "doh" ), "values says doh not there" );
ok( ! $tas->values( "doh::bla" ), "values says doh::bla not there" );

is ( keys %$tas, 1, "Still only one entry" );

is( $tas->writeString(), $simple, "simple in is simple out" );

$tas = Tarp::TAS->read( "foo.tas" ) or die Tarp::TAS->errStr() . "\n";

my $Nk = 0 + grep { ! /^_/ } keys %$tas;
is( $Nk, 1, "One entry" );

is( 0 + @{$tas->{foo}}, 7, "With seven values" );

# use Data::Dumper;
# print Dumper $tas->{foo};

my $exp = [
    'foo#$BAR$$BAT$',
    'foofee',
    'foo$BAR$$BAR$$BAR$',
    'foo$BAT$$BAT$$BAT$',
    '$BAR$\\ $BAR$\\ $BAR$\\ \\"hello\\"',
    '"$BAR$ $BAR$ $BAR$"',
    {
      'BAR' => [
                 'pig',
                 'pat',
                 'paste',
                 {}
               ],
      'BAT' => [
                 'bat$ty$\\ $ty$',
                 {
                   'ty' => [
                             'ty',
                             'boo',
                             {}
                           ]
                 }
               ],
    }
];

is_deeply( $tas->{foo}, $exp, "Data structure ok" );

my $ierp = $tas->interpolate( "foo" );

# use Data::Dumper;
# print Dumper $ierp;
my $ierpExp = [
    'foo#pigbatty\\ boo',
    'foofee',
    'foopigpatpaste',
    'foobatty\\ boobatty\\ boobatty\\ boo',
    'pig\\ pat\\ paste\\ \\"hello\\"',
    '"pig pat paste"'
];

eq_or_diff( $ierp, $ierpExp, "interp OK" );

my $nc = $tas->interpolate( "foo", "(?:<%s>%s)", '$VAR$', '$VAL$' );
my $ncExp = [
    'foo#(?:<BAR>pig)(?:<BAT>bat(?:<ty>ty)\\ (?:<ty>boo))',
    'foofee',
    'foo(?:<BAR>pig)(?:<BAR>pat)(?:<BAR>paste)',
    'foo(?:<BAT>bat(?:<ty>ty)\\ (?:<ty>boo))(?:<BAT>bat(?:<ty>ty)\\ (?:<ty>boo))(?:<BAT>bat(?:<ty>ty)\\ (?:<ty>boo))',
    '(?:<BAR>pig)\\ (?:<BAR>pat)\\ (?:<BAR>paste)\\ \\"hello\\"',
    '"(?:<BAR>pig) (?:<BAR>pat) (?:<BAR>paste)"'
];
  
eq_or_diff( $nc, $ncExp, "Named capture" );

$tas->write( "out.tas" );

ok( $tas = Tarp::TAS->read( "out.tas" ) )
    or diag "Error while reading out.tas: " . Tarp::TAS->errStr();

is_deeply( $tas->{foo}, $exp, "Data structure ok" );

# Create bar.tas from scratch

my $bar = Tarp::TAS->new();

$bar->values( "value1" );

ok( ! defined $bar->{value1}, "not adding new entry" );

$bar->{value1} = [{}];

my $r = $bar->values( "value1" );

$r = $bar->values( "value1" );
@$r = ( "a", {} );

is_deeply( $bar->{value1}, [ 'a', {} ], "New entry value1" );

ok( $tas = Tarp::TAS->readString( <<END_OF_TAS
foo = a\$b\$c
foo::b = c\$d\$e
foo::b::d= 1
END_OF_TAS
), "read string" );

is_deeply( [ $tas->entries() ], ["foo", "foo::b", "foo::b::d"], "three level entries" );

ok( ! Tarp::TAS->readString( <<END_OF_TAS
_entry = value
END_OF_TAS
), "entry starts with underscore" );

like( $tas->errStr(), qr/badly formed entry/, "msg: badly formed entry" );

ok( ! Tarp::TAS->readString( <<END_OF_TAS
entry[0]::subentry = value
END_OF_TAS
), "orphan entry" );

like( $tas->errStr(), qr/'entry\[0\]' referenced in 'entry\[0\]::subentry' not found/, "msg: orphan" );

ok( $tas = Tarp::TAS->readString( <<END_OF_TAS
entry[1] = value
END_OF_TAS
), "entry ends with subscript" ) or diag $tas->errStr();

ok( exists $tas->{entry_1_}, "exists entry_1_" );

eval { $tas->entries() };

ok( ! $@, "entries ok before badentry" );

$tas->{badentry} = [];

eval { $tas->entries() };

ok( $@, "bad entry killed it" );

like( $@, qr/bad tas data structure/i, "bad tas data structure" );

delete $tas->{badentry};

ok( ! $tas->values( "imaginary::ENTRY::here" ), "imaginary entry" );

my @e;
eval { @e = $tas->entries() };

ok( ! $@, "list after imaginary entry" );

ok( ! Tarp::TAS->readString( <<END_OF_TAS
entry = value1 \\
        value2 \\

entry2 = value3

END_OF_TAS
), "trailing backslash" );

like( $tas->errStr(), qr/trailing backslash/, "msg: orphan" );

ok( ! Tarp::TAS->readString( <<END_OF_TAS
entry = value1
entry = value2

END_OF_TAS
), "duplicate entry" );

like( $tas->errStr(), qr/duplicate entry/i, "msg: duplicate entry" );

