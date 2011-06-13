#!perl

use Test::More tests => 14;
use File::Copy;

copy "ansman.pl",     "t/r" or die "could not copy ansman.pl to t/r: $!, stopped";
copy "ansman.tas",    "t/r" or die "could not copy ansman-r.tas to t/r: $!, stopped";

chdir "t/r" or die "Could not chdir to t/r: $!, stopped";

ok( ! -e "7et07r-answers0.tex", "7et07r-answers0.tex does not exist" );
ok( ! -e "7et07r-answers1.tex", "7et07r-answers1.tex does not exist" );
ok( ! -e "7et07r-answers2.tex", "7et07r-answers2.tex does not exist" );
ok( ! -e "7et07r-answers3.tex", "7et07r-answers3.tex does not exist" );

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/7et07r\.tex -> 7et07r-answers1\.tex/, "stdout 1" );
}

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/7et07r\.tex -> 7et07r-answers2\.tex/, "stdout 2" );
}

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/7et07r\.tex -> 7et07r-answers3\.tex/, "stdout 3" );
}

ok( ! -e "7et07r-answers0.tex", "7et07r-answers0 exists" );
ok( -e "7et07r-answers1.tex", "7et07r-answers1 exists" );
ok( -e "7et07r-answers2.tex", "7et07r-answers2 exists" );
ok( -e "7et07r-answers3.tex", "7et07r-answers3 exists" );

move "7et07r-answers1.tex", "../out"
    or die "Could not move 7et07r-answers1.tex to 'out': $!, stopped";
move "7et07r-answers2.tex", "../out"
    or die "Could not move 7et07r-answers2.tex to 'out': $!, stopped";
move "7et07r-answers3.tex", "../out"
    or die "Could not move 7et07r-answers3.tex to 'out': $!, stopped";

chdir "..";

use Tarp::Test::Files;

Tarp::Test::Files->asExpected( "7et07r-answers1.tex" );
Tarp::Test::Files->asExpected( "7et07r-answers2.tex" );
Tarp::Test::Files->asExpected( "7et07r-answers3.tex" );

unlink map { "r/$_" } qw/ ansman.pl ansman.tas /;
