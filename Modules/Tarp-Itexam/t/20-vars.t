#!perl

use strict;
use Test::More;
use Data::Dumper;
use IO::File;

use Tarp::Itexam;
use Tarp::Test::Files;

plan tests => 5;

my $c = 1;

my @VARS_EXP = (
{ # c01
          'itemTag_2_::ITM' => [
                             {
                               'pos' => '0',
                               'val' => 'a',
                               'line' => '10'
                             },
                             {
                               'pos' => '0',
                               'val' => 'b',
                               'line' => '11'
                             },
                             {
                               'pos' => '0',
                               'val' => 'c',
                               'line' => '12'
                             }
                           ],
          'itemTag_1_::ITM' => [
                           {
                             'pos' => '0',
                             'val' => '1',
                             'line' => '6'
                           },
                           {
                             'pos' => '0',
                             'val' => '2',
                             'line' => '7'
                           },
                           {
                             'pos' => '0',
                             'val' => '3',
                             'line' => '8'
                           }
                         ],
          'subTitle::SUBTITLE' => [
                                    {
                                      'pos' => '10',
                                      'val' => 'A Childhood Story',
                                      'line' => '3'
                                    }
                                  ],
          'title::REST' => [
                             {
                               'pos' => '9',
                               'val' => 'Wee Bairn',
                               'line' => '1'
                             }
                           ],
          'title::FIRST' => [
                              {
                                'pos' => '7',
                                'val' => 'A',
                                'line' => '1'
                              }
                            ]
        },
{ # c02
          'itemTag_2_::ITM' => [
                             {
                               'pos' => '0',
                               'val' => 'a',
                               'line' => '10'
                             },
                             {
                               'pos' => '0',
                               'val' => 'b',
                               'line' => '11'
                             },
                             {
                               'pos' => '0',
                               'val' => 'c',
                               'line' => '12'
                             }
                           ],
          'itemTag_1_::ITM' => [
                           {
                             'pos' => '0',
                             'val' => '1',
                             'line' => '6'
                           },
                           {
                             'pos' => '0',
                             'val' => '2',
                             'line' => '7'
                           },
                           {
                             'pos' => '0',
                             'val' => '3',
                             'line' => '8'
                           }
                         ],
          'subTitle::SUBTITLE' => [
                                    {
                                      'pos' => '10',
                                      'val' => 'A Childhood Story',
                                      'line' => '3'
                                    }
                                  ],
          'title::REST' => [
                             {
                               'pos' => '9',
                               'val' => 'Wee Bairn',
                               'line' => '1'
                             }
                           ],
          'title::FIRST' => [
                              {
                                'pos' => '7',
                                'val' => 'A',
                                'line' => '1'
                              }
                            ]
        }
);

sub runTest {
	my $x = shift;

	$x->extractAttributes( "../in/datain.tex" );
	my $out = new IO::File ">out/dataout.txt";
	die "Could not open 'out/dataout.txt' for writing: $!, stopped"
		unless defined $out;

	$x->printLineBuffer( $out );
	undef $out;
}

chdir ( "t/t20" ) or die "Could not chdir to test directory, stopped";


my $x = Tarp::Itexam->new();

ok( $x->style()->load(), "style load" )
	or diag $x->style()->errStr();

my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest, $x ] );

$t->case( "simple" ); # c01

is_deeply( $x->variables(), $VARS_EXP[ 0 ], "c01 vars" );

$x->stripVariables( [ qw/ITM/ ] );

$t->case( "strip ITM" );

is_deeply( $x->variables(), $VARS_EXP[ 1 ], "c02 vars" );

