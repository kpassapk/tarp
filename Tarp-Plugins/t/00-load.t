#!perl

use Test::More tests => 1;
use File::Copy qw/move/;
use File::Copy::Recursive qw/dircopy/;
use File::Find;

BEGIN {
	use_ok( 'Tarp::Plugins' );
}

dircopy "lib", "t/plugins";

find ( \&disable, "t/plugins" );

sub disable {
	return unless $_ =~ /\.pm$/;
	return unless -e $_;
	my $o = $_;
	my $n = $o;
	$n =~ s/\.pm$/.p_/;
	move $o, $n;
}

diag( "Testing Tarp::Plugins $Tarp::Plugins::VERSION, Perl $], $^X" );

