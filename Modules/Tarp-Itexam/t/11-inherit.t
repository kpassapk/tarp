#!/usr/bin/perl -w

package Inh;
use base qw/Tarp::Itexam::Attribute/;

sub new {
	my $class = shift;
	bless $class->SUPER::new( @_ ), $class;
}

sub inherit {1}

sub value {
	my $self = shift;
	my $listData = shift;
	return "Inherited from " . $listData->{itemString};
}

package main;

use strict;
use Tarp::Itexam;

use Test::More tests => 3;

chdir "t/t11" or die "Could not chdir to 't/t11': $!, stopped";

my $exm = Tarp::Itexam->new();
ok( $exm->style()->load(), "style load" )
	or diag $exm->style()->errStr();

my $inh = Inh->new( "inh", $exm );
$exm->takeAttribute( $exm->attribute( "line" ) );
ok( $exm->extractAttributes( "datain.tex" ), "extractAttributes datain.tex" )
	or diag $exm->errStr();

is_deeply( $exm->data( 0 ), {
    '01' => {
              'inh' => 'Inherited from 01'
            },
    '01a' => {
               'inh' => 'Inherited from 01'
             },
    '01b' => {
               'inh' => 'Inherited from 01'
             }
  });
