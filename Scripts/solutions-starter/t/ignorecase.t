#!perl

use strict;
use Test::More tests => 10;

use File::Copy;

copy "solutions-starter.pl", "t/ignorecase" or die "could not copy solutions-starter.pl to t/ignorecase: $!, stopped";
copy "solutions-starter.tas", "t/ignorecase" or die "could not copy solutions-starter.tas to t/ignorecase: $!, stopped";

diag "Copied scripts & tas file";

chdir "t/ignorecase" or die "Could not chdir to t/ignorecase: $!, stopped";

ok( -e "BOOK-CONFIG.yml", "have book.yml" );

ok( -e "solutions-starter.pl", "script exists" );

system( "perl solutions-starter.pl 2>&1 1>tmpfile" ) == 0
    or die "system solutions-starter.pl failed: $?";

{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/Copied.*3FOO0101.tex/, "stdout 3: copied 3FOO0101.tex" );
    like( $out, qr/Copied.*3foo0102.tex/, "stdout 3: copied 3foo0102.tex" );
    like( $out, qr/Copied.*3BAR0101.tex/, "stdout 3: copied 3BAR0101.tex" );
    like( $out, qr/Copied.*3bar0102.tex/, "stdout 3: copied 3bar0102.tex" );
}

my @pks = ( map( { "1/3foo010$_.tex" } qw/1 2/ ), map( { "1/3bar010$_.tex" } qw/1 2/ ) );

foreach ( @pks ) {
    ok( -e $_, "$_ pickup copied" );
}

unlink map { "solutions-starter.$_" } q/pl tas/;

