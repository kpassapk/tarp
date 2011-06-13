package Tarp::LaTeXcombine::GUI;

use base qw/Tarp::Dialog/;

use Tarp::Config;

use strict;
use Carp;

my %fields = (
    PKlist      => '',
    pkIDs       => undef,
    pkFiles     => undef,
    hitCount    => undef,
    filesExist  => undef,
    preFrom     => "new",
    newPreamble => '',
    preTemplates => undef,
);

sub new {
    my $class = shift;
    
    my $self = $class->SUPER::new( @_ );
    
    foreach my $element ( keys %fields ) {
        $self->{_permitted}->{$element} = $fields{$element};
    }
    
    @{$self}{keys %fields} = values %fields;
    
    $self->{pkIDs}       = [];
    $self->{pkFiles}     = {};
    $self->{hitCount}   = [];
    $self->{filesExist} = [];
    $self->{preTemplates} = [];
    $self->{_btnAssign}  = {};
    $self->{_okButton}   = undef,
    $self->{_newPreFrame} = undef,
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
    
    my ( $frame, $pkIDs, $pkFiles, $preFrom, $PKlist, 
         $hitCount, $filesExist, $_btnAssign )
        = @{$self}{qw/ _frame pkIDs pkFiles preFrom PKlist
                   hitCount filesExist _btnAssign /};
    
    my %pkFiles = %$pkFiles;
    my @pkFiles = @pkFiles{@$pkIDs};

    my $pkframe =  $frame->new_ttk__labelframe( -text => "$PKlist pickup files" );
    $pkframe->g_grid( -column => 0, -row => 0, -sticky => "nesw" );
    $pkframe->g_grid_columnconfigure( 2, -weight => 1);
    
    $pkframe->new_ttk__label( -text => "exists?" )
        ->g_grid( -row => 0, -column => 3 );
    
    # Make a row for each pkID containing labels, entry, Browse button.
    for ( my $i = 0; $i < @$pkIDs; $i++ ) {
        my $id = $pkIDs->[ $i ];
        
        $pkframe->new_ttk__label( -text => $id )
            ->g_grid( -column => 0, -row => $i + 1 );
        
        my $hits = $hitCount->[ $i ] > 1 ? " hits" : " hit";
        $pkframe->new_ttk__label( -text => "(" . $hitCount->[ $i ] . $hits . ")" )
            ->g_grid( -column => 1, -row => $i + 1 );
            
        my $entry = $pkframe->new_ttk__entry(
            -width            => 20,
            -textvariable     => \$pkFiles->{ $id },
            -validate         => "all",
            -validatecommand  => sub { $self->validate(); 1 } # 1 return code
        );
        
        $entry->m_configure( -state => "disabled" ) if $pkFiles[ $i ] eq "(virtual)";
        
        $entry->g_grid( -column => 2, -row => $i + 1, -sticky => "we" );
        
        $pkframe->new_ttk__label( -textvariable => \$filesExist->[ $i ] )
            ->g_grid( -column => 3, -row => $i + 1);
        
        my $btn = $pkframe->new_ttk__button(
            -text    => "Browse",
        );
        
        $btn->g_grid( -column => 4, -row => $i + 1);
        
        $_btnAssign->{ $btn->_mpath() } = $i;
        
        $btn->m_configure(
            -command => sub {
                my $f = Tkx::tk___getOpenFile();
                my $id = $pkIDs->[ $_btnAssign->{ $btn->_mpath() } ];
                $pkFiles->{$id} = $f if $f;
                $self->validate();
            }
        );
        
        $btn->m_configure(
            -state => "disabled"
        ) if $pkFiles[ $i ] eq "(virtual)";
    }
    
    # Pad each element in pkframe
    foreach ( Tkx::SplitList( $pkframe->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 5);
    }
    
    ########## Preamble ########################################################
    my $preFrame = $frame->new_ttk__labelframe( -text => "Preamble" );
    $preFrame->g_grid( -column => 1, -row => 0, -sticky => "nesw" );
    
    for ( my $i = 0; $i < @$pkIDs; $i++ ) {
        my $id = $pkIDs->[ $i ];
        my $b = $preFrame->new_ttk__radiobutton(
            -text         => $id,
            -variable     => \$self->{preFrom},
            -command      => sub { $self->preambleChange( $self->{preFrom} ); },
            -value        => $id
        );
        $b->g_pack();
        
        # Select the first button in this list when the widget is created.
        if ( $i == 0 ) {
            Tkx::after( 0, sub { $b->m_invoke(); } );
        }
    }
    
    foreach ( Tkx::SplitList( $preFrame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 3);
    }
    
    ###### New Preamble Frame ##################################################

    my $newPreFrame = $frame->new_ttk__labelframe( -text => "Canned Preambles" );
    $newPreFrame->g_grid( -column => 0, -row => 1, -rowspan => 2, -sticky => "nesw" );
    $newPreFrame->g_grid_columnconfigure( 1, -weight => 1 );
    
    $newPreFrame->new_ttk__label(
        -text => "Use this canned preamble: "
    )->g_grid( -row => 0, -column => 0 );
    
    $newPreFrame->new_ttk__combobox(
        -textvariable   => \$self->{newPreFrom},
        -values         => $self->{preTemplates},
    )->g_grid( -row => 0, -column => 1 );
    
    my $info = $newPreFrame->new_ttk__label(
        -text => "This list contains preambles found in " . $self->templateDir(),
    );
    
    $info->m_configure( -wraplength => 400 );
    $info->g_grid( -row => 1, -column => 0, -columnspan => 2 );
    
    # OK and Cancel Buttons
    
    my $okButton = $frame->new_ttk__button(
        -text       => "OK",
        -command    => sub { $self->okClicked(); $self->destroy(); },
    );
    
    $okButton->g_grid( -column => 1, -row => 1 );
    
    $frame->new_ttk__button(
        -text => "Cancel",
        -command => sub {
            $self->cancelClicked();
            $self->destroy();
            exit( 255 );
    })->g_grid( -column => 1, -row => 2 );
    
    $frame->g_grid_columnconfigure( 0, -weight => 1);
    
    foreach ( Tkx::SplitList( $frame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 5);
    }

    $self->{_okButton} = $okButton;
    $self->{_newPreFrame} = $newPreFrame;
    
    $self->validate();
}

sub templateDir {
    my $self = shift;
    return '';
}

sub preambleChange {
    my $self = shift;
#    print "Preamble Change\n";
}

sub _guessFileName {
    my $self = shift;
    my $pkID = shift;
    
    my ( $PKlist ) = @{$self}{qw/ PKlist /};

    my $stub = $pkID;
    $stub =~ s/_\d+$//;
    $stub =~ s/\d$//;
    my $rest = $PKlist;
    $rest =~ s/^.*?(\d.*)$/$1/;
    
    if ( $rest eq $PKlist ) {
        return $stub . "_file.tex";
    }
    return $stub . $rest;
}

sub validate {
    my $self = shift;
    my ( $pkIDs, $pkFiles, $filesExist, $_okButton )
        = @{$self}{qw/pkIDs pkFiles filesExist _okButton/};
 
    my %pkFiles = %$pkFiles;
    my @pkFiles = @pkFiles{ @$pkIDs };
    my $missing = '';
    
    for ( my $i = 0; $i < @$pkIDs; $i++ ) {
        my $e;
        if ( $pkIDs->[ $i ] eq "new" ) {
            $e = 1;
        } else {
            $e = -e $pkFiles[ $i ] ? 1 : '';
            $missing = $missing || ! $e;
        }
        my $labelText = $e ? "yes" : "no";
        $filesExist->[ $i ] = $labelText;
    }
    if ( ! $missing ) {
        $_okButton->m_configure( -state => "enabled" );
    } else {
        $_okButton->m_configure( -state => "disabled" );
    }
}

sub okClicked {}

sub cancelClicked {}

1;
