#!/usr/bin/perl -w
use strict;
use Test::More tests => 4;

use Tarp::GenTex::App;
use Tarp::Config;

# Turn warnings fatal.

my %msgs = (
    NO_ERR    => '', # No error

# Errors specific to tagentex:
    INV_COMB    => qr/Invalid combination of options/,
    NO_TEMPLATE => qr/Could not open.*template/,
    
# Errors common to most Toolkit apps
    NO_TAS      => qr/TAS file not specified and no suitable default/,
    OPEN_TAS    => qr/File.*\.tas' does not exist/,
    OPEN        => qr/Could not open/,
);

my @expErrors = @msgs{
    'NO_TAS',           # c01
    'OPEN_TAS',         # c02
    'INV_COMB',         # c03
    'NO_TEMPLATE',      # c04
};

# my @expErrors = ();

my $case = 1;

sub runTest {
    my $tcd = "c" . sprintf "%02d", $case;

    chdir ( $tcd ) or die "Could not cd to $tcd: $!, stopped";
    
    my $errOut = '';
    
    open( ERR, '>', \$errOut );
    
    eval 'Tarp::GenTex::App->run()';
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

chdir ( "t/t32" ) or die "Could not open t/t31: $!";

@ARGV = ( 'foo' );

runTest(); # c01

@ARGV = ( qw/--tas=style.tas foo/ );

runTest(); # c02

# c04: Missing --master-templates option
@ARGV = ( qw/--template-dir="foo" bar/ ); 

runTest(); # c03

# c04:

if ( -e File::Spec->catfile(
        Tarp::Config->ResourceDir(),
        "templates", "ms_template.tex" ) )  {
    # If the template file exists, running this should
    # not result in an error.
    $expErrors[ 3 ] = $msgs{NO_ERR};
}
# Otherwise, there should be an error saying that the
# ms_template.tex could not be found.

@ARGV = ( qw/--master-templates foo.pklist/ );

runTest(); # c05