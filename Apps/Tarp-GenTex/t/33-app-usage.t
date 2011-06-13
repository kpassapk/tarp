#!/usr/bin/perl -w
use strict;
use Test::More tests => 5;

# Because the usage messages call exit(),
# I can't just call App->run() in Perl without the
# thing exiting the test script as well, so I am executing
# external commands and capturing either the standard output
# or standard error.

# Capturing standard error

use File::Spec;
my $null = File::Spec->devnull();
use Data::Dumper;

open( PH, "perl bin/tagentex 2>&1 1>$null |" )
    or die "Error loading tagentex: $!";

like( <PH>, qr/Incorrect number of arguments/, "incorrect number of args" );

open( PH, "perl bin/tagentex --gen-tas foo 2>&1 1>$null |" )
    or die "Error loading tagentex!";

like( <PH>, qr/too many arguments/i, "too many args" );

# Capturing standard out

open(PH, "perl bin/tagentex --help 2>$null |")
    or die "Error loading tagentex!";

like( <PH>, qr/Usage/, "usage msg" );

use Tarp;

open(PH, "perl bin/tagentex --version 2>$null |")
    or die "Error loading tagentex!";

my $version_msg = <PH>;

ok( $version_msg =~ /tagentex v(\d\.\d{2,})/, "verison msg format" )
    or diag "Got version message: $version_msg";

SKIP: {
    skip( "no version number", 1 ) unless $1;
    ok( $1 >= $Tarp::VERSION, "version is Tarp version" )
        or diag "Need to set \$VERSION in GenTex.pm to $Tarp::VERSION";
}
