package Tarp::Dialog;

use strict;
use Tkx;
Tkx::package_require("tile");
use File::Copy;
use Carp;

our $AUTOLOAD;

my %fields = (
    title => "Tarp Dialog",
);

sub new {
    my $class = shift;
    my $parent = shift || ".";
    
    my $self = {
        %fields,
        _mainWin   => undef,
        _frame     => undef,
    };
    
    bless $self, $class;
    $self->_init( $parent );
    return $self;
}

sub _init() {
    my $self = shift;
    my $parent = shift;
    
    my $title = $self->{title};
    my $mainWin = Tkx::widget->new( "." );

    $mainWin->g_wm_title( $title );

    my $xPos = $mainWin->g_winfo_screenwidth() / 2.0 - 200;
    my $yPos = $mainWin->g_winfo_screenheight() / 2.0 - 200;
    
    $mainWin->g_wm_geometry( "+$xPos+$yPos" );
    
    # Create a themed frame that covers the whole window area
    my $frame = $mainWin->new_ttk__frame();
    
    $frame->g_grid( -sticky => "nwes" );
    $mainWin->g_grid_columnconfigure(0, -weight => 1);
    $mainWin->g_grid_rowconfigure   (0, -weight => 1);
    
    @{$self}{qw/_mainWin _frame/} = ( $mainWin, $frame );
}

sub title {
    my $self = shift;

    if ( @_ ) {
        my $newTitle = shift;
        $self->{_mainWin}->g_wm_title( $newTitle );
        return $self->{title} = $newTitle;
    } else {
        return $self->{title};
    }
}

sub destroy {
    my $self = shift;
    $self->{_mainWin}->g_destroy();
}

sub AUTOLOAD {
    my $self = shift;
    
    our $AUTOLOAD;
    
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless ( exists $self->{$name} && $name =~ /^[a-z]/i ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }

}

sub DESTROY {}

1;
