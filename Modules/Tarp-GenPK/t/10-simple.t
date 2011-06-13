#!/usr/bin/perl -w

BEGIN {
    use Cwd;
    our $dir = cwd;
}

use lib $dir;
use strict;
use Test::More tests => 39;

use Tarp::GenPK;
use Carp;

$SIG{__DIE__} = sub {
    confess @_
};

my @PKS = (
    qw/0201 0202 0203 0204 0205 0206
    0207 0208 02cc 02pp 02r 02tf/
);

@PKS = map { "4c" . $_ } @PKS;

chdir "t/t10" or die "Could not cd to t/t10: $!, stoppped";

# Tarp::Style->debug( 1 );

Tarp::Style->import( "MyStyle" );

my $gpk = Tarp::GenPK->new();

eval { $gpk->readCorrelation() };

ok( ! $@, "readCorrelation success" ) or diag $@;

my $pickups = $gpk->pickups();

use Data::Dumper;
# print Dumper $pickups;
my $expPickups = {
          'CC' => {
                    '3c3_5' => '3c02cc.tex',
                    '6et_11' => '6et02cc.tex'
                  },
          '01' => {
                    '6et' => '6et0201.tex',
                    'new' => '(virtual)'
                  },
          'TF' => {
                    '6et_16' => '6et02tf.tex'
                  },
          '05' => {
                    'ECET_3' => 'ECET0301.tex',
                    '3c3_3' => '3c0205.tex',
                    'new' => '(virtual)',
                    '6et_2' => '6et0202.tex',
                    'ECET_2' => 'ECET0106.tex',
                    '6et_5' => '6et0206.tex'
                  },
          'PP' => {
                    '6et_12' => '6et02pp.tex',
                    '3c3_6' => '3c02fps.tex',
                    '6et_13' => '6et03pp.tex'
                  },
          '04' => {
                    '3c3_2' => '3c0204.tex',
                    'ECET' => 'ECET0105.tex',
                    '6et_4' => '6et0205.tex',
                    'new' => '(virtual)'
                  },
          '02' => {
                    '6et_2' => '6et0202.tex',
                    'new' => '(virtual)',
                    '3c3' => '3c0202.tex'
                  },
          '07' => {
                    'new' => '(virtual)',
                    '6et_8' => '6et0208.tex'
                  },
          '03' => {
                    '6et_3' => '6et0203.tex',
                    'new' => '(virtual)'
                  },
          '08' => {
                    '3c3_4' => '3c0209.tex',
                    'new' => '(virtual)',
                    '6et_10' => '6et0409.tex',
                    '6et_9' => '6et0403.tex'
                  },
          'R' => {
                   '6et_15' => '6et04r.tex',
                   '6et_14' => '6et02r.tex',
                   '3c3_7' => '3c02r.tex',
                   'ECET_4' => 'ECET02r.tex'
                 },
          '06' => {
                    '6et_7' => '6et1110.tex',
                    'new' => '(virtual)',
                    '6et_6' => '6et0207.tex'
                  }
        };

is_deeply( $pickups, $expPickups, "pickups look okay" );

my @books = $gpk->pickupBooks();
my $expBooks = [
          'ECET',
          '6et',
          '3c3'
        ];
is_deeply( \@books, $expBooks, "books look okay" );

# print Dumper \@books;

chdir "out";

# Create in current directory
foreach ( @PKS ) {
    ok ( ! -e "$_.pklist", "$_ does not exist" );
}

$gpk->createLists();

foreach ( @PKS ) {
    ok ( -e "$_.pklist", "$_ exists" );
}

chdir "..";

use Tarp::Test::Files;

foreach ( @PKS ) {
    Tarp::Test::Files->asExpected( "$_.pklist" );
}
