package Tarp::Burn::Style;

use strict;

=head1 NAME

Tarp::Burn::Style - style for Tarp::Burn

=head1 SYNOPSIS

    use Tarp::Style;
    
    Tarp::Style->import( "Tarp::Burn::Style" );
    
    # with "source" and "destination" entries
    $sty = Tarp::Style->new();

    $sty->burnSource( "mySource" ); # "source"
    $sty->burnDest( "myDest" );  # "destination"

    # with "mySource" and "myDest" entries
    $sty->loadString( $sty->emptyFileContents() );

=cut

my %fields = (
    burnString => '',
    burnSource => "source",
    burnDest   => "destination",
);

=head1 METHODS

=head2 new

    $sty = Tarp::Style->new();

Creates a new style for Tarp::Burn.

=cut

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;
    @{$self}{ keys %fields} = values %fields;
    return $self;
}

=head2 emptyFileContents

Appends the following lines:

    source = $name$\.$ext$
        source::name = .+
        source::ext = \w+
        source::EXACT = 1
    
    dest = $name$\.$ext$
        dest::name = .+
        dest::ext = \w+
        dest::EXACT = 1

=over

=item C< source >

Matches source strings (filenames by default)  Splits source strings into parts.
Also used as a regular expression to check that strings to be processed are in
the right format.  Because of this, this entry is also referred to as the
"source spec".

=item C< destination >

Specifies new order for the parts from the source filename, plus any additional
text.  Also used as a regular expression to check that the new filenames are
what was expected.  Because of this, this entry is also referred to as the
"destination spec".

=back

The entry names "source" and "destination" can be set to another value through
the accessor methods C< burnSource() > and C< burnDest() >, respectively.

=cut

sub emptyFileContents {
    my $self = shift;
    my $c = $self->SUPER::emptyFileContents();
    my $str = <<END_OF_TAS;
# Tarp::Burn::Style

$self->{burnSource} = \$name\$\\.\$ext\$
    $self->{burnSource}\::name = .+
    $self->{burnSource}\::ext = \\w+
    $self->{burnSource}\::EXACT = 1

$self->{burnDest} = \$name\$\\.\$ext\$
    $self->{burnDest}\::name = .+
    $self->{burnDest}\::ext = \\w+
    $self->{burnDest}\::EXACT = 1

END_OF_TAS
    return $c . $str;
}

=head2 constraints

=over

=item source

=over

=item *

must exist

=item *

1+ regular expressions

=back

=item destination

=over

=item *

Must exist.

=item *

1+ regular expressions.

=item *

Contains either one value or the same amount of values as C< source >.

=back

=cut

sub constraints {
    my $self = shift;
    my $tas = shift;
    my %c = $self->SUPER::constraints( $tas );
    $c{ $self->{burnSource} } ||= Tarp::TAS::Spec->exists();
    $c{ $self->{burnDest}   } ||= Tarp::TAS::Spec->exists();
    
    if ( $tas->values( $self->{burnSource} ) ) {
        my $ns = 0 + @{$tas->values( $self->{burnSource} ) };
        $c{ $self->{burnDest} } = Tarp::TAS::Spec->multi(
            $c{ $self->{burnDest} },
            [ sub {
                my $v = shift;
                my $n = shift; # gets "3"
                if ( @$v > 1 ) {
                    return ( "must have $n values" ) if @$v != $n; 
                }
                return ();
            }, $ns - 1 ]
        );
    }
    return %c;
}

1;
