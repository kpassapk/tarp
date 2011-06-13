package Tarp::LaTeXcombine::App;

=head1 NAME

Tarp::LaTeXcombine::App - The code behind the command line program

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use IO::File;

use Tarp::LaTeXcombine;
use Tarp::LaTeXcombine::VirtualPickup;
use Tarp::LaTeXcombine::PickupFile;

=head1 FUNCTIONS

=head2 run

    Tarp::LaTeXcombine::App->run();

Runs an application, parsing options from @ARGV.

=cut

sub run {    
    my $TASfile = '';
    my $CHUNKfile = '';
    my $SKELfile = '';
    my $dumpMatches = '';
    my $preambleFrom = '';
    my $info = '';
    my $silent = '';
    
    my %pickups;
    my @pkArgs;
    my $gen_tas = '';
    
    GetOptions(
        'tas=s'     => \$TASfile,
        'gen-tas'   => \$gen_tas,
        'pk=s'      => \@pkArgs,
        'chunk=s'   => \$CHUNKfile,
        'skel=s'    => \$SKELfile,
        'dump-matches' => \$dumpMatches,
        'preamble-from=s' => \$preambleFrom,
        'silent'    => \$silent,
        info        => \$info,
        help        => sub { pod2usage(1); },
        version     => sub { require Tarp::LaTeXcombine;
                        print "talatexcombine v$Tarp::LaTeXcombine::VERSION\n";
                        exit 1;
                    },
    ) or pod2usage( 2 );

    if ( $gen_tas ) {
        pod2usage({ -msg => "Too many arguments for --gen-tas", -exitval => 2 })
            if @ARGV;
        my $f = Tarp::LaTeXcombine->new(); # To import style plugins
        my $sty = $f->style(); # could also say Tarp::Style->new() and then import
        $sty->save( "TASfile.tas" )
            or die "Could not save 'TASfile.tas': " . $sty->errStr() . "\n";
        print "Created 'TASfile.tas'\n";
        return 0;
    }

    pod2usage({ -msg => "Incorrect number of arguments", -exitval => 2 })
        unless @ARGV == 1;
    
    my $PKlist = shift( @ARGV );
    
    # Process input files
    foreach my $pkArg ( @pkArgs ) {
        my ( $fileID, $pickup, $seq ) = split( /;/, $pkArg );
        
        die "Pickup --pk='$pkArg' must be given as --pk=fileID;file.tex[;seq]\n"
            unless $fileID =~ /\w+/ && $pickup;
        
        die "Sequence '$seq' in --pk='$pkArg' must be a positive integer\n"
            if defined $seq && ! ( $seq =~ /^\d\d?$/ );
        
        die "Cannot have duplicate pickup fileIDs: --pk=$fileID\n"
            if exists $pickups{$fileID};
        
        $pickups{$fileID} = [ $pickup, $seq ];
    }

    my $preambleTemplate = '';

    $preambleFrom ||= $pkArgs[0] || "new";
    $preambleFrom =~ s/;(.*)$//;
    if ( $preambleFrom eq "new" ) {
        # Specify new preamble from a file.
        $preambleTemplate = $1 if $1;
    } else {
        die "Cannot get preamble from $preambleFrom since fileID $preambleFrom has not been ",
        "specified using the --pk option.\n"
            unless exists $pickups{$preambleFrom};
    }
    
    my %outFiles = ( skel => \$SKELfile, chunk => \$CHUNKfile );
    while ( my ( $ext, $file ) = each %outFiles ) {
        next if $$file;
        $$file = $PKlist;
        $$file =~ s/\..*?$//;
        $$file .= ".$ext";
    }
    
    my $f = Tarp::LaTeXcombine->new();
    $f->dumpMatches( $dumpMatches );
    $f->preambleFrom( $preambleFrom );
    $f->style()->load( $TASfile ) or die $f->style()->errStr() . "\nStopped";
    my %pkObjs;
    my $newPk = Tarp::LaTeXcombine::VirtualPickup->new();
    $newPk->preambleTemplate( "templates/preambles/$preambleTemplate" )
        if ( $preambleTemplate );    
    $pkObjs{new} = $newPk;
    while ( my ( $ID, $details ) = each %pickups ) {
        my $pk = Tarp::LaTeXcombine::PickupFile->new( @$details );
        $pkObjs{ $ID } =  $pk;
    }
    
    open( PKLIST, '<', $PKlist ) or die "Could not open $PKlist: $!, stopped";

    while ( <PKLIST> ) {
        chomp;
        my @fields = split /\s+/;
        die "Pickup lists should have 4 fields, not " . @fields . ", stopped at $PKlist line $.\n"
            unless @fields == 4;
        my ( $newEx ) = @fields;
        die "Duplicate instruction for '$newEx' found, stopped at $PKlist line $.\n"
            if $f->instruction( $newEx );
        $f->instruction( @fields );
    }
    close PKLIST;
    $f->combine( %pkObjs );
###################### HELP!  MY PROGRAM STOPPED HERE ######################
#
# If execution stopped here:
#
# - "Missing file ID(s)..." Check the --pk arguments
#
# - "foo pickup error: bar not found..." Check that every exercise in the pickup
#   list exists in each pickup file
#
# - "Exercise foo:bar contains parts or subparts..." Check that exercises in
#   the pickup list are "leaves": they should contain no parts or subparts.
#   Parts and subparts should have their own entry in the pickup list.
#
# - "Gap in input exercises..." Check if there is a gap in the first column
#   of the pickup list.
#
# - "Invalid pickup...": Check that where "new" appears there is no exercise
#   in the third column, and that when the second column is non-new there
#   is a valid exercise in the third column.  These two are NOT okay:
#
#   01a new 01 00001    <- "new" cannot have a pickup exercise 01
#   01b foo .. 00002    <- ".." is not an exercise
############################################################################
    
    unless ( $silent ) {
        print "Chunks of sequential input:\n";
        my $d = $f->chunkData();
        for ( @$d ) {
            print join( ' - ', @$_ ) . "\n";
        }
    }
    
    unless ( $info ) {
        my $CHUNK = IO::File->new();
        $CHUNK->open( "> $CHUNKfile" )
            or die "Could not open $CHUNKfile for writing: $!, stopped";
        $f->printChunks( $CHUNK );
        undef $CHUNK;
        
        my $SKEL = IO::File->new();
        $SKEL->open( "> $SKELfile" )
            or die "Could not open $SKELfile for writing: $!, stopped";
        $f->printSkel( $SKEL );
        undef $SKEL;
        
        print "Wrote $CHUNKfile and $SKELfile.\n"
            unless $silent;
    }
}

1;