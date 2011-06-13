#!perl

use Test::More;
use Test::Differences;

use Data::Dumper;

use Tarp::Itexam;
# use Tarp::Test::Files;

package MyAttr;
use base qw/Tarp::Itexam::Attribute/;

sub new {
	my $class = shift;
	bless $class->SUPER::new( @_ ), $class;
}

sub value { 42 }

package main;

my $icase = 1;
plan tests => 11;

$Carp::Verbose = 1;

chdir ( "t/t10" ) or die "Could not chdir to test directory, stopped";

$foo = Tarp::Itexam->new();
$foo->stripVariables( 0 );

ok( $foo->style()->load(), "style load" )
	or diag $foo->style()->errStr();

ok( $foo->maxLevel( 2 ), "maxLevel set" );
is( $foo->maxLevel(), 2, "maxLevel get" );

MyAttr->new( "line", $foo );

my @names = sort $foo->attrNames();

eq_or_diff( \@names, [ qw/line line_2/ ], "attNames" );

ok( $foo->extractAttributes( "datain.tex" ), "extractAttributes datain.tex" )
	or diag $foo->errStr();

is_deeply( $foo->data(), {
          '03b' => {
                     'line_2' => 42,
                     'line' => '7'
                   },
          '01' => {
                    'line_2' => 42,
                    'line' => '2'
                  },
          '03c' => {
                     'line_2' => 42,
                     'line' => '8'
                   },
          '03a' => {
                     'line_2' => 42,
                     'line' => '6'
                   },
          '02' => {
                    'line_2' => 42,
                    'line' => '3'
                  }
        }, "foo data" );

is( $foo->seqCount, 1, "One sequence as expected" );

use Test::Differences;

eq_or_diff( $foo->exBuffer( "03", 0 ), <<EOT, "exBufer" );
3
begin
a
b
c
end
EOT

eq_or_diff( $foo->exRangeBuffer( "02", "03", 0 ), <<EOT, "exRangeBuffer" );
2
3
begin
a
b
c
end
EOT

ok( $foo->extractAttributes( "datain2.tex" ), "extractAttributes datain2.tex" )
	or diag $foo->errStr();

is_deeply( $foo->data(), [
          {
            '01' => {
                      'line_2' => 42,
                      'line' => '2'
                    }
          },
          {
            '01' => {
                      'line_2' => 42,
                      'line' => '6'
                    }
          }
        ], "foo data multiple seq" );

