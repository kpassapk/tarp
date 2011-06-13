package Tarp::MasterAlloc::Style;

=head1 NAME

Tarp::MasterAlloc::Style - style for Tarp::MasterAlloc

=cut

use strict;

=head2 new

    Tarp::Style->import( "Tarp::MasterAlloc::Style" );
    $s = Tarp::Style->new();

Creates a new style for MasterAlloc.

=cut

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;
    return $self;
}

=head2 emptyFileContents

    (not user callable)

Returns the contents of the superclass's emptyFileContents() plus
the following lines:

    masterRef = $MASTER$
        masterRef::MASTER = \d+

=cut

sub emptyFileContents {
    my $self = shift;
    my $str = '';
    open STR, '>', \$str;
    print STR <<END_OF_CONTENTS;
masterRef = \$MASTER\$
    masterRef::MASTER = \\d+
END_OF_CONTENTS
    close STR;
    return $self->SUPER::emptyFileContents() . $str;
}

=head2 constraints

    (not user callable)

Requires an entry called masterRef which contains $MASTER$ and cannot be empty.

=cut

sub constraints {
    my $self = shift;
    my %p = $self->SUPER::constraints( @_ );
    
    $p{masterRef} = Tarp::TAS::Spec->multi(
        $p{masterRef} ? $p{masterRef} : (),
        Tarp::TAS::Spec->simple(
            allowEmpty  => '',
            requireVars => [ qw/MASTER/ ] ),
    );
    return %p;
}

1;
