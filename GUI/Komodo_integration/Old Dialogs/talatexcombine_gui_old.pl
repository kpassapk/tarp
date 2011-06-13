#!/usr/bin/perl -w
use strict;

=head1 NAME

talatexcombine_gui.pl:  GUI front end for talatexcombine.

=head1 SYNOPSIS

talatexcombine_gui.pl [options]

Options:

    f=[file.pklist]     File base name

This program is meant to be used from Komodo.  Use talatexcombine for instructions
on the command line interface.

=cut

use Tkx;
Tkx::package_require("tile");
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;

use Tarp::PickupList;
use Tarp::StyleHelper;

# Turn warnings fatal b/c I want to complain nicely about errors while
# eval'ing the PACKLIST.
BEGIN { $SIG{'__WARN__'} = sub { die $_[0]; }; }

### The Output #################################################################
my $PKlist  = '';
my @pkIDs   = ();
my @pkFiles = ();

my $preFrom = "new";

sub printCommand {
    my $command = "talatexcombine";
    
    for ( my $i = 0; $i < @pkIDs; $i++ ) {
        my $id   = $pkIDs[ $i ];
        my $file = $pkFiles[ $i ];
        $command .= " --pk=\"$id;$file\"" unless $id eq "new";
    }
    $command .= " --preamble-from=$preFrom";
    $command .= " " . $PKlist;
    
    print "Executing:\n" . $command . "\n";
    
    system( $command );
}

### Aux Variables ##############################################################

# Other variables that help out in filling the dialog box
# From pickup file ID to hit count
my %hitCount = ();

# "yes" if files exist, "no" otherwise (same order as pkIDs)
my @filesExist = ();

# Browse button assignment: from button name to pickup file index
my %btnAssign;

my $okButton;

my $chapter = '';

my $section = '';


### Functions ##################################################################

sub _readTASfile {
    my $TASfile = shift || '';

    my $hlp = Tarp::StyleHelper->new();
    
    eval '$hlp->loadTASfile( $TASfile )';
    
    if ( ! $@ ) {
        my $DS = $hlp->entry( "DESCRIPTOR", Tarp::StyleHelper::INTERPOLATE () );
        
            ENTRY: foreach my $ds ( @$DS ) {
                if ( $PKlist =~ /$ds/ ) {
                    $chapter  ||= $-{CHAPTER}[0] if $-{CHAPTER};
                    $section  ||= $-{SECTION}[0] if $-{SECTION};
    
                    last ENTRY;
                } else {
                    print "(hint: if you want better guesses, edit DESCRIPTOR in your TAS file " ,
                        "to match the filename of your pickup list.)\n";
                }
            }
    } else { die $@; }
}

# Reads a pickup list and loads @hitCount and @pkIDs.
sub readPickupList {
    # Load unique pkIDs
    my $pkList = Tarp::PickupList->new();
    
    $pkList->read( $PKlist );
    
    # hit count to 
    my %hts = ();
    
    my @fids = reverse sort $pkList->fileIDs();
    
    foreach my $id ( @fids ) {
       my $c = $pkList->pickupCount( $id );
       $hitCount{ $id } = $c;
       my $t = $c * 10;
       my $d = 0;
       $d++ while exists $hts{ $t + $d };
       $hts{ $t + $d } = $id;
    }
    # 
    # Sort in order of relevance
    my @hts = reverse sort { $a <=> $b } keys %hts;
    @pkIDs = @hts{ @hts };
}

# Read PACKLIST.txt and give all sorts of helpful messages telling the user
# whether it loaded OK, and if not what the program is doing. The purpose
# is to load the @pkFiles array with good approximations of the file names
# being used.

sub readPackList {
    # Read PACKLIST.TXT or load default file names.
    
    if ( -e "PACKLIST.txt" ) {
        
        open( PACKLIST, "PACKLIST.txt" )
            or die "Could not open PACKLIST.txt: $!, stopped";

        my $VAR1;
        
        local $/;
        undef $/;
        my $str = <PACKLIST>;
        close PACKLIST;
    
        eval "$str";
        
        if ( $@ ) {
            print STDERR "Your beautifully crafted PACKLIST.txt does not seem to be kosher PERL.\n" ,
            "Perl complained about the following:\n";
            my $err = $@;
            $err =~ s/\(eval.*?\)/PACKLIST\.txt/;
            warn $err;
        }
        my $sectionData = $VAR1->{ $section };
        
        my $gotIt = '';
        
        if ( $sectionData ) {
            # print "Found section $section in PACKLIST.txt\n";
            for ( my $i = 0; $i < @pkIDs; $i++ ) {
                my $pkID = $pkIDs[ $i ];
                my $f = $sectionData->{$pkID};
                if ( $f ) {
                    $pkFiles[ $i ] = $f;
                    print "Got $pkID => $f from PACKLIST.txt\n";
                    $gotIt = 1;
                }
            }
        }
        
        print "Opened PACKLIST.txt but did not find the fileIDs we need. ",
            "Guessing filenames...\n" unless $gotIt;
    } else {
        print "PACKLIST.txt not found; no worries, will guess filenames...\n";
    }
    # Load default if not found in section data
    for ( my $i = 0; $i < @pkIDs; $i++ ) {
        next if $pkFiles[ $i ];
        if ( $pkIDs[ $i ] eq "new" ) {
            $pkFiles[ $i ] = "(virtual)";
        } else {
            $pkFiles[ $i ] = _guessFileName( $pkIDs[ $i ] );
        }
    }
}

sub _guessFileName {
    my $pkID = shift;
    
    # If pickup list can be matched against DESCRIPTOR,
    # then break it up into chapter and section and append these to the
    # stub of the pickup list filenames. Otherwise, just increment an integer
    # to the end of the stub and then put .tex on it.
    my $stub = $pkID; $stub =~ s/_.*$//; $stub =~ s/\d$//;
    my $guess = $stub . "_file.tex";

    if ( $chapter && $section ) {
        $guess = $stub . $chapter . $section . ".tex";
    }
    return $guess;
}

sub createDialog {
    my $mainWin = Tkx::widget->new(".");

    my $xPos = $mainWin->g_winfo_screenwidth() / 2.0 - 200;
    my $yPos = $mainWin->g_winfo_screenheight() / 2.0 - 200;
    
    $mainWin->g_wm_geometry( "+$xPos+$yPos" );
    
    $mainWin->g_wm_title( "Tarp LaTeXcombine" );
    
    # Create a themed frame that covers the whole window area
    my $frame = $mainWin->new_ttk__frame();
    
    $frame->g_grid(-sticky => "nwes");
    $mainWin->g_grid_columnconfigure(0, -weight => 1);
    $mainWin->g_grid_rowconfigure   (0, -weight => 1);
    
    ########## Pickup Files ####################################################

    my $pkframe =  $frame->new_ttk__labelframe( -text => "Pickup Files" );
    $pkframe->g_grid( -column => 0, -row => 0, -sticky => "nesw" );
    $pkframe->g_grid_columnconfigure( 2, -weight => 1);
    
    $pkframe->new_ttk__label( -text => "exists?" )
        ->g_grid( -row => 0, -column => 3 );
    
    # Make a row for each pkID containing labels, entry, Browse button.
    for ( my $i = 0; $i < @pkIDs; $i++ ) {
        my $id = $pkIDs[ $i ];
        
        $pkframe->new_ttk__label( -text => $id )
            ->g_grid( -column => 0, -row => $i + 1 );
        
        my $hits = $hitCount{ $id } > 1 ? " hits" : " hit";
        $pkframe->new_ttk__label( -text => "(" . $hitCount{ $id } . $hits . ")" )
            ->g_grid( -column => 1, -row => $i + 1 );
            
        my $entry = $pkframe->new_ttk__entry(
            -width            => 20,
            -textvariable     => \$pkFiles[ $i ],
            -validate         => "all",
            -validatecommand  => sub { validate(); 1 } # 1 return code
        );
        
        $entry->m_configure( -state => "disabled" ) if $pkFiles[ $i ] eq "(virtual)";
        
        $entry->g_grid( -column => 2, -row => $i + 1, -sticky => "we" );
        
        $pkframe->new_ttk__label( -textvariable     => \$filesExist[ $i ] )
            ->g_grid( -column => 3, -row => $i + 1);
        
        my $btn = $pkframe->new_ttk__button(
            -text    => "Browse",
        );
        
        $btn->g_grid( -column => 4, -row => $i + 1);
        
        $btnAssign{ $btn->_mpath() } = $i;
        
        $btn->m_configure(
            -command => sub {
                my $f = Tkx::tk___getOpenFile();
                my $id = $pkIDs$btnAssign{ $btn->_mpath() };
                $pkFiles[ $id ] = $f if $f;
                &validate();
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
    
    my $hasNew = '';
    
    for ( my $i = 0; $i < @pkIDs; $i++ ) {
        my $id = $pkIDs[ $i ];
        $preFrame->new_ttk__radiobutton(
            -text         => $id,
            -variable     => \$preFrom,
            -value        => $id
        )->g_pack();
        $hasNew ||= ( $id eq "new" );
    }
    
    if ( ! $hasNew ) {
        $preFrame->new_ttk__radiobutton(
            -text      => "new",
            -variable  => \$preFrom,
            -value     => "new"
        )->g_pack();
    }
    
    foreach ( Tkx::SplitList( $preFrame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 3);
    }
    
    # OK and Cancel Buttons
    
    $okButton = $frame->new_ttk__button(
        -text       => "OK",
        -command    => sub { printCommand(); $mainWin->g_destroy(); },
    );
    
    $okButton->g_grid( -column => 1, -row => 2 );
    
    $frame->new_ttk__button( -text => "Cancel",
                             -command => sub { $mainWin->g_destroy(); exit( 255 ); } )
        ->g_grid( -column => 1, -row => 3 );
    
    $frame->g_grid_columnconfigure( 0, -weight => 1);
    
    foreach ( Tkx::SplitList( $frame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 5);
    }    
}

sub validate {
    my $missing = '';
    
    for ( my $i = 0; $i < @pkIDs; $i++ ) {
        my $e;
        if ( $pkIDs[ $i ] eq "new" ) {
            $e = 1;
        } else {
            $e = -e $pkFiles[ $i ] ? 1 : '';
            $missing = $missing || ! $e;
        }
        $filesExist[ $i ] = $e ? "yes" : "no";
    }
    if ( $okButton ) {
        if ( ! $missing ) {
            $okButton->m_configure( -state => "enabled" );
        } else {
            $okButton->m_configure( -state => "disabled" );
        }
    }
}

$| = 1; # I want to see output messages while the GUI is running.

GetOptions(
    'f=s' => \$PKlist,
) or pod2usage( 2 );

pod2usage( 2 ) unless $PKlist;

&_readTASfile(); # Look for default TAS file

&readPickupList();
&readPackList( );

# Create dialog elements
&createDialog();

# Validate to initialize aux variables
&validate();

Tkx::MainLoop();