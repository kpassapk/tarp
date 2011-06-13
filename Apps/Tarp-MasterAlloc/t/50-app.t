#!perl

use strict;
use Test::More tests => 2;
use File::Copy;

use Tarp::MasterAlloc::App;
use Tarp::Test::Files;

chdir ( "t/t50" ) or die "Could not chdir to t50: $!";

my $Debugging = 0;

sub runTest {
	my $out = '';
	open B, '>', \$out;
	select B;
	Tarp::MasterAlloc::App->run();
	close B;
	diag $out if $Debugging;
}

sub check_tas {
	&runTest;
	ok( -e "TASfile.tas", "TASfile.tas exists" );
	move "TASfile.tas", "out";
}

my $t = Tarp::Test::Files->new();

$t->generator( [ \&check_tas ] );
@ARGV = ( qw/--gen-tas/ );

$t->case();

