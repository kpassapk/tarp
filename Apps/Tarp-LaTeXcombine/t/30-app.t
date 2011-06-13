#!/usr/bin/perl -w
use strict;

use Test::More tests => 22;

use Tarp::LaTeXcombine::App;
use Tarp::Test::Files;
use File::Copy;

BEGIN {
    use Cwd;
    use File::Spec;
    $ENV{TECHARTS_TOOLKIT_DIR} = File::Spec->catfile( cwd, "t" );
}

my $Debugging = 0; # 1 shows test output
# Tarp::Style->debug( 1 );

sub runTest {
    my $out = '';
    open B, '>', \$out;
    select B;
    Tarp::LaTeXcombine::App->run();
    close B;
    diag $out if $Debugging && length $out;
}

sub check_tas {
	&runTest;
	ok( -e "TASfile.tas", "TASfile.tas exists" );
	move "TASfile.tas", "out";
}

chdir ( "t/t30" ) or die "Could not open t/t30: $!";

my $t = Tarp::Test::Files->new();
$t->generator( [ \&check_tas ] );
@ARGV = ( qw/--gen-tas/ );

$t->case(); # c01

my @ALL = qw/ --tas=..\/TASfile.txt --chunk=out\/dataout.chunk --skel=out\/dataout.skel --silent/;
my $f = "datain.pklist";

$t->generator( [ \&runTest ] );

@ARGV = ( @ALL, qw/ --pk=bar;in\/bar.tex --pk=foo;in\/foo.tex /, $f );

$t->case(); # c02

@ARGV = ( @ALL, qw/ --preamble-from=foo --pk=bar;in\/bar.tex --pk=foo;in\/foo.tex /, $f );

$t->case(); # c03

@ARGV = ( @ALL, qw/ --preamble-from=new --pk=bar;in\/bar.tex --pk=foo;in\/foo.tex /, $f );

$t->case(); # c04

@ARGV = ( @ALL, qw/ --pk=foo;in\/foo.tex /, $f );

$t->case(); # c05

@ARGV = ( @ALL, qw/ --preamble-from=foo --pk=bar;in\/bar.tex --pk=foo;in\/foo.tex /, $f );

$t->case(); # c06

@ARGV = ( @ALL, $f );

$t->case(); # c07

@ARGV = ( @ALL, qw/ --pk=foo;in\/foo.tex /, $f );

$t->case(); # c08

@ARGV = ( @ALL, qw/ --pk=foo;in\/foo.tex /, $f );

$t->case(); # c09

@ARGV = ( @ALL, qw/ --pk=foo;in\/foo.tex /, $f );

$t->case(); # c10

@ARGV = ( @ALL, qw/ --preamble-from=new;foo --pk=foo;in\/foo.tex /, $f );

$t->case() # c11
