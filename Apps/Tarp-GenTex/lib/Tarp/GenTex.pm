package Tarp::GenTex;

=head1 NAME

Tarp::GenTex - generate a .tex file by merging .chunk and .skel files

=head1 SYNOPSIS

    use Tarp::GenTex;
    
    # New GenTex to merge foo.skel and foo.chunk in the current directory:

    $gtx = Tarp::GenTex->new( "foo.pklist" );

    # Get a list of variables in foo.chunk's preamble
    my @vars = $gtx->vars();
    
    $gtx->gen( CHAPT => '1', SECT => '2' );
    $gtx->genTemplateFiles();

=head1 VERSION

Version 0.994

=cut

our $VERSION = '0.994';

=head1 DESCRIPTION

This module creates a new C<LaTeX> file using a skeleton and chunk file. A
pickup list is used to insert exercise numbers and MasterID references, where
applicable.

Generation of the C<.tex> file is orchestrated by the L</gen> method, as
follows.

=over

=item 1.

A list of the (new edition) items and masterIDs is extracted from the pickup
list.

=item 2.

The Chunk file is loaded into a buffer.

=item 3.

The preamble chunk, chunk zero, is parsed and variable placeholders such as
$CHAP$ and $SECT$ are replaced. If these placeholders are found in the preamble
but no value has been given to gen(), a warning message is printed and the
placeholders are left unchanged.

=item 4.

A temporary file is then made by expanding the skeleton file with the contents
of the chunk file. As it goes along, the algorithm replaces the $ITM$ variable
with the new edition exercise number (or letter, or Roman numeral). This is done
by "unwinding" the first column of the pickup list.

=item 5.

The temporary file is re-read and parsed by Tarp::Itexam; this module, with
the help of an attribute called "MSPlacer", performs a substitution of the
$MASTER$ variable in each exercise (if any) with the MasterID corresponding to
that exercise.

=item 6.

The final output file is then written.

=back

Unless specified explicitly, the names of the skeleton, chunk and output files
are guessed using the name of the pickup list: If using foo.pklist, files
foo.skel, foo.chunk, and foo.tex will be used, respectively.

It is important that the pickup list and the C<TAS> file are the same as those that
were used to generate the skeleton and chunk files; otherwise, the $ITM$ variables
in the skeleton and chunk files will not match up with the new edition exercise
numbers in the pickup list, and the LaTeX file will not be generated successfully.

=cut

use strict;
use warnings;
use Cwd;
use IO::File;

use Carp;
use Tarp::Config;
use Tarp::Style;
use Tarp::Itexam;

use Tarp::GenTex::Unwind;
use Tarp::GenTex::MSPlacer;

our $AUTOLOAD;

my %fields = (
    PKlist       => '',
    SKELfile     => '',
    CHUNKfile    => '',
    OUTfile      => '',
    style        => undef,
    chunkStart => 'CHUNK_START',
    chunkEnd   => 'CHUNK_END',
);

my $Debugging = '';

=head1 METHODS

=head2 new

    $xt = Tarp::GenTex->new( "file.pklist" );

Returns a new instance of Tarp::GenTex using 'file.pklist'.  This method
imports GenTeX::Style and Itexam::Style

Options can be set through acessor methods. Currently the following options are
available:

=over

=item SKELfile

The name of the skeleton file.  Absolute and relative paths are acceptable.
B<Default: get from PKlist.>

=item CHUNKfile

The name of the chunk file. Absolute and relative paths are acceptable.
B<Default: get from PKlist.>

=item OUTfile

The name of the output file. Absolute and relative paths are acceptable.
B<Default: get from PKlist.>

=back

=cut

sub new {
    my $class = shift;
    my $PKlist = shift;
    
    my $use = "check usage";
    confess $use unless defined $PKlist;
    confess $use if ref $PKlist || @_;
    
    my $self = bless {
        %fields,
        chunkBuffer  => [],
        chunkRanges  => [],
        exList       => [],
        newExList    => [], # with "new" pickup file
        masters      => {}, # 01a => 12345
    }, $class;
    
    $self->{PKlist} = $PKlist;
    Tarp::Style->import( "Tarp::GenTex::Style" );
    my $exm = Tarp::Itexam->new(); # Import style plugins
    my $sty = $exm->style();       # (could also say Tarp::Style->new() 
    $sty->impXforms( 1 );          # and then import)
    $self->{style} = $sty;
    $self->getDefaults();
    return $self;
}

=head2 vars

    @vars = $gtx->vars();

Returns the variables in the chunk file's preamble (chunk zero) which require
substitution.  The variable names are not returned with the bracketing dollar
signs and are not sorted.

=cut

sub vars {
    my $self = shift;
    
    open( CHUNK, $self->{CHUNKfile} )
        or croak "Could not open '$self->{CHUNKfile}' for reading: $!, stoppped";
    
    my %vars;
    
    my $inPre = 0;
LINE: while ( <CHUNK> ) {
        chomp;
        s/\n//; s/\r//;
        $inPre = 1 if $_ eq $self->chunkStart();
        $inPre = 0 if $_ eq $self->chunkEnd();
        last LINE unless $inPre;
        my @varsInLine = Tarp::Style->varsIn( $_ );
        @vars{ @varsInLine } = @varsInLine;
    }

    return keys %vars;
}

=head2 gen

    $gtx->gen( a => [ "foo" ], b => [ "bar" ] );

Generates an output file using the skeleton file, chunk file and pickup list, as
described above. If the pickup list has not been specified, an exception will be
raised. Variables are in the format of %-.

=cut

sub gen {
    my $self = shift;
    my %vars = @_;
    
    $self->getDefaults();
    $self->_loadPKlist( $self->{PKlist} );
    $self->_loadChunkFile();
    carp "Going to replace variables" if $Debugging;
    $self->_replaceVars( %vars );
    $self->_makeTMPfile();
    $self->_placeMasters();
}

=head2 genTemplateFiles

    $gtx->genTemplateFiles();
    $gtx->genTemplateFiles( $outDir );

Generates template files for each reference to the C<new> virtual pickup file in
the pickup list by copying a file F<ms_template.tex> to F<ms$MASTER$.tex>, where
$MASTER$ is the master number. F<ms_template.tex> is searched for in the
"templates" subdirectory of Tarp::Config::ResourceDir unless the file exists in
the current working directory. If $outDir is given, places all C<ms*.tex> files
in that directory.
In each of the template files, the string $MASTER$ gets replaced with the actual
master number.

=cut

sub genTemplateFiles {
    my $self = shift;
    my $outDir = shift || '.';
    
    if ( ! -e $outDir ) {
        mkdir( $outDir ) or croak "Could not create directory '$outDir': $!, stopped";
    }
    
    $self->_loadPKlist( $self->{PKlist} );
    
    my $templateFile = "ms_template.tex";
    my $resDir = -e $templateFile ?
        cwd() :
        File::Spec->catfile( Tarp::Config->ResourceDir(), "templates" );
    $templateFile = File::Spec->catfile( $resDir, $templateFile );
    
    my @newExList = @{$self->{newExList}};
    my $createCount = 0;  # Counter for how many template files were created
    for ( @newExList ) {
        my $master   = $self->{masters}->{$_};

        my $outFile = "ms$master.tex";
        $outFile = File::Spec->catfile( $outDir, $outFile );
            
        open( TEM, "<$templateFile" )
            or croak "Could not open '$templateFile': $!, stopped";
        
        open( OUT, ">$outFile" )
            or croak "Could not open '$outFile': $!, stopped";
        
        while ( <TEM> ) {
            s/\$MASTER\$/$master/;
            print OUT $_;
        }
        
        close OUT;
        close TEM;
        $createCount++;
    }
    warn "No master templates created: '$self->{PKlist}' contains no \"new\" refs.\n"
        if ( ! $createCount );
}

=head2 getDefaults

    $gtx->getDefaults();

Gets the default output C<.tex> and the input C<.chunk> and C<.skel> file names
by using the base of the input pickup list.  If any of the above have already
been specified, the previous value is not changed.  If the pickup list has not
been specified, no other values are changed.

=cut

sub getDefaults {
    my $self = shift;
    
    my ( $PKlist, $SKELfile, $CHUNKfile, $OUTfile ) =
        @{$self}{ qw/ PKlist SKELfile CHUNKfile OUTfile/ };
    
    return unless $PKlist;
    
    # Extensions for each type of file:
    my %exts = (
        skel  => \$SKELfile,
        chunk => \$CHUNKfile,
        tex   => \$OUTfile,
    );

    # Set default file names unless already specified.
    while ( my ( $ext, $file ) = each %exts ) {
        next if $$file;       # Do not change the defined ones.
        $$file = $PKlist;
        $$file =~ s/\..*?$//; # Strip old extension, if any
        $$file .= "\.$ext";   # Append new extension
    }
    
    @{$self}{ qw/ SKELfile CHUNKfile OUTfile / } =
        ( $SKELfile, $CHUNKfile, $OUTfile );
}

=head2 style

    $gtx->style( $s );
    $s = $gpk->style();

Sets or gets the style for this GenTex object

=head2 debug

    Tarp::GenTex->debug( $level )

Sets the debug level.  A nonzero value prints debugging messages to STDERR.

=cut

sub debug {
    my $class = shift;
    if (ref $class)  { confess "Class method called as object method" }
    $Debugging = shift;
}


sub _loadPKlist {
    my $self = shift;
    my $PKlist = shift;
    
    carp "Loading '$PKlist'" if $Debugging;
    open( PKLIST, $PKlist )
        or croak "Could not open '$PKlist' for reading: $!";
    
    my @exList;
    my @newExList;
    my %masters;
    while ( <PKLIST> ) {
        chomp;
        my @fields = split /\s+/;
        croak "Incorrect number of fields (expected 4) at $PKlist line $.\n"
            unless @fields == 4;
        my ( $ex, $file, undef, $master ) = @fields;
        push( @exList, $ex );
        push @newExList, $ex if $file =~ /new/;
        $masters{$ex} = $master;
    }
    @exList = $self->style()->sort( @exList );
    @newExList = $self->style()->sort( @newExList );
    
    carp "Loaded $. instructions" if $Debugging;
    close PKLIST;
    
    @{$self}{qw/exList newExList masters/}
        = ( \@exList, \@newExList, \%masters );
}

sub _loadChunkFile {
    my $self = shift;
    
    my ( $CHUNKfile ) = @{$self}{ qw/CHUNKfile/ };

    carp "Loading '$CHUNKfile'" if $Debugging;

    open( CHUNK, $CHUNKfile ) or die "Could not open $CHUNKfile: $!";
    my @fb = <CHUNK>;
    chomp( @fb );
    close( CHUNK ) or die "Failed to close $CHUNKfile: $!";
 
    open( SLURP, $CHUNKfile ) or die "Could not open $CHUNKfile: $!";   

    my $prev = $/;
    undef $/;
    my $buf = <SLURP>; # Pull in the buffer with newlines.
    $/ = $prev;
    
    my @chunkRanges = $self->_getChunkRanges( $buf )
        or die "No chunks were found in $CHUNKfile, stopped";

    carp "Loaded " . @chunkRanges . " chunks" if $Debugging;
        
    @{$self}{qw/chunkBuffer chunkRanges/}
        = ( \@fb, \@chunkRanges );
}

sub _replaceVars {
    my $self = shift;
    my %vars = @_;
    # Get preamble buffer from chunk zero, make
    # replacements to variables.
    
    carp "\nReplacing preamble variables" if $Debugging;
    my ( $chunkBuffer, $chunkRanges )
        = @{$self}{qw/chunkBuffer chunkRanges/};

    carp "Found " . $self->vars() . " variables in preamble"
        if $Debugging;
    my @preVars = $self->vars();
    
    # Get variables from preamble chunk
    my %preVars;
    @preVars{ @preVars } = @preVars;
    
    my $preRng = $chunkRanges->[0]; # Chunk zero is the preamble.
    
    while ( my ( $preVar ) = each %preVars ) {
        unless ( exists $vars{$preVar} )  {
            warn "Warning: no replacement value given for \$$preVar\$. " ,
            "Leaving unchanged.\n";
            $vars{$preVar} = "\$$preVar\$";
        }
    }
    
    foreach my $var ( keys %vars ) {
        unless ( exists $preVars{ $var } ) {
            warn "Warning: variable \$$var\$ not found in preamble. Ignoring.\n";
        }
    }
    
    for ( my $l = $preRng->[0] + 1; $l < $preRng->[1]; $l++ ) {
        my $i = $l - 1;
        ( $chunkBuffer->[$i] ) =
            $self->style()->interpolateVars( $chunkBuffer->[$i], \%vars );
    }
}

sub _makeTMPfile {
    my $self = shift;
    
    my ( $SKELfile, $OUTfile, $exList, $chunkRanges, $chunkBuffer ) =
        @{$self}{qw/SKELfile OUTfile exList chunkRanges chunkBuffer/};
    
    open( SKEL, "<$SKELfile" )
        or die "Could not open $SKELfile for reading: $!, stopped";
    
    my @uw;
    my $unwinder = Tarp::GenTex::Unwind->new();
    @uw = $unwinder->unwind( @$exList );
    
    carp "Creating $OUTfile.tmp" if $Debugging;
    my $TMP = IO::File->new();    
    
    $TMP->open(">$OUTfile.tmp" )
        or die "Could not open '$OUTfile.tmp' for writing: $!, stopped";
    
    croak "No chunks in chunk file!, stopped"
        unless @$chunkRanges;
    
    my $i_ch = 0;     # chunk index
    LINE: while ( <SKEL> ) {
        chomp;
        my $line;
        if ( /INSERT.*HERE/ ) {
            carp "Inserting chunk at line $." if $Debugging;
            if ( $i_ch < @$chunkRanges ) {
                my $rng = $chunkRanges->[$i_ch];
                for ( my $l = $rng->[0] + 1; $l < $rng->[1]; $l++ ) {
                    my $i = $l - 1; # line number to index
                    $line = $chunkBuffer->[ $i ];
                    $self->_dropEx( \$line , \@uw );
                    print $TMP $line . "\n";
                }
            } else {
                warn "Too many INSERT CHUNK HEREs";
                print $TMP $_ . "\n";
            }
            $i_ch++;
        } else {
            $line = $_;
            $self->_dropEx( \$line, \@uw );
            print $TMP $line . "\n";
        }
    } # LINE loop
    
    $TMP->close() or die "Could not close $TMP: $!, stopped";
    undef $TMP;
    
    croak "Unused chunks (not enough INSERT CHUNK HEREs in .skel file)"
        unless ( $i_ch == @{$self->{chunkRanges}} );
    
    while ( @uw ) {
        my $itm = shift( @uw );
        croak "More entries in pickup list than \$ITM\$ tags: $itm!";
    }
}

sub _placeMasters {
    my $self = shift;
    
    my ( $OUTfile, $masters )
        = @{$self}{ qw/OUTfile masters/ };
    
    my $exm = Tarp::Itexam->new();
    $exm->enforceOrder( 1 );
    $exm->stripVariables( 0 );
    
    $exm->style( $self->style() );

    # For each exercise, look for the $MASTER$ variable
    # in the corresponding line range, and replace with the
    # master number found in the pickup list.
    
    carp "Replacing \$MASTER\$ variables" if $Debugging;
    
    my $msplacer = Tarp::GenTex::MSPlacer->
        new( "master", $exm );
    
    $msplacer->masters( $masters );
    $exm->extractAttributes( "$OUTfile.tmp" )
        or die $exm->errStr();
    
    my $io = IO::File->new;
    $io->open( ">$OUTfile" )
        or die "Could not open $OUTfile for writing: $!";
    
    $exm->printLineBuffer( $io );
    unlink "$OUTfile.tmp";
    
    undef $io;
}

sub _dropEx {
    my $self = shift;
    my $line = shift;
    my $stack = shift;
    
    if ( $$line =~ /\$ITM\$/ ) {
        my $itm = shift( @$stack );
        die "Too many \$ITM\$s, stopped" unless $itm;
        $$line =~ s/\$ITM\$/$itm/;
    }
}

sub _getChunkRanges {
    my $self = shift;
    my $str = shift;
    my $in = 0;
    my @r = ();
    
    open STR, "<", \$str;
    while ( <STR> ) {
        chomp;
        s/\n$//; s/\r$//;
        if ( $_ eq $self->chunkStart() ) {
            push @r, [ $. ];
            $in  = 1;
        }
        if ( $_ eq $self->chunkEnd() ) {
            croak "end with no start" unless $in;
            push @{$r[-1]}, $.;
        }
    }
    @r;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{$name} && $name =~ /^[a-z]/i ) {
        croak "Can't access '$name' field in class $type, stopped";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::GenTex

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1;