#!perl

use Test::More tests => 8;
use File::Copy;

copy "ansman.pl",     "t" or die "could not copy ansman.pl to t: $!, stopped";
copy "ansman.tas",    "t" or die "could not copy ansman.tas to t: $!, stopped";
copy "ansman-pp.tas", "t" or die "could not copy ansman.tas to t: $!, stopped";

chdir "t" or die "Could not chdir to t: $!, stopped";

ok( ! -e "foo-answers.tex", "foo-answers does not exist" );
ok( ! -e "bar-pp-answers.tex", "bar-pp-answers does not exist" );

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/foo\.tex -> foo-answers\.tex/, "tut stdout" );
    like( $out, qr/bar-pp\.tex -> bar-pp-answers\.tex/, "tut stdout" );
}

ok( -e "foo-answers.tex", "foo-answers exists" );
ok( -e "bar-pp-answers.tex", "bar-pp-answers exists" );

move "foo-answers.tex", "out"
    or die "Could not move foo-answers.tex to 'out': $!, stopped";

move "bar-pp-answers.tex", "out"
    or die "Could not move bar-pp-answers.tex to 'out': $!, stopped";

use Tarp::Test::Files;

Tarp::Test::Files->asExpected( "foo-answers.tex" );
Tarp::Test::Files->asExpected( "bar-pp-answers.tex" );

unlink qw/ ansman.pl ansman.tas /;