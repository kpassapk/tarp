#!perl

use strict;
use Test::More;

use Tarp::Itexam;
use Tarp::Itexam::Attribute::Master;

plan tests => 2;

chdir ( "t/t30" ) or die "Could not chdir to test directory, stopped";

# Tarp::Itexam->debug( 1 );

my $exm = Tarp::Itexam->new();
$exm->stripVariables( 0 );

# print $exm->style()->saveString();

Tarp::Itexam::Attribute::Master->new( "master", $exm );

ok( $exm->extractAttributes( "in.txt" ), "extractAttributes in.txt" )
	or diag $exm->errStr();

# use Data::Dump qw/dump/;
# dump ;

is_deeply( $exm->data( 0 ), { "01" => { line => 2, master => 42 } }, "simple master"
)