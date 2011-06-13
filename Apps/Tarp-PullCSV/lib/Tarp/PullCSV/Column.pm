package Tarp::PullCSV::Column;

=head1 NAME

    Tarp::PullCSV::Column - column type for Tarp::PullCSV

=head1 SYNOPSIS

See L<Tarp::PullCSV/SYNOPSIS>.

=cut

BEGIN {
    use Cwd;
    our $directory = cwd;
}

use lib $directory;
use strict;

use Carp qw/croak/;

our $AUTOLOAD;

=head1 METHODS

=head2 new

    $col = Tarp::PullCSV::Column->new( $csv );
    $col = Tarp::PullCSV::Column->new( $csv, "Tarp::Itexam::AttrType" );

Creates a new column for the Tarp::PullCSV object $csv. The new column will have
a heading "Col", "Col_2", "Col_3", etc. A custom attribute type may also be
specified (advanced users only). This is used for getting the column's values.
If not supplied, Tarp::Itexam::Attribute will be used.

=cut

sub new {
    my $class = shift;
    my $csv = shift;
    my $attrType = shift || "Tarp::Itexam::Attribute";
    
    my $self = {
        _csv       => undef, # Set in _init()
        _attr      => undef, # Set in _init()
        _attrType  => $attrType,
    };
    
    bless $self, $class;
    $self->_init( $csv );
    return $self;
}

# This is a bit experimental, but what it does is create a .pm that
# subclasses Itexam::Attribute and links to a PullCSV::Column, uses it
# and then deletes it.  By default the attribute's name is Attribute__col, but
# but this changes with the name of the Itexam::Attribute subclass.  The adapter
# forwards the preProcess(), read() and postProcess methods to the CSV::Column.
sub _init {
    my $self = shift;
    my $csv = shift;
    
    my $exm = $csv->{_EXM};
    
    my $attrType = $self->{_attrType};
    my $attrName = $attrType;
    $attrName =~ s/^.*://; # Strip fully qualified portion
    
    my $adaptMod = "$attrName\__col";
    open ADAPT, ">$adaptMod.pm"
        or die "Could not open $adaptMod.pm for writing: $!, stopped";
    
    print ADAPT <<END_OF_ADAPTER;
# This is an automatically generated template adapter
# Any changes made to this file will be lost!

package $adaptMod;

use base qw/$attrType/;

our \$AUTOLOAD;

my \%fields = (
    colRef => undef,
);

sub new {
    my \$class = shift;
    my \$name = shift;
    my \$exm = shift;
    my \$self = \$class->SUPER::new( \$name, \$exm );
    \@{\$self}{keys \%fields} = values \%fields;
    bless \$self, \$class;
    return \$self;
}

sub AUTOLOAD {
    my \$self = shift;
    my \$name = \$AUTOLOAD;
    \$name =~ s/.*://;   # strip fully-qualified portion
    if ( \$self->{colRef} && \$self->{colRef}->can( \$name ) ) {
        return \$self->{colRef}->\$name( \@_ );
    } else {
        my \$super = "SUPER::\$name";
        return \$self->\$super( \@_ );
    }
}

1;

END_OF_ADAPTER

    close ADAPT;
    
    eval "use $adaptMod";
    die "Failed to load adapter:\n$@" if $@;
    unlink $adaptMod . ".pm";
    my $attr = $adaptMod->new( "Col", $exm );
    $attr->colRef( $self ); # to forward methods here
    $self->{_attr} = $attr;
    # sets $self->{_csv}:
    $csv->addColumn( $self ); 
}

=head2 heading

    (not user callable)

Returns the column's default heading, normally Col, Col_2 etc.  Reimplement to
output a different heading.

=cut

sub heading {
    my $self = shift;
    return $self->{_attr}->name();
}

=head2 value

    (not user callable)

Returns the value for this column. This method is called repeatedly, once for
every exercise in the file. By default the value is an empty string (unless you
use a custom Attribute type, see L</Custom Attributes> below). Reimplement this
method to do something more interesting. For example, if you want the column to
contain "42", say

    sub value {42}

in your subclass.  Or better yet, use some of the data available about each
exercise.  Write

    sub value {
        my $args = shift;
        return $args->{exLine};
    }

to return the line number for the current exercise.
See L<Tarp::Itexam::Attribute/value>() for a list of available data.

=head1 CUSTOM ATTRIBUTES

If there is C<Tarp::Itexam::Attribute> subclass that already provides a
C<preProcess()>, C<postProcess()> or C<value()> methods with the functionality
you would like to use in your column, you can use it and pass the result
through as column values.

In order to do this, just specify the attribute's name in the constructor.  For
example, to create an attribute that contains the line number, you could create
a file C<line.pm> as follows:

    ______/ line.pm \_______________________________
    
    package line;

    use strict;
    use base qw/Tarp::PullCSV::Column/;
    
    sub new {
        my $class = shift;
        my $csv = shift;
        my $self = $class->SUPER::new( $csv,
            "Tarp::Itexam::Attribute::Line" );    
        bless $self, $class;
        return $self;
    }
    
    1;
    ________________________________________________

You don't need to provide C<value()> because this is already taken care of by
L<Tarp::Itexam::Attribute::Line/value()>.

=cut

# Sets or gets the intenal attribute name (and column heading).
# Set this to change the default name without reimplementing.
sub _attrName {
    my $self = shift;
    return $self->{_attr}->name( @_ );
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless ( exists $self->{$name} && $name =~ /^[a-z]/i ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

1;
