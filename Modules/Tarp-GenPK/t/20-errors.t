#!/usr/bin/perl -w

use strict;
use Tarp::GenPK;

use Test::More tests => 6;

chdir "t/t20" or die "Could not chdir to t/t20: $!";

my $gpk = Tarp::GenPK->new();

eval { $gpk->readCorrelation() };

ok( $@, "error produced" );

like( $@, qr/Could not open.*correlation.csv/, "could not open correlation.csv" );

eval { $gpk->readCorrelation( "another.csv" ) };

ok( $@, "error produced" );

like( $@, qr/Could not open.*another.csv/, "could not open another.csv" );

eval { $gpk->readCorrelation( "corr.csv" ) };

ok( $@, "error produced" );

like( $@, qr/02foo.01a.*does not match the 'csv_string' entry/, "does not match csv_string" );
