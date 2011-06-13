package Tarp::PullCSV::book;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub heading { "BookID" }

# Kathi, if there is any special "translation" between the book name
# as it appears in the filename and the chapter name as it appears in the
# CSV file, we put an entry below.

# For example, here it says that every time "4c" is contained by the filename's
# "book" variable (ask me if you don't know what this means),
# the CSV file should say "4c3"

my %XL = (
    "4c" => "4c3",
    "6e" => "6et",
);

# Shouldn't need to touch below here! #########################################

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;

    if ( @_ ) {
        $self->{book} = shift;
    } else {
        warn "Warning: 'book' column requires an argument\n";
        $self->{book} = '';
    }
    
    return $self;
}

# Return translation of the argument (if it exists) or just the original argument
sub value {
    my $self = shift;
    my $b = $self->{book};
    return unless defined $b;
    return $XL{ $b } ? $XL{ $b } : $b;
}

1;
