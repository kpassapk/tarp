#!perl

use File::Find;
use File::Copy;

BEGIN {
    use Cwd;
    our $dir = cwd;
}

use File::Spec;
use lib File::Spec->catfile( $dir, qw/Modules Tarp lib/ );

use strict;
use Tarp;

sub fix {
    return if $_ eq "clean.pl";
    return unless -f $_;
    my ( $f, $t ) = ( $_, "__tmp_$_" );
    open F, "<$f";
    open F2, ">$t";
    my $ch = 0;
    
    my @from = ( qr/^Version (\d\.\d{1,})/,
                 qr/our \$VERSION = '(\d\.\d{1,})'/ );
    my @to = ( "Version $Tarp::VERSION",
               "our \$VERSION = '$Tarp::VERSION'" );
    
    while ( <F> ) {
        for my $i ( 0 .. 1 ) {
            if ( $_ =~ $from[ $i ] ) {
#                print "$f: $1 to $Tarp::VERSION\n";
                s/$from[$i]/$to[$i]/;
                $ch++;
            }
        }
        print F2 $_;
    }
    close F2;
    close F;
    if ( $ch ) {
        move $t, $f or die "Could not replace $t: $!";
        print "$ch changes in $File::Find::name\n";
    } else {
        unlink $t or die "Could not remove $t: $!";
    }
}

print "Setting version to $Tarp::VERSION\n";
find( \&fix, "." )