#!perl

use Test::More tests => 3;
use Test::Differences;

# Here we test that the master refs found in the macros are
# left to right, top to bottom.

package OrderTester;

use base qw/Tarp::MasterAlloc::NewMasterAttribute/;

sub new {
	my $class = shift;
	
	my $self = $class->SUPER::new( @_ );
	
	$self->{allRefs} = ();
	$self->{uniqueRefs} = ();
	
	bless $self, $class;
	return $self;
}

sub gotMacroManyMasters {
	my $self = shift;
	my $args = shift;
	
	my @uniqueRefs= @{$args->{uniqueRefs}};
	my @allRefs = @{$args->{allRefs}};
	
	@{$self->{allRefs}} = @allRefs;
	@{$self->{uniqueRefs}} = sort @uniqueRefs;
}

sub allRefs {
	my $self = shift;
	return @{$self->{allRefs}};
}

sub uniqueRefs {
	my $self = shift;
	return @{$self->{uniqueRefs}};	
}

package main;

eval 'use Tarp::Itexam';
die "Could not load Tarp::Itexam: $@" if $@;

chdir ( "t/t40" ) or die "Could not chdir to t40: $!, stopped";

my $ex = Tarp::Itexam->new();
ok( $ex->style()->load() )
	or diag $ex->style()->errStr();

my @msRefs = $ex->style()->interpolate( "masterRef" );

my $x = OrderTester->new( "master", $ex );
$x->startTag( "TCIMACRO" );
$x->endTag( "EndExpansion" );
$x->refFormats( \@msRefs );

$ex->extractAttributes( "in/in.tex" );

my @allRefs = $x->allRefs;
my @uniqueRefs = $x->uniqueRefs;

my @allExpected = qw/ 00001 NEW 00003 NEW 00003 NEW 00004 /;
my @uniqueExpected = qw/ 00001 00003 00004 NEW /;

eq_or_diff( \@allRefs, \@allExpected, "All REFS ok" );
eq_or_diff( \@uniqueRefs, \@uniqueExpected, "Unique REFS ok" );
