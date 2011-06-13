#!/usr/bin/perl -w

=head2 NAME

tagentex_gui - Gui front end for tagentex

=head1 SYNOPSIS

tagentex_gui [options]

Options:

    f=[file.pklist]     File base name

This program is meant to be used from Komodo.  Use talatexcombine for instructions
on the command line interface.

=cut

package MyDialog;

use strict;
use Carp;

use Tkx;
Tkx::package_require("tile");

my %fields = (
    chapter     => "Chapter",
    section     => "Section",
    chapter_title => "Chapter Title",
    section_title => "Section Title",
    PKlist => '',
    genOutput => 1,
    genTemplates => 1,
);

sub new {
    my $class = shift;
    my $parent = shift;
    
    my $self = {
        _permitted => \%fields,
        %fields,
        _chaptEntry => undef,
    };
    
    bless $self, $class;
    return $self;
}

sub create {
    my $self = shift;
    my $mainWin = Tkx::widget->new( "." );
    
    $mainWin->g_wm_title( "Tarp GenTex" );
    
    my $xPos = $mainWin->g_winfo_screenwidth() / 2.0 - 200;
    my $yPos = $mainWin->g_winfo_screenheight() / 2.0 - 200;
    
    $mainWin->g_wm_geometry( "+$xPos+$yPos" );
    
    # Create a themed frame that covers the whole window area
    my $frame = $mainWin->new_ttk__frame();
    
    $frame->g_grid( -sticky => "nwes" );
    $mainWin->g_grid_columnconfigure(0, -weight => 1);
    $mainWin->g_grid_rowconfigure   (0, -weight => 1);
    
    my $OUTfile = $self->{PKlist};
    $OUTfile =~ s/\..*?$/\.tex/;
    
    my $topFrame = $frame->new_ttk__labelframe( -text => "Output file: $OUTfile" );
    my $midFrame = $frame->new_ttk__frame();
    my $btnFrame = $frame->new_ttk__frame();
    
    $topFrame->g_grid( -row => 0, -column => 0, -sticky => "nwes", -padx => 5, -pady => 5 );
    $midFrame->g_grid( -row => 1, -column => 0, -sticky => "nwes", -padx => 5, -pady => 5 );
    $btnFrame->g_grid( -row => 2, -column => 0, -sticky => "nwes" );
    
    $frame->g_grid_columnconfigure( 0, -weight => 1 );
    $frame->g_grid_rowconfigure( 0, -weight => 1 );
    $frame->g_grid_rowconfigure( 1, -weight => 1 );
    
    $topFrame->new_ttk__checkbutton( -text => "Generate output", -variable => \$self->{genOutput} )
        ->g_grid( -row => 0, -column => 0, -columnspan => 4, -sticky => "w" );
    
    $topFrame->new_ttk__label( -text => "Chapter:" )
        ->g_grid( -row => 1, -column => 0, -sticky => "e" );
    
    $topFrame->new_ttk__label( -text => "Chapter Title:" )
        ->g_grid( -row => 2, -column => 0, -sticky => "e" );

    $topFrame->new_ttk__label( -text => "Section Title:" )
        ->g_grid( -row => 3, -column => 0, -sticky => "e" );
    
    $topFrame->new_ttk__entry( -width => 10, -textvariable => \$self->{chapter}, )
        ->g_grid( -row => 1, -column => 1, -sticky => "nwes" );
    
    $topFrame->new_ttk__label( -text => "Section:" )
        ->g_grid( -row => 1, -column => 2, -sticky => "e" );

    $topFrame->new_ttk__entry( -width => 10, -textvariable => \$self->{section} )
        ->g_grid( -row => 1, -column => 3, -sticky => "nwes" );
    
    $topFrame->new_ttk__entry( -width => 40, -textvariable => \$self->{chapter_title} )
        ->g_grid( -row => 2, -column => 1, -sticky => "nwes", -columnspan => 3 );
    
    $topFrame->new_ttk__entry( -width => 40, -textvariable => \$self->{section_title} )
        ->g_grid( -row => 3, -column => 1, -sticky => "nwes", -columnspan => 3 );

    $topFrame->g_grid_columnconfigure( 1, -weight => 1 );
    $topFrame->g_grid_columnconfigure( 3, -weight => 1 );
    # Pad each element in pkframe
    foreach ( Tkx::SplitList( $topFrame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 5);
    }
    
    $midFrame->new_ttk__checkbutton(
        -text => "Generate master templates (ms*.tex)",
        -variable => \$self->{genTemplates}
    )->g_grid( -row => 0, -column => 0, -sticky => "w" );
    
    my $okButton = $btnFrame->new_ttk__button(
        -text => "OK",
        -command => sub { $self->okClicked(); $mainWin->g_destroy(); }
    )->g_grid( -row => 0, -column => 1 );
    
    my $cancelButton = $btnFrame->new_ttk__button(
        -text => "Cancel",
        -command => sub { $self->cancelClicked(); $mainWin->g_destroy() },
    )->g_grid( -row => 0, -column => 2 );
        
    $btnFrame->g_grid_columnconfigure( 0, -weight => 1 );
    
    foreach ( Tkx::SplitList( $btnFrame->g_winfo_children ) ) {
        Tkx::grid_configure($_, -padx => 5, -pady => 5);
    }
}

sub okClicked {
    my $self = shift;
    $self->printCommand();
}

sub printCommand {
    my $self = shift;
    
    my ( $genOutput, $genTemplates, $PKlist )
        = @{$self}{ qw/genOutput genTemplates PKlist/};
        
    if ( $genOutput ) {    
        my $command = "tagentex";
        my ( $chapter, $section, $chapter_title, $section_title )
            = @{$self}{qw/ chapter section chapter_title section_title /};
        
        $command .= ' --chapter="' . $chapter . '"';
        $command .= ' --section="' . $section . '"';
        $command .= ' --chapter-title="' . $chapter_title . '"';
        $command .= ' --section-title="' . $section_title  . '"';
        
        $command .= ' ' . $PKlist;
        _goCommand( $command );
        print "\n";
    }
    
    if ( $genTemplates ) {
        my $command = "tagentex --master-templates " .
        $PKlist;
        _goCommand( $command );
    }
}

sub _goCommand {
    my $command = shift;
    print "Executing:\n" . $command . "\n\n";    
    system( $command );
}

sub cancelClicked {}

sub AUTOLOAD {
    my $self = shift;
    
    our $AUTOLOAD;
    
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{_permitted}->{$name} ) {
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

package main;

use Getopt::Long;
use Pod::Usage;

use Tarp::StyleHelper;

my $PKlist;
my $chapter;
my $section;

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

$| = 1;

GetOptions(
    'f=s' => \$PKlist,
) or pod2usage( 2 );

die "Check options" unless $PKlist;

&_readTASfile();

my $dialog = MyDialog->new( "." );

$dialog->PKlist( $PKlist );
$dialog->chapter( $chapter );
$dialog->section( $section );

$dialog->create();


Tkx::MainLoop();