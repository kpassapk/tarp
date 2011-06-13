package Tarp::PullCSV::update_date;

use strict;
use Time::localtime;

use base qw/Tarp::PullCSV::Column/;

# Change heading here
sub heading { "UpdateDate" }

# Return translation of the argument (if it exists) or just the original argument
sub value { sprintf "%d/%d/%d",
            localtime->mon() + 1, localtime->mday(), localtime->year() + 1900 }

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    return $self;
}

1;
