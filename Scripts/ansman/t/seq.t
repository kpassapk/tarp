#!perl

use Test::More tests => 11;
use File::Copy;

copy "ansman.pl",     "t/seq" or die "could not copy ansman.pl to t/seq: $!, stopped";
copy "ansman.tas",    "t/seq" or die "could not copy ansman.tas to t/seq: $!, stopped";

chdir "t/seq" or die "Could not chdir to t/seq: $!, stopped";

ok( ! -e "boo-answers0.tex", "boo-answers0 does not exist" );
ok( ! -e "boo-answers1.tex", "boo-answers1 does not exist" );

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/boo\.tex -> boo-answers0\.tex/, "tut stdout" );
}

ok( -e "boo-answers0.tex", "boo-answers0 exists" );
ok( ! -e "boo-answers1.tex", "boo-answers1 does not exist" );

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/boo\.tex -> boo-answers1\.tex/, "tut stdout" );
}

ok( -e "boo-answers0.tex", "boo-answers0 exists" );
ok( -e "boo-answers1.tex", "boo-answers1 exists" );

system( "perl ansman.pl 2>&1 1>tmpfile" ) == 0
    or die "system expandex.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/all sequences done/, "tut stdout" );
}

move "boo-answers0.tex", "../out"
    or die "Could not move foo-answers.tex to 'out': $!, stopped";

move "boo-answers1.tex", "../out"
    or die "Could not move bar-pp-answers.tex to 'out': $!, stopped";

chdir "..";

use Tarp::Test::Files;

Tarp::Test::Files->asExpected( "boo-answers0.tex" );
Tarp::Test::Files->asExpected( "boo-answers1.tex" );

unlink map { "seq/$_" } qw/ ansman.pl ansman.tas /;
