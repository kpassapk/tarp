#!/usr/bin/perl -w
use strict;

BEGIN {
    use Cwd;
    use File::Spec;
    $ENV{TECHARTS_TOOLKIT_DIR} = File::Spec->catfile( cwd, "t" );
}

use Test::More tests => 14;

use Tarp::LaTeXcombine::App;

my %msgs = (
    NO_ERR    => '', # No error
    BAD_PK    => qr/Pickup.*must be given as --pk=fileID;file.tex/,
    BAD_SEQ   => qr/Sequence.*must be a positive integer/,         
    DUP_ID    => qr/Cannot have duplicate pickup fileIDs/,
    NOT_PREAM => qr/Cannot get preamble/,                           
    
    PARSE     => qr/Pickup lists should have.*fields/,
    GAP       => qr/Gap in input exercises/,                         
    DUP_INST  => qr/Duplicate instruction/,                         
    INV_PK    => qr/pickup instruction error/,

    OPEN      => qr/Could not open/,                                
    NA_SEQ    => qr/Sequence.*does not exist/,
    NOT_FOUND => qr/instruction error.*not found/,                           
    LEAF      => qr/instruction error.*contains parts or subparts/,           
);


my @expErrors = @msgs{
    'NOT_FOUND', # c01
    'LEAF',      # c02
    'GAP',       # c03
    'NO_ERR',    # c04
    'DUP_INST',  # c05
    'INV_PK',    # c06
    'INV_PK',    # C07
    'BAD_PK',    # c08
    'BAD_SEQ',   # c09
    'DUP_ID',    # c10
    'NOT_PREAM', # c11
    'OPEN',      # c12
    'PARSE',     # c13
    'NA_SEQ',    # c14
};

# my @expErrors = ();

my $case = 1;

sub runTest {
    my $tcd = "c" . sprintf "%02d", $case;

    chdir ( $tcd ) or die "Could not cd to $tcd: $!, stopped";
    
    my $errOut = '';
    
    open( ERR, '>', \$errOut );
    
    eval 'Tarp::LaTeXcombine::App->run()';
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

chdir ( "t/t31" ) or die "Could not open t/t31: $!";

my @all = qw/ --tas=..\/TASfile.txt --silent /;
@ARGV = ( @all, qw/--pk=foo;in\/foo.tex --chunk=out\/dataout.chunk --skel=out\/dataout.skel datain.pklist/ );

runTest(); # c01: not found

# App.pm wipes out ARGV, so we have to reset it
@ARGV = ( @all, qw/ --pk=foo;in\/foo.tex --chunk=out\/dataout.chunk --skel=out\/dataout.skel datain.pklist/ );

runTest(); # c02

@ARGV = ( @all, qw/ --pk=foo;in\/foo.tex --chunk=out\/dataout.chunk --skel=out\/dataout.skel datain.pklist/ );

runTest(); # c03

@ARGV = ( @all, qw/ --pk=foo;in\/foo.tex --chunk=out\/dataout.chunk --skel=out\/dataout.skel datain.pklist/ );

runTest(); # c04: no error

unlink "c04/out/dataout.chunk" or die "Could not remove c04/out/dataout.chunk: $!, stopped";
unlink "c04/out/dataout.skel" or die "Could not remove c04/out/dataout.skel: $!, stopped";

@ARGV = ( @all, qw/--pk=foo;in\/foo.tex  datain.pklist/ );

runTest(); # c05

@ARGV = ( @all, qw/--pk=foo;in\/foo.tex datain.pklist/ );

runTest(); # c06

@ARGV = ( @all, qw/--pk=foo;in\/foo.tex datain.pklist/ );

runTest(); # c07

@ARGV = ( @all, qw/ --pk=foobar datain.pklist/ );

runTest(); # c08

@ARGV = ( @all, qw/ --pk=foo;in\/foo.tex;foo datain.pklist/ );

runTest(); # c09

@ARGV = ( @all, qw/ --pk=foo;bar --pk=foo;bat datain.pklist/ );

runTest(); # c10

@ARGV = ( @all, qw/ --preamble-from=bar --pk="foo;in\/foo.tex" datain.pklist/ );
runTest(); # c11

@ARGV = ( @all, qw/ --pk=foo;in\/foo.tex nonexistent.pklist/ );

runTest(); # c12

@ARGV = ( @all, qw/ --pk=foo;in\/foo.tex datain.pklist/ );

runTest(); # c13

@ARGV = ( @all, qw/ --pk=foo;in\/foo.tex;1 datain.pklist/ );

runTest(); # c14
