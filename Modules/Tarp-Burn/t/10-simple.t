#!/usr/bin/perl -w

use strict;
use Tarp::Burn;
use File::Copy;
use Test::More tests => 9;

chdir "t/t10" or die "Could not chdir to t/t10: $!, stopped";

my $foo = Tarp::Burn->new();

my %xf = (
name => {
    foo => "bat",
    bar => "mog"
} );

$foo->values( qw/foo.txt bar.txt/ );
$foo->bulkXform( %xf );
use Data::Dumper;
is_deeply( [ $foo->values() ], [ 'bat.txt', 'mog.txt' ], "values ok" );

ok ( -e "foo.txt", "foo.txt exists prior to rename" );
ok ( -e "bar.txt", "foo.txt exists prior to rename" );
ok ( ! -e "bat.txt", "bat.txt does not exist prior to rename" );
ok ( ! -e "mog.txt", "mog.txt does not exist prior to rename" );

$foo->bulkRename( %xf );

ok ( ! -e "foo.txt", "foo.txt does not exist after rename" );
ok ( ! -e "bar.txt", "foo.txt does not exist after rename" );
ok ( -e "bat.txt", "bat.txt exists after rename" );
ok ( -e "mog.txt", "mog.txt exists after rename" );

move "bat.txt", "foo.txt";
move "mog.txt", "bar.txt";
