#!/usr/bin/perl -w
use strict;
use Cwd;

use Test::More tests => 12;

use Tarp::PullCSV::App;

# Turn warnings fatal.
BEGIN { $SIG{'__WARN__'} = sub { die $_[0]; } }

my %msgs = (
    NO_ERR          => '', # No error
    SEQ_MISMATCH    => qr/numbering sequence\(s\) found.*but.*section name\(s\) given/,
    NA_FILE         => qr/File.*does not exist/,
    AUTO_COL        => qr/Warning:.*column requires an argument/,
    NO_MACROS       => qr/Exercise.*contains no macros/,
    NO_MASTERS      => qr/Macro\(s\).*contain no master number refs/,
    MULT_MASTERS    => qr/Exercise.*has multiple masters.*across different macros/,
    MULT_MS_MACRO   => qr/Macro in.*has multiple master refs/,
    MS_MULT_MACRO   => qr/Master.*found in more than one.*macro/,
    NO_COLS         => qr/No columns for CSV file!/,
    NA_PLUGDIR      => qr/Plugin directory does not exist/,
    XTR_ERROR       => qr/LaTeXtract didn't like a tag/,
);

my @expErrors = @msgs{
    'SEQ_MISMATCH',  # c01
    'NA_FILE',       # c02
    'AUTO_COL',      # c03
    'AUTO_COL',      # c04
    'AUTO_COL',      # c05
    'NO_MACROS',     # c06
    'NO_MASTERS',    # c07
    'MULT_MASTERS',  # c08
    'MULT_MS_MACRO', # c09
    'MS_MULT_MACRO', # c10
    'NA_PLUGDIR',    # c11
    'XTR_ERROR',     # c12
};

my $case = 1;

sub runTest {
    my $tcd = "c" . sprintf "%02d", $case;
    chdir ( $tcd ) or die "Could not cd to $tcd: $!, stopped";
    
    my $errOut = '';
    
    open( ERR, '>', \$errOut );
    
    eval 'Tarp::PullCSV::App->run()';
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

chdir ( "t/t41" ) or die "Could not open t/t41: $!";

$ENV{TECHARTS_TOOLKIT_DIR} = cwd;

# Comment stdout
my $gulp = '';
open( GULP, '>', \$gulp );
select GULP;

my @ARGV_COMMON = (
    "--tas=..\/TASfile.txt",
    "--out=out\/dataout.csv",
);

@ARGV = (
    @ARGV_COMMON,
    "--col=section;foo,bar,bat",
    "in\/foobarbat.tex"
);

runTest(); # c01

@ARGV = (
    @ARGV_COMMON,
    "--col=section;foo,bar,bat",
    "in\/foobarbat.tex"
);

runTest(); # c02

@ARGV = (
    @ARGV_COMMON,
    "--out=out\/dataout.csv",
    "in\/foo.tex"
);

runTest(); # c03

@ARGV = (
    @ARGV_COMMON,
    "--col=book;book",
    "in\/foo.tex"
);

runTest(); # c04

@ARGV = (
    @ARGV_COMMON,
    "--col=book;book",
    "--col=chapter;chapter",
    "in\/foo.tex"
);

runTest(); # c05

@ARGV = (
    @ARGV_COMMON,
    "--col=book;book",
    "--col=chapter;chapter",
    "--col=section;bar,bat",
    "in\/foobarbat.tex"
);
# No macros
runTest(); # c06

@ARGV = (
    @ARGV_COMMON,
    "--tas=..\/TASfile.txt",
    "--out=out\/dataout.csv",
    "--col=book;book",
    "--col=chapter;chapter",
    "--col=section;bar,bat",
    "in\/foobarbat.tex"
);
# No masters
runTest(); # c07

@ARGV = (
    @ARGV_COMMON,
    "--col=book;book",
    "--col=chapter;chapter",
    "--col=section;bar,bat",
    "in\/foobarbat.tex"
);
# Multiple masters
runTest(); # c08

@ARGV = (
    @ARGV_COMMON,
    "--col=book;book",
    "--col=chapter;chapter",
    "--col=section;bar,bat",    
    "in\/foobarbat.tex"
);

runTest(); # c09

@ARGV = (
    @ARGV_COMMON,
    "--col=book;book",
    "--col=chapter;chapter",
    "--col=section;bar,bat",        
    "in\/foobarbat.tex"
);

runTest(); # c10

use File::Spec;
$ENV{TECHARTS_TOOLKIT_DIR} = File::Spec->catfile( cwd , "c11" );

@ARGV = (
    @ARGV_COMMON,
    "in\/foo.tex"
);

# Directory does not exist
runTest(); # c11

$ENV{TECHARTS_TOOLKIT_DIR} = cwd;

@ARGV = (
    @ARGV_COMMON,
    "in\/foobarbat.tex"
);

# in/foo.tex is not LaTeXtractable
runTest(); # 12

