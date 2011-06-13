#!/usr/bin/perl -w
use strict;

use Test::More tests => 4;
use Tarp::MasterAlloc::App;

# Turn warnings fatal.
BEGIN { $SIG{'__WARN__'} = sub { die $_[0]; } }

# Delete output files after performing each test
my $CLEAN_UP = 1;

my %msgs = (
    'NO_OUT'  => qr/The.*option requires an output file/,
    'NO_CH'   => qr/No changes.*required/,
# Errors common to most Toolkit apps
    NO_ERR    => '', # No error
    BAD_ARGC  => qr/Incorrect number of arguments/,
    NO_TAS     => qr/TAS file not specified and default.*not found/,
    OPEN       => qr/Could not open/,
);

my @expErrors = @msgs{
    'NO_ERR', # c01
    'NO_OUT', # c02
    'NO_ERR', # c03
    'NO_CH',  # c04
};

my $case = 1;

sub runTest {
    my $tcd = "c" . sprintf "%02d", $case;

    chdir ( $tcd ) or die "Could not cd to $tcd: $!, stopped";
    
    my $errOut = '';
    
    open( ERR, '>', \$errOut );
    
    eval 'Tarp::MasterAlloc::App->run()';
    print ERR $@;
    close ERR;

    my $expError = $expErrors[ $case - 1 ];
    
    if ( $expError ) {
        like( $errOut, $expError, "Case $case error" );
    } else {
        ok( ! $errOut, "Case $case produced no error" )
            or diag "No error expected, but this was produced:\n$errOut";
    }

    $case++;    
    chdir ( ".." );    
}

chdir ( "t/t51" ) or die "Could not chdir to t50: $!, stopped";

@ARGV = qw/--tas=..\/TASfile foo.tex/;

my $gulp;
open GULP, '>', \$gulp;
select GULP;

&runTest(); # c01

# Missing an output file: Should be like the next test case
@ARGV = qw/--tas=..\/TASfile --next-master=1 foo.tex/;

&runTest(); # c02

# Arguments OK
@ARGV = qw/--tas=..\/TASfile --next-master=1 --out=bar.tex foo.tex/;

&runTest(); # c03

unlink "c03/bar.tex" if $CLEAN_UP;

@ARGV = qw/--tas=..\/TASfile --fix --out=bat.tex foo.tex/;

&runTest(); # c04




