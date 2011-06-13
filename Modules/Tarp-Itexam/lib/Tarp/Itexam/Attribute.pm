package Tarp::Itexam::Attribute;

=head1 NAME

Tarp::Itexam::Attribute - Attribute class for Itexam

=head1 SYNOPSIS

    # This usage is to demonstrate the interface of subclasses.
    # Objects of this class cannot be used directly!
    Tarp::Itexam::Attribute;
    
    $ITM = Tarp::Itexam->new( ... );
    Tarp::Itexam::Attribute->new( "foo", $ITM );
    
    $ITM->extractAttributes;

=head1 DESCRIPTION

This is a base class for implementing attributes in Itexam. Each attribute has a
name, which is assigned automatically but can be reset using name(), and a
value() function, which should be reimplemented in an Attribute subclass.

If value() depends on something other than the current exercise, preProcess()
and postProcess() can be reimplemented to look elsewhere.

When an Attribute is created, it is "attached" to the Itexam given as a second
argument. When Itexam's extractAttributes() function is called, each attached
attribute's value() function is called on each exercise in the input file. Since
an Attribute is attached automatically by the new() constructor, the oref
returned by this method does not need to be stored, unless the user wants to
specify additional attribute properties later.

This class is AUTOLOAD enabled to provide accessor methods for object data
(except those beginning with an underscore).  preProcess(), postProcess() and
value() are also autoloaded, so subclassing AUTOLOAD will catch all three.

=cut

use strict;
use Carp qw/ croak confess /;

my %fields = (
    inherit     => '',
    name        => undef,
    preProcess  => 1,
    postProcess => 1,
    value       => "",
);

our $AUTOLOAD;

=head1 METHODS

=head2 new

    $ITM = Tarp::Itexam->new( ... );
    $foo = Tarp::Itexam::Attribute->new( "foo", $ITM );

Creates a new attribute for C<$ITM>, called "foo", that returns an empty string
with its value() method and does noo preProcess() or postProcess() anything.

If $ITM already has an attribute called "Foo", the name of te new attribute
is modified by adding an underscore and an integer: Foo_2, Foo_3, and so on.

=cut

sub new {
    my $class = shift;
    my $name = shift;
    my $examiner = shift;

    confess "check usage" unless ref $examiner
        && $examiner->isa( "Tarp::Itexam" );
    confess "check usage" unless length $name;
    
    my $self = {
        %fields,
        _exm        => undef,
    };
    $self->{name} = $name;
    
    bless $self, $class;
    $examiner->addAttribute( $self );
    return $self;
}

=head2 name

    $foo = $attr->name();
    $attr->name( "baz" );

Sets or gets the attribute's name.  The name may be modified slightly to make
sure it is unique in the parent Examiner (by appending _2, _3 etc.) The return
value is the current name or, when setting a new value, the new modified name.

=cut

sub name {
    my $self = shift;
    my $exm = $self->{_exm};
    
    if ( @_ ) {
        my $newName = $self->{_exm}->_approve( @_ );
        $self->{_exm}->{attributes}->{$self} = $newName;
        return $self->{name} = $newName;
    } else {
        return $self->{name};
    }
}

=head2 preProcess

    [not user-callable]

Called once by Itexam's extractAttributes() method, after finding the
exercises in the TeX file but before extracting any attributes.

The following arguments are available (through a hashref)

    # Read only
        TEXfile     The name of the TeX file being processed
        listData      The exercise data.  See LaTeXtract listData method.
        lineBuffer  The line buffer as an array (the whole file)
        eXtractor   LaTeXtract oref.

=head2 postProcess

    [not user-callable]

Called once by Itexam's extractAttributes() method, after finding
the attributes.

=head2 value

    [not user-callable]

Gets the value of this attribute.  This method must be implemented in subclasses.

Called for each exercise in the TeX file by Itexam's
extractAttributes() mehtod. Before calling value(), the parent Examiner will
have loaded the following arguments:

    # read-only
        TEXfile         The LaTeX file name being extracted (string)
        exSeq           Numbering sequence (integer)
        itemString        Exercise string
        exLine          Line where the exercise is found (integer)
        isLeaf          True if this exercise is a leaf (has no children)
    # read/write
        exBuffer        Line buffer corresponding to the exercise (arrayref)

=head2 inherit

    $attr->inherit( 1 );

=cut

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    if ( $name eq "value" ) {
        croak "The value() method has not been reimplemented in class $type, stopped";
    }
    unless ( exists $self->{$name} && $name =~ /^[a-z]/i ) {
        croak "Can't access `$name' field in class $type, stopped";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

1;