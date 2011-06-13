package Tarp::MasterAlloc;

=head1 NAME

Tarp::MasterAlloc - Allocate new master numbers and fix errors in manuscript files.

=head1 SYNOPSIS

    use Tarp::MasterAlloc;
    
    # Use default TAS File
    $x = Tarp::MasterAlloc->new();

    # Get macros and NEW refs from file.etx
    $x->getExData( "file.tex" );
    
    $x->printExData();

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

=head1 DESCRIPTION

This module is designed to extract relevant data from problem (or exercise) lists
in SciWord C<TeX> files.  Typically the input will resemble the following:

    ...

    \item[\hfill 24.]

    %TCIMACRO{%
    %\hyperref{\fbox{\textbf{NEW}}}{}{\fbox{\textbf{NEW}}}{}}%
    %BeginExpansion
    \msihyperref{\fbox{\textbf{NEW}}}{}{\fbox{\textbf{NEW}}}{}%
    %EndExpansion

    \item[\hfill 25.]
    
    ...

The problem list is in a format that can be understood by Tarp::LaTeXtract
with the aid of a Tarp Style C<.tas> file.  Each problem contains one or more
macros, which begin with %TCIMACRO and %EndExpansion in this example.  Inside
this macro there are four calls to a master number or the word C<NEW>.  The goal
of this module is to extract this master number and correlate it to the "parent"
problem number.

There may be more than one section in the input file.  Unless sections are
named explicitly using L</setSectionNames>, these will named according to their
order of occurrence in the input file ("1", "2", "3" etc.)

=cut

use strict;
use Carp;
use Tarp::Itexam;
use Tarp::MasterAlloc::NewMasterAttribute;

our $AUTOLOAD;

my %fields = (
    nextMaster      => '',
    newCount        => 0,
    fixCount        => 0,
    macroStartTag   => 'TCIMACRO',
    macroEndTag     => 'EndExpansion',
);

=head1 METHODS

=head2 new

    $foo = $x->new();
    
    $bar = $x->new( nextMaster => 42 );

Creates a new MasterAlloc object using the file "in.tex". Options can be set
by supplying a hashref. Currently the following options are available:

=over

=item nextMaster (integer)

Sets the next master number to be assigned.  This value is used by L</getExData>
as follows:

=over

=item *

All references to new masters in the input will get replaced with this masters
starting at this number.
  
=item *

The next master number will be shown when L</printExData> is called, with the
word (new) next to it.

=back

=back

=cut

sub new {
    my $class = shift;
    my $opts = shift || {};
    return if @_;
    
    my $self = {
        _permitted => \%fields,
        %fields,
        # implementation    
        newAttr  => undef,
        _EXM => undef,   
    };
    
    for my $prop ( keys %$opts ) { # if invalid attr, return undef
        return unless exists $fields{$prop};
        $self->{$prop} = $opts->{$prop};
    }
    bless $self, $class;

    Tarp::Style->import( "Tarp::MasterAlloc::Style" );
    
    my $EXM = Tarp::Itexam->new();
    $EXM->stripVariables( '' );
    $EXM->maxLevel( 2 );

    my $newAttr = Tarp::MasterAlloc::NewMasterAttribute
    ->new( "master", $EXM );
    @{$self}{qw/newAttr _EXM/} = ( $newAttr, $EXM );
    return $self;
}

=head2 getExData

    $m->getExData( "file.tex" );

Gets exercise data from F<file.tex>.
If there were "new" refs and masterRef was defined prior to calling this method,
master numbers starting at this masterRef are allocated and put into the exercise
line buffer and the exercise data array.

newCount and fixCount are updated in this method to reflect the result of parsing
the input file.  Old values are ignored.

=cut

sub getExData {
    my $self = shift;
    my $TEXfile = shift;
    
    my ( $nextMaster, $macroStartTag, $macroEndTag, $_EXM, $newAttr, )
        = @{$self}{ qw/ nextMaster macroStartTag macroEndTag _EXM newAttr/ };

    my @msRefs = $_EXM->style()->interpolate( "masterRef", Tarp::Style->NCBUFS () );
    $newAttr->refFormats( \@msRefs );
    $newAttr->nextMaster( $nextMaster );
    $newAttr->startTag( $macroStartTag );
    $newAttr->endTag( $macroEndTag );
    
    $_EXM->extractAttributes( $TEXfile )
        or croak $_EXM->errStr();
    
    $nextMaster = $newAttr->nextMaster(); # Next master AFTER allocation (if any)
    
    my @exData;
    for ( my $seq = 0; $seq < $_EXM->seqCount; $seq++ ) {
        push @exData, $_EXM->data( $seq );
    }
    
    @{$self}{ qw/exData nextMaster newCount fixCount/ }
        = ( \@exData, $nextMaster, $newAttr->newCount(), $newAttr->fixCount() );
}

=head2 printExData

    $m->printExData();

Print a summary of eercise data, as follows:

  Line | Ex.     | Master
Sequence 0
  42     01        00001 (new)
  43     02        00002

=cut

sub printExData {
    my $self = shift;

    my ( $exData ) = @{$self}{ qw/ exData / };
    
    print "  Line | Ex.     | Master\n";
    
    for ( my $seq = 0; $seq < @$exData; $seq++ ) {
        print "Sequence $seq\n";
        my $xd = $exData->[ $seq ];
                my @EXS = sort( keys( %$xd ) );

        foreach my $ex ( @EXS ) {
            my $attrs = $xd->{$ex};
            my ( $line, $master ) = @{$attrs}{qw/line master/};
            my $exPadded = sprintf("%-*s", 8, $ex);
            my $linePadded = sprintf( "%-*s", 5, $line );
            print "  $linePadded| $exPadded| $master\n";
        }
    }
}

=head2 printLineBuffer

    $m->printLineBuffer( $io );

Print output data to $io object.

=cut

sub printLineBuffer {
    my $self = shift;
    my $io = shift;
    
    my ( $_EXM ) = @{$self}{ qw/ _EXM / };
    
    $_EXM->printLineBuffer( $io );
}

=head2 style

    $sty = $m->style();

Returns a reference to the style object.

=cut

sub style {
    my $self = shift;
    return $self->{_EXM}->style();
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

=head2 SEE ALSO

=over

=item *

L<Tarp::NewMasterAttribute>

=back

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::MasterAlloc


=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1;