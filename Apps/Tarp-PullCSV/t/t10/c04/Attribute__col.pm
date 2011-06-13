# This is an automatically generated template adapter
# Any changes made to this file will be lost!

package Attribute__col;

use base qw/Tarp::Itexam::Attribute/;

my %fields = (
    colRef => undef,
);

sub new {
    my $class = shift;
    my $name = shift;
    my $exm = shift;
    my $self = $class->SUPER::new( $name, $exm );

    foreach my $element ( keys %fields ) {
        $self->{_permitted}->{$element} = $fields{$element}; 
    }
    
    bless $self, $class;
    return $self;
}

sub preProcess {
    my $self = shift;
    return $self->{colRef}->preProcess(  );
}

sub value {
    my $self = shift;
    return $self->{colRef}->value(  );
}

1;

