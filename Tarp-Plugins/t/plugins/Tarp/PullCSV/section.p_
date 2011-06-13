package Tarp::PullCSV::section;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub heading { "Section" }

# Kathi, if there is any special "translation" between the section name
# as it appears in the filename and the section name as it appears in the
# CSV file, we put an entry below.

# For example, here it says that every time "r" is contained by the filename's
# "section" variable (ask me if you don't know what this means),
# the CSV file will have three sections, RX,CC, and TF.

my %XL = (
    pps => [ "PP" ],
    pp  => [ "PP" ],
    r   => [ "dummy",  "CC", "TF", "R" ],
);

# Shouldn't need to touch below here! #########################################

sub new {
    my $class    = shift;
    my $csv      = shift;
    my $sections = $_[0] ? shift : ''; # comma separated list
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    
    if ( defined $sections ) {
        $sections = $XL{ $sections } ?
            $XL{ $sections } : [ split /,/, $sections ];
    } else {
        warn "Warning: 'section' column requires an argument\n" unless @_;
        $sections = [];
    }
    $self->{sections} = $sections;
    return $self;
}

# Complanin if the user gave the wrong amount of sections...
sub preProcess {
    my $self = shift;
    my $args = shift;
    
    my $fs = @{$args->{listData}};   # How many sections were found
    my $gs = @{$self->{sections}}; # How many sections were given
    
    # Is there only one seq with exercises and one given section? Use it.
    # Otherwise complain and automatically number the sections.
    
    if ( $gs == 1 ) {
        my @exCount = map { 0 + keys %$_ } @{ $args->{listData} };
        if ( ( grep { $_ > 0 } @exCount ) == 1 ) {
            $self->{sections} = [ map { $self->{sections}->[0] } @exCount ];
        }
    } else {
        warn "Warning: $fs numbering sequence(s) found, but $gs section name(s) given: " ,
            "@{$self->{sections}}\n" unless $fs == $gs;
        for ( my $i = 0; $i < $fs; $i++ ) {
            $self->{sections}->[$i] = "section " . ( $i + 1 )
                unless defined $self->{sections}->[$i];
        }
    }
}

sub value {
    my $self = shift;
    my $args = shift;
    return $self->{sections}->[ $args->{exSeq} ];
}

1;
