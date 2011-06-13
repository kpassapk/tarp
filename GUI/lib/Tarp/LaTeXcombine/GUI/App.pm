package Tarp::LaTeXcombine::GUI::App;

use base qw/ Tarp::LaTeXcombine::GUI /;
use strict;

use Tarp::Config;
use Cwd;
use Carp;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    bless $self, $class;
    return $self;
}

sub aboutToCreateGUI {
    my $self = shift;
    $self->_loadTemplateNames();
    $self->_readPickupList();
    $self->_getDefaults();
}

sub templateDir {
    my $self = shift;
    my $resDir = Tarp::Config->ResourceDir();
    die "Tarp resource directory '$resDir' not installed!\n" unless -e $resDir;
    my $templateDir = File::Spec->catfile( $resDir, "templates", "preambles" );
    return $templateDir;
}

sub _loadTemplateNames {
    my $self = shift;
    
    my $templateDir = $self->templateDir();
    
    my $lastDir = cwd;
    chdir $templateDir or croak "Could not chdir to $templateDir: $!, stopped";
    my @preTemplates = <*.txt>;
    chdir $lastDir;
    
    foreach ( @preTemplates ) {
        s/\.txt$//;
    }    
    
    $self->{preTemplates} = \@preTemplates;
}

# load pkIDs and hitCount

sub _readPickupList {
    my $self = shift;
    
    my ( $PKlist, $_hitCount )
        = @{$self}{qw/PKlist _hitCount/};
    
    # Load unique pickup IDs

    my %fids;
    open( PKLIST, '<', $PKlist ) or die "Could not open '$PKlist' for reading: $!, stopped";
    while ( <PKLIST> ) {
        my ( undef, $file ) = split /\s+/;
        $fids{ $file } = exists $fids{ $file } ? ++$fids{ $file } : 1;
    }
    close PKLIST;
    
#    use Data::Dumper;
#    print Dumper \%fids;
    
    my %hts = (); # Artificial hit count
    
    my @fids = reverse sort keys %fids;

    # This weird bit ensures 6et_2 comes after 6et, and so on, if they happen
    # to have the same hit count.  Breaks if there are more than ten pickups
    # with the same hit count, but this is unlikely. Ugly but it works.
    foreach my $id ( @fids ) {
       my $c = $fids{ $id };
       my $t = $c * 10;
       my $d = 0;
       $d++ while exists $hts{ $t + $d };
       $hts{ $t + $d } = $id;
    }

    # Sort by hit count
    my @hts = reverse sort { $a <=> $b } keys %hts;
    my @pkIDs = @hts{ @hts };
    my @hitCount = @fids{ @pkIDs };
    
    # Add a "new" at the end of @pkIDs with zero hits if it is not there
    # already. 

    unless ( $fids{new} ) {
        push( @pkIDs, "new" );
        push( @hitCount, 0 );
    }
    @{$self}{ qw/pkIDs hitCount/ } = ( \@pkIDs, \@hitCount );
}

sub _getDefaults {
    my $self = shift;
        
    my ( $pkIDs, $pkFiles ) = @{$self}{qw/pkIDs pkFiles/};

    # Load default if not found in section data

    for ( my $i = 0; $i < @$pkIDs; $i++ ) {
        my $pkID = $pkIDs->[ $i ];
        next if $pkFiles->{ $pkID };
        if ( $pkID eq "new" ) {
            $pkFiles->{ $pkID } = "(virtual)";
        } else {
            $pkFiles->{ $pkID } = $self->_guessFileName( $pkIDs->[ $i ] );
        }
    }
}

sub preambleChange {
    my $self = shift;
    my $changedTo = shift;
    
    my $newPreFrame = $self->{_newPreFrame};
    
    my $state;
    if ( $changedTo eq "new" ) {
        $state = "!disabled";
    } else {
        $state = "disabled";
    }
    
    $newPreFrame->m_state( $state );
    foreach ( Tkx::SplitList( $newPreFrame->g_winfo_children ) ) {
        my $obj = Tkx::widget->new( $_ );
        $obj->m_configure( -state => $state );
    }
}

# Reads a pickup list and loads hitCount and pkIDs.
sub okClicked {
    my $self = shift;
    $self->goCommand();
}

sub cancelClicked {}

sub _buildCommand {
    my $self = shift;
        my $command = "talatexcombine";

    my ( $pkIDs, $pkFiles, $preFrom, $newPreFrom, $PKlist )
        = @{$self}{qw/pkIDs pkFiles preFrom newPreFrom PKlist/};
    
    my @pkIDs = @$pkIDs;
    my %pkFiles = %$pkFiles;
    my @pkFiles = @pkFiles{@pkIDs};
    
    for ( my $i = 0; $i < @pkIDs; $i++ ) {
        my $id   = $pkIDs[ $i ];
        my $file = $pkFiles[ $i ];
        $command .= " --pk=\"$id;$file\"" unless $id eq "new";
    }
    $command .= " --preamble-from=$preFrom";
    
    if ( $preFrom eq "new" && $newPreFrom ne "standard" ) {
        $command .= ";$newPreFrom";
    }
    
    $command .= " " . $PKlist;

    return $command;
}

sub printCommand {
    my $self = shift;
    my $command = $self->_buildCommand;
    print $command . "\n\n";
}

sub goCommand {
    my $self = shift;
    my $command = $self->_buildCommand;
    print "\nExecuting:\n" . $command . "\n\n";    
    system( $command );
}

1;
