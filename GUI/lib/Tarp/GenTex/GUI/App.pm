package Tarp::GenTex::GUI::App;

use base qw/ Tarp::GenTex::GUI /;
use strict;

my %fields = (
    args => '',
);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    @{$self}{keys %fields} = values %fields;
    bless $self, $class;
    return $self;
}

sub cancelClicked {}

sub okClicked {
    my $self = shift;
    
    my ( $genOutput, $genTemplates, $vars )
        = @{$self}{ qw/genOutput genTemplates vars/};
    
    my $command = "tagentex";
    if ( $genOutput ) {    
        while ( my ( $var, $value ) = each %$vars ) {
            $command .= " --var=\"$var;$value\"";
        }
        $self->_goCommand( $command . ' ' . $self->{args} );
    }
    
    if ( $genTemplates ) {
        $self->_goCommand( "tagentex --master-templates --template-dir=new " . $self->{args} );
    }
}

sub _goCommand {
    my $self = shift;
    my $command = shift;
    print "\nExecuting:\n" . $command . "\n\n";    
    system( $command );
}

1;
