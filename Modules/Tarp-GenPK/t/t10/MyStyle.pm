package MyStyle;
use strict;

sub new {
    my $class = shift;
    my $self = bless $class->SUPER::new(), $class;
    return $self;
}

sub _heading_EX2filename {
    my $self = shift;
    return $self->_subName( @_ );
}

sub _heading_PKEX2filename {
    my $self = shift;
    return $self->_subName( @_ );
}

sub _csv_string2filename {
    my $self = shift;
    my $var= shift;
    my $vals = shift;
    
    if ( $var eq "section" ) {
        map { tr/[A-Z]/[a-z]/ } @$vals;
    }
    return $vals;
}

sub _subName {
    my $self = shift;
    my ( $v ) = @{$_[1]};
    $v =~ s/\d$//;
    return [ $v ];    
}

1;
