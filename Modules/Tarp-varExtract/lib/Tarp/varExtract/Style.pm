package Tarp::varExtract::Style;

=head1 NAME

Tarp::varExtract::Style - style for varExtract

=head1 SYNOPSIS

    Tarp::Style->import( "Tarp::varExtract::Style" );

    # New style with "filename" entry
    $sty = Tarp::Style->new();
    
    # New style with "myFileName" entry
    $sty->fnameEntry( "myFileName" );
    $sty->loadString( $sty->emptyFileContents() );

=head1 DESCRIPTION

Requires an entry called "filename" by default, although this can be changed
using the fnameEntry() method.  You may want to do this when using this script
with another one that also uses a "filename" entry.

=cut

use strict;
use Carp;

my $FnameEntry = "filename";

=head1 METHODS

=head2 new

    Tarp::Style->new();

=cut

sub new {
    my $class = shift;
    confess "Use Tarp::Style->import() instead, stopped"
        unless $class eq "Tarp::Style";
    my $self = bless $class->SUPER::new(), $class;
    $self->{fnameEntry} = $FnameEntry;
    return $self;
}

=head2 fnameEntry

    $f = $sty->fnameEntry();
    $sty->fnameEntry( "myFileName" );

C<TAS> entry used to look for filename patterns.

=cut

sub fnameEntry {
    my $self = shift;

    if ( ref $self ) {
        if ( @_ ) {
            return $self->{fnameEntry} = shift;
        } else {
            return $self->{fnameEntry};
        }
    } else {
        if ( @_ ) {
            return $FnameEntry = shift;
        } else {
            return $FnameEntry;
        }
    }
}

=head2 emptyFileContents

    $sty->emptyFileContents();

Returns the following lines:

    filename = $fileBase$\.$ext$
        filename::fileBase = \w+
        filename::ext = \w+

where "filename" above is contents of the fnameEntry() method.

=cut

sub emptyFileContents {
    my $self = shift;
    my $fn = $self->{fnameEntry};
    my $str = <<END_OF_INPUT;
# Tarp::varExtract::Style

$fn = \$fileBase\$\\.\$ext\$

$fn\::fileBase = \\w+
$fn\::ext      = \\w+

END_OF_INPUT
    my $contents = $self->SUPER::emptyFileContents() . $str;
    return $contents;
}

=head2 constraints

Adds the following constraints:

=over

=item C<filename>

=over

=item *

must exist

=item *

cannot be empty

=item *

contains at least one variable

=back

=back

where "C<filename>" above is contents of the fnameEntry() method.

=cut

sub constraints {
    my $self = shift;
    my %c = $self->SUPER::constraints( @_ );

    my $filename = $self->{fnameEntry};
    my $simple = Tarp::TAS::Spec->simple();
    
    $c{$filename} ||= Tarp::TAS::Spec->exists();
    $c{$filename} = Tarp::TAS::Spec->multi(
        $c{$filename},
        Tarp::TAS::Spec->simple(
            requireVars => 1,
            allowEmpty  => 0,
        )
    );
    return %c;
}

1;
