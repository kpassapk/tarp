package Tarp::PullCSV::section;

use strict;
use base qw/Tarp::PullCSV::Column/;

sub requireArg { 1 }

=pod

    $s = Tarp::PullCSV::section->new( $csv, "foo,bar" );

Uses sections foo and bar

=cut

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $sections;
    if ( @_ ) {
        $sections = shift;
    } else {
        warn "Warning: column requires an argument\n" unless @_;
    }
    
    my $self = bless $class->SUPER::new( $csv ), $class;
    $self->{sections} = defined $sections ? [ split /,/, $sections ] : [];
    return $self;
}

sub heading { "Section" }

sub preProcess {
    my $self = shift;
    my $args = shift;
    
#    use Data::Dumper;
#    warn Dumper $args;
    
    my $fs = @{$args->{listData}};   # How many sections were found
    my $gs = @{$self->{sections}}; # How many sections were given
    warn "$fs numbering sequence(s) found, but $gs section name(s) given: " ,
        "@{$self->{sections}}\n" unless $fs == $gs;
}

sub value {
    my $self = shift;
    my $args = shift;
    
    return $self->{sections}->[ $args->{exSeq} ];
}

1;
