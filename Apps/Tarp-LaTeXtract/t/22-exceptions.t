#!/usr/bin/perl -w
use strict;

use Tarp::Test::Exceptions;
use Test::More tests => 2;

my %msgs = (
    noError         => '',
    no_tas          => qr/TAS.*no suitable default/,
    read            => qr/File.*does not exist/,
);

my @exp = @msgs{
    'no_tas',
    'read', # c01
};

my $t = Tarp::Test::Exceptions->new();
$t->expected( \@exp );

chdir "t/t22" or die "could not chdir to t/t22: $!, stopped";

use Tarp::LaTeXtract::App;

# Class to test (note we are testing CLASS data)
my $app = "Tarp::LaTeXtract::App";

# foo does not exist, but neither does default .tas file
@ARGV = qw/ foo /;

$t->case( $app, "run()" ); # c01

# default .tas file is there but foo does not exist
@ARGV = qw/ foo /;

$t->case( $app, "run()" ); # c03


