#!perl

use strict;
use Test::More tests => 3;
use File::Copy;

use Tarp::GenTex::App;
use Tarp::Test::Files;

chdir ( "t/t30" ) or die "Could not chdir to t30: $!";

my $Debugging = 0;

sub runTest {
	my $out = '';
	open B, '>', \$out;
	select B;
	Tarp::GenTex::App->run();
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

$t->generator([ \&runTest ]);

@ARGV = (
	 "--out=out/dataout.tex",
	  "--var=CHAP_TITLE;Learning Perl",
	  "--var=SECT_TITLE;How to Use Variables",
	  "in/3c0102.pklist" );

$t->case();

