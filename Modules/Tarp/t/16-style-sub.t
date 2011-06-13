#!/usr/bin/perl -w

BEGIN {
    use Cwd;
    our $dir = cwd;
}

use lib $dir;
use strict;

#Here we are testing a style subclass (plugin)

use Test::More tests => 3;

use Tarp::Style;
# Tarp::Style->debug( 1 );

open OUT, ">myStyle.pm";
print OUT <<END_OF_MODULE;
package myStyle;
use strict;

sub new {
    my \$class = shift;
    my \$self = bless \$class->SUPER::new(), \$class;
    return \$self;
}

sub emptyFileContents {
    my \$self = shift;
    my \$str = \$self->SUPER::emptyFileContents() . "forgot = to end in newline";
    return \$str;
}

1;
END_OF_MODULE
close OUT;

eval 'Tarp::Style->import( "myStyle" )';
ok( ! $@, "Import ok" );

my $sty;
eval '$sty = Tarp::Style->new()';
ok( $@, "Error produced" );
like( $@, qr/does not end with a newline/, "does not end with a newline" );
unlink "myStyle.pm";
