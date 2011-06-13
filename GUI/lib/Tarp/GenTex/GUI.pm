package Tarp::GenTex::GUI;
use base qw/Tarp::Dialog/;

use strict;
use Carp;

my %fields = (
    PKlist       => '',
    OUTfile      => '',
    vars         => undef,
    genOutput    => 1,
    genTemplates => 1,
);

sub new {
    my $class = shift;
    
    my $self = $class->SUPER::new( @_ );
        
    @{$self}{keys %fields} = values %fields;
    
    $self->{vars} = {};
    
    bless $self, $class;
    return $self;
}

sub create {
    my $self = shift;
    $self->aboutToCreateGUI();
    $self->createGUI();
    $self->doneCreatingGUI();
}

sub aboutToCreateGUI {}

sub doneCreatingGUI {}

sub createGUI {
    my $self = shift;
    my ( $PKlist, $OUTfile, $vars ) = @{$self}{qw/PKlist OUTfile vars/};
    my $frame = $self->{_frame};
    
    my $topFrame = $frame->new_ttk__labelframe( -text => "Output file: $OUTfile" );
    my $midFrame = $frame->new_ttk__frame();
    my $btnFrame = $frame->new_ttk__frame();
    
    $topFrame->g_grid( -row => 0, -column => 0, -sticky => "nwes", -padx => 5, -pady => 5 );
    $midFrame->g_grid( -row => 1, -column => 0, -sticky => "nwes", -padx => 5, -pady => 5 );
    $btnFrame->g_grid( -row => 2, -column => 0, -sticky => "nwes" );
    
    $frame->g_grid_columnconfigure( 0, -weight => 1 );
    $frame->g_grid_rowconfigure( 0, -weight => 1 );
    $frame->g_grid_rowconfigure( 1, -weight => 1 );
    
    $topFrame->new_ttk__checkbutton(
        -text => "Generate output",
        -variable => \$self->{genOutput}
    )->g_grid( -row => 0, -column => 0, -columnspan => 2, -sticky => "w" );
    
    $topFrame->g_grid_columnconfigure( 1, -weight => 1 );
    
    $midFrame->new_ttk__checkbutton(
        -text => "Generate master templates (ms*.tex)",
        -variable => \$self->{genTemplates}
    )->g_grid( -row => 0, -column => 0, -sticky => "w" );
    
    my $okButton = $btnFrame->new_ttk__button(
        -text => "OK",
        -command => sub { $self->okClicked(); $self->destroy(); }
    )->g_grid( -row => 0, -column => 1 );
    
    my $cancelButton = $btnFrame->new_ttk__button(
        -text => "Cancel",
        -command => sub { $self->cancelClicked(); $self->destroy(); exit 255; },
    )->g_grid( -row => 0, -column => 2 );
    
    $btnFrame->g_grid_columnconfigure( 0, -weight => 1 );
    
    foreach ( Tkx::SplitList( $btnFrame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 5);
    }

    $topFrame->new_ttk__label( -text => "Variable substitutions:" )
        ->g_grid( -row => 1, -columnspan => 2, -sticky => "w" );
    
    my $row = 2;
    while ( my ( $var, $value ) = each %$vars ) {
        $topFrame->new_ttk__label( -text => "$var:" )
            ->g_grid( -row => $row, -column => 0, -sticky => "e" );
        $topFrame->new_ttk__entry( -width => 10, -textvariable => \$vars->{$var}, )
        ->g_grid( -row => $row, -column => 1, -sticky => "nwes" );
        $row++;
    }
    
    if ( ! keys %$vars ) {
        $topFrame->new_ttk__label( -text => "(none)" )
            ->g_grid( -row => 2, -columnspan => 2 );
    }

    # Pad each element in pkframe
    foreach ( Tkx::SplitList( $topFrame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 5);
    }
}

sub okClicked {}

sub cancelClicked {}

1;
