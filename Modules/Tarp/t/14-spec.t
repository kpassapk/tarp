#!/usr/bin/perl -w

use Tarp::TAS;
use Tarp::TAS::Spec;

use Test::More tests => 14;
use Tarp::Test::Files;

use Carp;
$Carp::Verbose = 1;

chdir "t/t14" or die "Could not chdir to t/t14: $!, stopped";

my $tas = Tarp::TAS->read( "spec.tas" );
my $case = 1;

sub runTest {
    my %c = @_;
    my $dir = "c" . sprintf "%02d", $case++;
    chdir $dir or die "Could not chdir to $dir: $!, stopped";
    open ERR, ">out/errout.txt" or die "Could not open out/errout.txt for writing: $!, stopped";
    ok( ! Tarp::TAS::Spec->check( $tas, %c ), "error produced" );
    print ERR Tarp::TAS::Spec->errStr();
    close ERR;
    Tarp::Test::Files->asExpected( "errout.txt", "$dir output" );
    chdir "..";
}

&runTest( # c01
    foo => Tarp::TAS::Spec->simple(
        allowEmpty   => 0,
        requireVars => [ qw/b/ ], # for all values
        allowMultiple => '' )
);

&runTest( # c02
    bar => [
        sub {
            my $v = shift;
            my $n = shift;
            @$v != $n ? ( "entry must have $n values" ) : ();
        }, 3 ],
);

&runTest( # c03
    bat => sub { @_ && $_[0] =~ /bla/ ? () : ( "Must contain 'bla'" ) },
);

&runTest( # c04
    fooey => {}
);

my $multi = Tarp::TAS::Spec->multi(
        Tarp::TAS::Spec->simple( allowEmpty => 0 ),
        Tarp::TAS::Spec->simple( allowMultiple => 0 ),
    );

&runTest( # c05
    bar => $multi,
);

&runTest( # c06
    bat => $multi,
);

# note this doesn't really exist, but barf[0] thru barf[3] do.

&runTest( # c07
    bat => $multi,
    barf => Tarp::TAS::Spec->exists(), 
);
