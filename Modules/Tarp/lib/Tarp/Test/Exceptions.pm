package Tarp::Test::Exceptions;

use strict;

=head1 NAME

Tarp::Test::Exceptions - test exceptions

=head1 SYNOPSIS

    use Tarp::Test::Exceptions;

    my %msgs = (
        noError => '',
        
        read => qr/cannot read/,
        write => qr/cannot write/,
        ...
    );
    
    my @exp = @msgs{}
        'read', # c01
        'write' # c02
    };
    
    my $t = Tarp::Test::Exceptions->new();
    $t->expected( \@exp )

    my $x = Foo->new(); # class I am testing
    
    $t->case( $x, "read()" );  # c01
    $t->case( $x, "write()" ); # c02


=head1 DESCRIPTION

This class calls object methods, catches exception output, and then compares it
against a list of expected errors.  Each test must have a subdirectory called
"c01", "c02" etc.  where you can put any input to the test method.

The list of expected errors (regular expressions) must be given to
Test::Exceptions beforehand.

=cut

use Test::More;
use Carp;

=head1  METHODS

=head2 new

    my $t = Tarp::Test::Exceptions->new();

Creates a new exceptions tester.

=cut

sub new {
    my $class = shift;
    my $self = bless {
        _cidx    => 0,
        expected => [],
    }, $class;
    return $self;
}

=head2 case

 # Object method $obj->method()
    $t->case( $obj, "method( \"args\" )" );
    $t->case( $obj, "method( \"args\" )", "description" );
 
 # Class method Foo->method()
    $t->case( "Foo", "method" );

Runs the next test case.  Output is printed as "c01: description" (where 'c01'
is the next test case number) or "c01 exception" if no description is given.

=cut

sub case {
    my $self    = shift;
    my $c       = "c" . sprintf "%02d", ++$self->{_cidx};
    my $obj     = shift;
    my $method  = shift;    
    my $desc    = $_[0] ? $c . ": " . shift : "$c exception";

    chdir $c or croak "Could not chdir to '$c': $!, stopped";

    my $msg;
    if ( ref $obj ) {
        eval "\$obj->$method";
        $msg = $@;
    } else {
        eval "$obj->$method";
        $msg = $@;
    }
    
    my $exp = $self->{expected}->[ $self->{_cidx} - 1 ];
    
    if ( $exp ) {
        like( $msg, $exp, $desc );
    } else {
        ok( ! $msg, "$c produced no error" )
            or diag "No error expected, but this was produced:\n$msg";
    }

    chdir "..";
}

=head2 expected

    $t->expected( \@exp )

Sets @exp as the list of regular expressions to check for each case (c01, c02
etc)

=cut

sub expected {
    my $self = shift;
    if ( @_ ) {
        return $self->{expected} = shift;
    } else {
        return $self->{expected};
    }
}

1;
