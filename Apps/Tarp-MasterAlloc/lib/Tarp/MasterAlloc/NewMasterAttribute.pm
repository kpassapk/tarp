package Tarp::MasterAlloc::NewMasterAttribute;

use strict;
use base qw/Tarp::Itexam::Attribute::Master/;

=head1 NAME

Tarp::MasterAlloc::NewMasterAttribute: Handle "new" refs

=head1 SYNOPSIS

    use Tarp::MasterAlloc::NewMasterAttribute;
    
    my $ITM = Tarp::Itexam=>new( ... );
    my $a = Tarp::NewMasterAttribute->new( "master", $ITM );

    # Methods in this class are called by the following.
    $ITM->getExData();
    
=head1 DESCRIPTION

This attribute assigns master numbers and repairs the line buffer whenever
possible.

=cut

use Data::Dumper;

my %fields = (
    newRefFormat    => '\b(NEW)\b',
    newCount        => 0,
    fixCount        => 0,
    nextMaster      => '', # No allocation by default
);

=head1 METHODS

=head2 new

    my $ITM = Tarp::Itexam=>new( ... );
    my $a = Tarp::NewMasterAttribute->new( "NEW", $ITM );

Creates a new attribute with name "NEW" in the parent Itexam.

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new( @_ );
    
    foreach my $element (keys %fields) {
        $self->{_permitted}->{$element} = $fields{$element};
    }
    @{$self}{keys %fields} = values %fields;    
    
    bless $self, $class;
    return $self;
}

=head2 refFormats

    my $f = $attr->refFormats();

Returns the reference formats of the parent NewMasterAttribute class, plus an
entry that matches "NEW". 

=cut

sub refFormats {
    my $self = shift;
    
    if ( @_ ) {
        $self->SUPER::refFormats( shift );
    }
    my $formats = $self->SUPER::refFormats();
    push @$formats, $self->{newRefFormat};
    return $formats;
}

=head2 newRefFormat

    $f = $attr->newRefFormat();
    $attr->newRefFormat( "n" );

Accessor method for format of new reference.

=head2 nextMaster

    $f = $attr->nextMaster();
    $attr->nextMaster( "42" );

Sets or gets the next master number to be assigned.  If an empty string is given,
no master number will be assigned.

=head2 newCount

    $m->newCount();

Returns the amount of new master numbers allocated by the last call to
getExData().

=head2 fixCount

    $m->fixCount();

Returns the amount of items fixed by the last call to getExData().

=head2 gotExSingleMaster

    (not user callable)

If the single master is "NEW", then it is replaced with the next available
master number (assuming nextMaster has an integer).  Changes are applied to the
exercise buffer.  The "ref" argument is appended with (new).  If nextMaster
is empty, ref is given the value "new" and no changes are applied to the
exercise buffer.

If the single master is not "NEW", then nothing happens.

=cut

sub gotExSingleMaster {
    my $self = shift;
    my $args = shift;

    my ( $newRefFormat ) = @{$self}{ qw/ newRefFormat / };
    
    my ( $exBuffer, $macros, $im, $ref )
        = @{$args}{ qw/exBuffer macros macroIdxWithRef ref/ };

    if ( $$ref =~ /$newRefFormat/ ) {
        
        my $mr = $macros->[ $im ];    
        my @macroBuffer = @$exBuffer[ $mr->[0]-1 .. $mr->[1]-1 ];
        # All new
        $self->_replaceWithNew( \@macroBuffer, $ref );
        
        # Append "new" to master unless "new" already.
        $$ref .= " (new)" unless $$ref eq "new";
        
        # Replace this macro in the exercise buffer
        @$exBuffer[ $mr->[0]-1 .. $mr->[1]-1 ] = @macroBuffer;     
    }
}

=head2 gotMacroManyMasters

    (not user callable)

This function could be called if there are many non-new master refs in a macro,
or if there is one or more non-new master refs plus a "NEW" ref.

The superclass method is called, but instead of terminating the program, which
it would normally do, this method just issues a warning saying that there are
many masters in a particular macro.

Then the master refs are examined, left to right and top down.  The first value
is used for replacements in the line buffer.  If this value is "NEW", and
nextMaster is non empty, a new master is allocated.   Otherwise, if nextMaster
is empty, the word "NEW" is put in all the placeholders.


=cut

sub gotMacroManyMasters {
    my $self = shift;
    my $args = shift;
    
    # One or more existing plus possibly "new"
    my ( $newRefFormat ) = @{$self}{ qw/ newRefFormat / };
    
    my ( $macroBuffer, $allRefs, $uniqueRefs )
        = @{$args}{qw/macroBuffer allRefs uniqueRefs/};

    eval '$self->SUPER::gotMacroManyMasters( $args )';
    warn $@ if $@;
    
    my $ref;
    
    # Replace with first value
    if ( $allRefs->[0] eq "new" ) {
        $self->_replaceWithNew( $macroBuffer, \$ref );
    } else {
        $ref = $allRefs->[0];
        $self->_replaceWithValue( $macroBuffer, $ref );
    }
    @{$args->{uniqueRefs}} = ( $ref );
    $self->{fixCount}++;
}

### replaceWithNew
#
# If nextMaster is non-empty, strip buffer and insert the next master number,
# incrementing it by one.  If nextMaster is empty, strip buffer and replace
# with the word "NEW"

sub _replaceWithNew {
    my $self = shift;
    my $macroBuffer = shift;
    my $ms = shift;
    
    $self->_stripBuffer( $macroBuffer );
    
    if ( $self->{nextMaster}) {
        my $master = $self->{nextMaster}++;
        my $masterString = sprintf( "%0*d", 5, $master );
        $self->{newCount}++;
        $self->_insertIntoPlaceholder( $macroBuffer, "master $masterString" );
        $$ms = $masterString;
    } else {
        $self->_insertIntoPlaceholder( $macroBuffer, "NEW" );
        $$ms = "new";
    }
}

sub _replaceWithValue {
    my $self = shift;
    my $macroBuffer = shift;
    my $value = shift;
    
    $self->_stripBuffer( $macroBuffer );
    $self->_insertIntoPlaceholder( $macroBuffer, "master $value" );
}

sub _stripBuffer {
    my $self = shift;
    my $macroBuffer = shift;
    
    # Strip existing stuff
    for( my $i = 0; $i < @$macroBuffer; $i++ ) {
        while ( $macroBuffer->[$i] =~ /\b(new)\b/i ) {
            $macroBuffer->[$i] =~ s/$1/MASTER_PLACEHOLDER/;
        }            
        while ( $macroBuffer->[$i] =~ /master \d{5}[a-z]?/ ) {
            $macroBuffer->[$i] =~ s/master \d{5}[a-z]?/MASTER_PLACEHOLDER/;
        }
    }
}

sub _insertIntoPlaceholder {
    my $self = shift;
    my $macroBuffer = shift;
    my $replacementValue = shift;
    
    for( my $i = 0; $i < @$macroBuffer; $i++ ) {
        $macroBuffer->[$i] =~ s/MASTER_PLACEHOLDER/$replacementValue/g;
    }
}

1;