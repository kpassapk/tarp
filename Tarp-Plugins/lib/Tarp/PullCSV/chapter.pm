package Tarp::PullCSV::chapter;

use strict;
use base qw/Tarp::PullCSV::Column/;

# Change heading here
sub heading { "Chapter" }

# Kathi, if there is any special "translation" between the chapter name
# as it appears in the filename and the chapter name as it appears in the
# CSV file, we put an entry below.

# For example, here it says that every time "apdx" is contained by the filename's
# "chapter" variable (ask me if you don't know what this means),
# the CSV file should say "Appendix"  (surely not right but you get the idea)

my %XL = (
    apdx => "Appendix",
);

# Shouldn't need to touch below here! #########################################

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    if ( @_ ) {
        $self->{chapter} = shift;        
    } else {
        warn "Warning: 'chapter' column requires an argument\n" unless @_;
        $self->{chapter} = '';
    }
    return $self;
}

# Return translation of the argument (if it exists) or just the original argument
sub value {
    my $self = shift;
    my $c = $self->{chapter};
    return unless defined $c;
    return $XL{ $c } ? $XL{ $c } : $c;
}

1;
