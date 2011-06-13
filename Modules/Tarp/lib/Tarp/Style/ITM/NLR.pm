package Tarp::Style::ITM::NLR;

=head1 NAME

Tarp::Style::ITM::NLR - Number, Letter, Roman style

=cut

use strict;
use Carp;

use Tarp::Counter::Numeric;
use Tarp::Counter::Latin;
use Tarp::Counter::Roman;

=head1 METHODS

=head2 new

    Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
    $sty = Tarp::Style->new();

Creates a new NLR style.

=cut

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;

    my @fmats = (
        'Tarp::Counter::Numeric', # level 1
        'Tarp::Counter::Latin',   # level 2
        'Tarp::Counter::Roman'    # level 3
    );

    my @fmatObjs = ();
    foreach ( @fmats ) { push @fmatObjs, $_->new() }    

    $self->{_FMATS} = \@fmatObjs;
    
    return $self;
}

=head2 postRead

    (not user callable)

Sets itemTag_0_::ITM, itemTag_1_::ITM, itemTag_2_::ITM to regexps matching a number, letter,
and roman numeral, respectively.  Sets itemString::ITM to a three item list matching
a letter, number and roman numeral in string context.

=cut

sub postRead {
    my $self = shift;
    my $tas = shift;
    
    my $_fmats = $self->{_FMATS};

    for ( my $i = 1; $i < 4; $i++ ) {
        $tas->{"itemTag_$i\_"}->[-1]->{ITM}->[0]
            = $_fmats->[$i-1]->matchTex();
        $tas->{itemString}->[-1]->{ITM}->[$i-1]
            = $_fmats->[$i-1]->matchStr();
    }
    
    1;
}

sub _itemString2itemStack {
    my $self = shift;
    my $o = $_[1];
    my @x;

    for ( my $i = 0; $i < @$o; $i++ ) {
        next unless defined $o->[$i];
        push @x, $self->{_FMATS}->[$i]->revStr( $o->[$i] );
    }
    
    return \@x;
}

sub _itemStack2itemString {
    my $self = shift;
    my $o = $_[1];
    my @x;

    for ( my $i = 0; $i < @$o; $i++ ) {
        next unless defined $o->[$i];
        push @x, $self->{_FMATS}->[$i]->fwdStr( $o->[$i] );
    }
    
    return \@x;
}

sub _itemSplit2itemStack {
    my $self = shift;
    my $o = $_[1];
    my @x;

    for ( my $i = 0; $i < @$o; $i++ ) {
        next unless defined $o->[$i];
        push @x, $self->{_FMATS}->[$i]->revTex( $o->[$i] );
    }
    
    return \@x;    
}

sub _itemStack2itemSplit {
    my $self = shift;
    my $o = $_[1];
    my @x;

    for ( my $i = 0; $i < @$o; $i++ ) {
        next unless defined $o->[$i];
        push @x, $self->{_FMATS}->[$i]->fwdTex( $o->[$i] );
    }
    
    return \@x;
}

sub _itemStack2itemTag_1_ {
    my $self = shift;
    my $o = $_[1];
    
    return [ $self->{_FMATS}->[0]->fwdTex( $o->[ 0 ] ) ];
}

sub _itemTag_1_2itemStack {
    my $self = shift;
    my $o = $_[1];
    return [ $self->{_FMATS}->[0]->revTex( $o->[0] ), undef, undef ]
}

sub _itemStack2itemTag_2_ {
    my $self = shift;
    my $o = $_[1];
    my @x;

    return [ $self->{_FMATS}->[1]->fwdTex( $o->[ 1 ] ) ];    
}

sub _itemTag_2_2itemStack {
    my $self = shift;
    my $o = $_[1];
    return [ undef, $self->{_FMATS}->[1]->revTex( $o->[0] ), undef ]    
}

sub _itemStack2itemTag_3_ {
    my $self = shift;
    my $o = $_[1];
    my @x;

    return [ $self->{_FMATS}->[2]->fwdTex( $o->[ 2 ] ) ];        
}

sub _itemTag_3_2itemStack {
    my $self = shift;
    my $o = $_[1];
    return [ undef, undef, $self->{_FMATS}->[2]->revTex( $o->[0] ) ];    
}

=pod

sub itemString {
    my $self = shift;
    my $es = shift;
    
    croak "Argument should be an arrayref, stopped"
        unless ref $es eq "ARRAY";
    
    my ( $format, $_FORMATOBJS )
        = @{$self}{ qw/_LEVTAGS _FMATS/ };
    
    return undef if @$es > @$format;
    
    my $exStr = '';
    for ( my $i = 0; $i < @$es; $i++ ) {
        $exStr .= $self->{_FMATS}->[$i]->fwdStr( $es->[ $i ] );
    }
    return $exStr;
}

=cut

=pod

sub itemStack {
    my $self = shift;
    my $str = shift;
    
    croak "Undefined argument, stopped"
        unless defined $str;
        
    return [] if $str eq '';
    
    my @es = ();
    
    my ( $format, $_FORMATOBJS )
        = @{$self}{ qw/_LEVTAGS _FMATS/ };
    
    my $qrs = $self->qr( "itemString" );
    $_ = $str;
    if ( $str =~ $qrs->[0] ) {
        my $mem = $-{ITM};
        for ( my $i = 0; $i < @$mem; $i++ ) {
            next unless defined $mem->[$i];
            push( @es, $self->{_FMATS}->[$i]->revStr( $mem->[$i] ) );
        }
    }
    
    return @es ? \@es : undef;
}

=cut

1;
