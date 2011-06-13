#!perl

use Test::More tests => 4;
use File::Copy;

copy "ansman.pl",     "t/pp" or die "could not copy ansman.pl to t/pp: $!, stopped";
copy "ansman-pp.tas",    "t/pp" or die "could not copy ansman-pp.tas to t/pp: $!, stopped";

# this one's required even if it's not used in this test
copy "ansman.tas",    "t/pp" or die "could not copy ansman-pp.tas to t/pp: $!, stopped";

chdir "t/pp" or die "Could not chdir to t/pp: $!, stopped";

ok( ! -e "7et07pp-answers.tex", "7et07pp-answers.tex does not exist" );

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/7et07pp\.tex -> 7et07pp-answers\.tex/, "tut stdout" );
}

ok( -e "7et07pp-answers.tex", "7et07pp-answers exists" );

move "7et07pp-answers.tex", "../out"
    or die "Could not move 7et07pp-answers.tex to 'out': $!, stopped";

chdir "..";

use Tarp::Test::Files;

Tarp::Test::Files->asExpected( "7et07pp-answers.tex" );

unlink map { "pp/$_" } qw/ ansman.pl ansman.tas ansman-pp.tas /;
