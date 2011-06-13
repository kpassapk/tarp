#!/usr/bin/perl -w
use strict;

use Tarp::varExtract;

Tarp::Style->import( "Tarp::varExtract::Style" );
Tarp::Style->import( "Tarp::Style::ITM" );

my $style = Tarp::Style->new();

my $tas = -e "solutions-starter.tas" ?
    "solutions-starter.tas" : $style->defaultTASfile();
    
if ( $tas ) {
    print "Using '$tas' for search terms\n";
    $style->load( $tas )
        or die $style->errStr() . "\n\nStopped";
} else {
    my $header = <<END_OF_TAS;
################################################################################
#                                                                              #
#                              TECHARTS STYLE FILE                             #
#                                                                              #
#                    Generated automatically by get-titles.pl                  #
#                                                                              #
################################################################################

END_OF_TAS

    my $tas = $header . $style->saveString() . <<REST_OF_TAS;
# The rest

REST_OF_TAS
    
    open TAS, '>', "tasfile.tas"
        or die "Could not open 'tasfile.tas' for writing: $!, stopped";
    
    print TAS $tas;
    close TAS;
    print "Wrote 'tasfile.tas'\n";
    return;
}

my $xt = Tarp::varExtract->new();
$xt->style( $style );
