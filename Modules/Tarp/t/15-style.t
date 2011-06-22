#!/usr/bin/perl -w

use strict;
use Test::More tests => 60;
use Tarp::Style;
use Tarp::Test::Files;

$Carp::Verbose = 1;

chdir "t/t15" or die "Could not chdir to 't/t15': $!, stopped";

my $sty  = Tarp::Style->new();

ok( ! $sty->entries(), "initially no entries" );
ok( ! Tarp::TAS->errStr, "errStr not set" );

eval { $sty->loadString() };

ok( $@, "errStr - readString no arg" );

ok ( ! $sty->loadString( '' ), "cannot read empty string" );
like( $sty->errStr(), qr/does not end with a newline/, "because doesn't end with newline" );

#use Data::Dumper;
#print Dumper $sty->saveString();

ok( $sty->loadString( $sty->saveString() ), "saved and loaded empty style" )
    or diag $sty->errStr();

ok( ! $sty->entries(), "No entries after saveload" );

my @v = $sty->values( "foo", "bar" );
is_deeply( \@v, [ "bar" ], "values set returns" );

#use Data::Dump qw/dump/;
#dump $sty->values( "foo" );

is_deeply( [ $sty->values( "foo" ) ], [ "bar" ], "values get" );

eval { $sty->values( "foo::bat::mog", "mog" ) };

ok( $@, "values set with nonexistent parent" );
like( $@, qr/'foo::bat' does not exist/, "err nonexistent parent" );

$sty->values( "foo", "bar\$bat\$", "bat" );

is_deeply( [ $sty->values( "foo" ) ], [
          'bar$bat$',
          'bat'
        ], "values get" );

is_deeply( [ $sty->values( "foo::bat" ) ], [ ".+" ], "values get 2" );

is_deeply( [ $sty->interpolate( "foo", Tarp::Style->INLINE ) ], [ 'bar.+', 'bat' ], "interpolate" );
is_deeply( [ $sty->interpolate( "foo", Tarp::Style->PARENS ) ], [ 'bar(.+)', 'bat' ], "interpolate" );
is_deeply( [ $sty->interpolate( "foo", Tarp::Style->NCBUFS) ], [ 'bar(?<bat>.+)', 'bat' ], "interpolate" );
is_deeply( [ $sty->interpolate( "foo" ) ], [ 'bar(?<bat>.+)', 'bat' ], "interpolate" );

like( 'barf', ( $sty->qr("foo") )[0], "qr" );
like( 'bat', ( $sty->qr("foo") )[1], "qr" );

ok( ! $sty->load(), "Could not load default" );
is_deeply( [ $sty->values( "foo" ) ], [
          'bar$bat$',
          'bat'
        ], "values get after failed load" );
is_deeply( [ $sty->values( "foo::bat" ) ], [ ".+" ], "values get 2 after failed load" );
like( 'barf', ( $sty->qr("foo") )[0], "qr after failed load" );
like( 'bat', ( $sty->qr("foo") )[1], "qr2 after failed load" );

like( $sty->errStr(), qr/no suitable default/, "No default" );

ok( $sty->save( "TASfile" ), "save to 'TASfile'" );
ok( $sty->load(), "Loaded a default" );
is( $sty->file(), "TASfile", "Loaded the right default" );
unlink 'TASfile';

like( 'barf', ( $sty->qr("foo") )[0], "qr after good load" );
like( 'bat', ( $sty->qr("foo") )[1], "qr2 after good load" );

is_deeply( [ $sty->vars() ], [ qw/bat/ ], "variables" );
is_deeply( [ $sty->vars( "foo" ) ], [ qw/bat/ ], "variables in foo");
is_deeply( [ $sty->vars( "foo", 0 ) ], [ qw/bat/ ], "variables in foo entry zero");
is_deeply( [ $sty->vars( "foo", 1 ) ], [], "variables in foo entry one");

# values with a space
$sty->values( "foo", "\"bar \$bat\$\"" );
like( 'bar f', ( $sty->qr("foo") )[0], "qr with quotes" );

my $sty2 = Tarp::Style->new();
$sty2->loadString( <<END_OF_TAS

foo = a.*\$var\$.*c
foo::var = b
foo::var::WORD = 1
foo::var::CSENS = 0

END_OF_TAS

) or diag $sty->errStr();

like( 'pa B c t',  ( $sty2->qr( "foo" ) )[0], "qr with CSENS turned off" );

ok( $sty->m( "foo", "bar f" ), "m()" );

is_deeply( $sty->mParens(), [ 'bar f', 'f'], "mParens" );
is_deeply( $sty->mVars(), { 'bat' => [ 'f' ] }, "mVars" );
is_deeply( $sty->mPos(), { 'bat' => [ 4 ] }, "mPos" );

ok( $sty->save( "TASfile.txt" ), "Saved to 'TASfile.txt'" )
    or diag $sty->errStr();
$sty->file('');
ok( $sty->load(), "Loaded a default" )
    or diag $sty->errStr();
is( $sty->file(), "TASfile.txt", "Loaded the right default" );
unlink 'TASfile.txt';

ok( $sty->save( "TASfile.tas" ), "Saved to 'TASfile.tas'" )
    or diag $sty->errStr();
$sty->file('');
ok( $sty->load(), "Loaded a default" )
    or diag $sty->errStr();
is( $sty->file(), "TASfile.tas", "Loaded the right default" );
unlink 'TASfile.tas';

ok( ! $sty->load( "nonexistent.tas" ), "Nonexistent returns false" );

like( $sty->errStr(), qr/does not exist/, "nonexistent.tas error msg" );

ok( ! $sty->load( "empty.tas" ) );

like( $sty->errStr(), qr/does not end with a newline/, "Trailing newline" );

ok( $sty->load( "minimal.tas" ), "Minimal file load" );

ok( $sty->load( "good.tas" ), "good.tas" );

# Test the files from t10

ok( $sty->load( "foo.tas" ), "foo.tas from t10 loads" );

my @qrs = $sty->qr( "foo" );

is( @qrs + 0, 6, "qrs has six entries" );

# Test a couple of files with errors, compare the error message with
# what we were expecting

ok( ! $sty->load( "bad.tas" ), "bad.tas" );

sub fileTest {
    my $sty = shift;
    my $testDir = shift;

    chdir $testDir or die "Could not chdir to '$testDir': $!, stoppped";

    open ERR, ">out/errout.txt"
        or die "Could not open 'errout.txt' for writing: $!, stopped";
    print ERR $sty->errStr();
    close ERR;

    like( $sty->errStr(), qr/Regexp Error/, "$testDir.tas regexp error" );
    Tarp::Test::Files->asExpected( "errout.txt", "$testDir.tas err msg" );
    
    chdir "..";
}

&fileTest( $sty, "bad" );

ok( ! $sty->load( "ugly.tas" ), "ugly.tas" );

&fileTest( $sty, "ugly" );

