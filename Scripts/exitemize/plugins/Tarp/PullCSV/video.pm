package Tarp::PullCSV::video;

use strict;
use base qw/Tarp::PullCSV::Column/;

# Change heading here
sub heading { "Video" }

sub value {
    my $self = shift;
    my $listData = shift;
    my ( $exBuffer ) = @{$listData}{ qw/ exBuffer / };
        
    for ( @$exBuffer ) {
        return 1 if /VIDEO/;
    }

    return 0;
}

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    return $self;
}

1;
