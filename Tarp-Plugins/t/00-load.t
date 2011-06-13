#!perl

BEGIN {
	use Test::More tests => 1;
	use_ok( 'Tarp::Plugins' );
    use Cwd;
    our $directory = cwd;
    use File::Spec;
    our $libDir = File::Spec->catfile( $directory, "..", "Resources", "lib" );    
}

use lib $libDir;
use File::Copy qw/move/;
use File::Find;
use File::Copy::Recursive qw/dircopy/;

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

