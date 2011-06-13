#!perl

use strict;
use Tarp::GenPK;

use Test::More tests => 3;

# From 30jul09, re. having problems mathing csv_string entry & with ap01, ap02..

use File::Copy;
copy "solutions-starter.tas", "t/projs"
    or die "could not copy solutions-starter.tas to t/ignorecase: $!, stopped";

diag "copied solutions-starter.tas";

chdir "t/projs" or die "Could not chdir to t/ignorecase: $!, stopped";

my $gpk = Tarp::GenPK->new();

ok( $gpk->style()->load( "solutions-starter.tas" ), "loaded style" )
    or diag "could not load style: " . $gpk->style()->errStr();

eval { $gpk->readCorrelation() };

ok( ! $@, "readCorrelation" ) or diag "Could not read the correlation:\n$@";

#use Data::Dumper;
is_deeply( $gpk->pickups(), {
          'CC' => {
                    '4c_12' => '4c04CC.tex',
                    '6et_10' => '6et04CC.tex'
                  },
          '07ap01' => {
                        '4c_9' => '4c0406ap.tex'
                      },
          '01' => {
                    '6et' => '6et0401.tex',
                    '4c' => '4c0402.tex',
                    'new' => '(virtual)'
                  },
          'TF' => {
                    '4c_17' => '4c04TF.tex'
                  },
          '05' => {
                    '4c_3' => '4c0403.tex',
                    'new' => '(virtual)',
                    '6et_5' => '6et0405.tex'
                  },
          'PP' => {
                    '4c_14' => '4c0304.tex',
                    'new' => '(virtual)',
                    '4c_7' => '4c0406.tex',
                    '6et_11' => '6et04PP.tex',
                    '4c_13' => '4c04PP.tex'
                  },
          '04' => {
                    '4c_5' => '4c0405.tex',
                    '6et_4' => '6et0404.tex',
                    'new' => '(virtual)'
                  },
          '02' => {
                    '4c_3' => '4c0403.tex',
                    '6et_2' => '6et0402.tex',
                    'new' => '(virtual)'
                  },
          '01ap01' => {
                        '4c_2' => '4c0402ap.tex'
                      },
          '07' => {
                    '6et_7' => '6et0407.tex',
                    '4c_7' => '4c0406.tex',
                    'new' => '(virtual)',
                    '4c_8' => '4c04R.tex'
                  },
          '08' => {
                    '4c_10' => '4c0407.tex',
                    'new' => '(virtual)',
                    '6et_8' => '6et0408.tex'
                  },
          '03' => {
                    '4c_4' => '4c0208.tex',
                    '6et_3' => '6et0403.tex',
                    '4c_3' => '4c0403.tex',
                    'new' => '(virtual)'
                  },
          'R' => {
                   '4c_16' => '4c02PP.tex',
                   '6et_12' => '6et04R.tex',
                   'new' => '(virtual)',
                   '4c_15' => '4c02R.tex',
                   '4c_8' => '4c04R.tex'
                 },
          '06' => {
                    '4c_6' => '4c0404.tex',
                    '4c_5' => '4c0405.tex',
                    'new' => '(virtual)',
                    '6et_6' => '6et0406.tex'
                  },
          '09' => {
                    '4c_4' => '4c0208.tex',
                    'new' => '(virtual)',
                    '6et_9' => '6et0409.tex',
                    '4c_11' => '4c0408.tex'
                  }
        }, "pickups ok" );

unlink "solutions-starter.tas";

