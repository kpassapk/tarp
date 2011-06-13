package Tarp::Counter::Roman;

=head1 NAME

Tarp::Counter::Roman - Item counter format for Roman numerals

=head1 SYNOPSIS

    use Tarp::Counter::Roman;
    
    
=cut

use base qw/ Tarp::Counter /;

use strict;
use warnings;

=head2 new

    $counter = Tarp::Counter::Roman->new();

Creates a new counter in Roman format

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    my @fwd = qw/ dummy i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx/;
    my %rev;
    @rev{ @fwd } = 0 .. 20;
    my @match = @fwd;
    shift( @match ); # remove "dummy".
    
    my $mstr = "(?:" . join('|', @match ) . ")";
    $self->{fwd} = \@fwd;
    $self->{rev} = \%rev;
    $self->{matchTex} = $mstr; # TeX and string representations are the same
    $self->{matchStr} = $mstr;
    
    bless $self, $class;
    return $self;
}

1;