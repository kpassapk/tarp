package Tarp::LaTeXtract;

use strict;
use warnings;

=head1 NAME

Tarp::LaTeXtract - Extract list data from LaTeX file (or other files with lists)

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

=head1 SYNOPSIS

    --- in.tex ---

    \begin{enumerate}
    \item[1]
    ...
    \item[2]
    ...
    \end{enumerate}    

    --- meanwhile, back at the ranch ---
    
    use Tarp::LaTeXtract;
    
    $ltx = Tarp::LaTeXtract->new();
    
    # Specify options
    $ltx->maxLevel( 1 );            # Ignore parts or subparts
    $ltx->enforceOrder( 1 );        # complain about out-of-order \item tags
    
    # Optionally, load a .tas file (see Tarp::Style)
    # $ltx->style()->load( "foo.tas" ) or die "Could not load style: "
    #     . $ltx->style()->errStr();
    
    $ltx->read( "in.tex" ) or die "Error reading in.tex: "
        . $ltx->errStr();
    
    # Get numbering sequence and item data
    my $l = $ltx->lines();
    my $seqs = $ltx->seqData();
    
    # $l has start/end line number hashes, one per sequence
    
    use Data::Dump qw/dump/;
    print dump $l;
    # prints { "01" => [2, 3], "02" => [4, 5] }
    
    # while $seqs has line numbers for each sequence
    print dump $seqs;
    # prints [[1, 6]]
        
    my $ex = $ltx->itemOnLine( 42 );
    
    ( $itm ) = $ltx->itemOnLine( 2 );
    print $itm; # prints "01";

=head1 DESCRIPTION

This module reads a source C< LaTeX > file and extracts begin and end line
numbers for enumerated list items contained in the file. It is a bit
like a specialized "grep -n".  Although it is designed with LaTeX files in mind,
it can work with any other type of tagged file (HTML for example).

Suppose we have a list like this one. (line numbers on the left)

    1: \begin{enumerate} 
    2: \item[1] 
    3: \begin{enumerate} 
    4: \item[a] 
    5: Contents of 01a 
    6: \item[b] 
    7: Contents of 01b 
    8: \end{enumerate} 
    9: \end{enumerate}  

The list contains two enumerated items, C< 01a > and C< 01b >, plus other tags
related to the enumerated list. The C<\begin> and C<\end> tags change the
current item level. In this case, the tag on line 1 changes the level from C< 0
>, or "file level", to C< 1 >.

This module tries to match each line of the input file against its Tarp::Style
entries (accessible through style()). This is done in the read() method.
Subscripted tags, for example C< foo[1] >, act at a specific item level (one in
this case). Tags without a subscript are active at all item levels. The program
tries to match subscripted tags first, then all other tags.

When a match is found, the module attempts to call a tag loader called
Tarp::LaTeXtract::Loader::<tag>, where <tag> is the name of the matching tag.
If a loader exists, the load() class method is called, supplying some state
information. The job of the loader is to translate this state information into
three triggers, rangeStarted(), rangeEnded(), and sequenceChanged(), and
additionally to modify its itemStack(). All of these are class methods. Loaders
are supplied for each of LaTeXtract::Style's entries and for the C< itemTag >
entry, which is defined in C< Tarp::Style::ITM >. After the load() method has
been called, the read() method turns the itemStack and the three triggers into
a line number range. Parsing then continues on the next line. When the input
file has been read successfully, lines() can be used to get the line numbers
where list items were found.

As it goes along, the read() method performs some basic checks on the input it
is getting.  If the next tag is not what was expected, for example if
C< \item[(b)] > above actually said C< \item[(c)] >, parsing is interrupted.
This can be turned off by setting C< enforceOrder > to false in the constructor.
The loaders themselves can report on illegal tags by having load() return false
and setting the errStr().  Also, if a subscripted entry for the current level
contains the text C< <illegal> >, and if there is a non-subscripted entry with
the same name that matches the current line, then an error will be reported.

Typically, extracting a list of exercises from a TeX file using this module will
take several passes, with the user performing the necessary edits to the TeX and
TAS files each time until parsing is sucecssful. Therefore, this module tries
particularly hard to provide helpful error messages that may aid the user in
editing these files.

Apart from getting line ranges for enumerated items, this module is also useful
for extracting bits of text from a file using TAS variables: any variables
contained in the matching entry are saved and can be accessed afterwards using
the variables() method. 

By manipulating the style entries it is possible to set a different syntax for
tags at each level, or to disallow tags from occurring at a certain level. For
example, The \item tag could have a different syntax for each level by using
itemTag[1], itemTag[2], and itemTag[3], or otherwise use a single syntax for
itemTag and empty values for itemTag[1] through [3].

=head2 SEQUENCES

There may be more than one numbering sequence in a source TeX file. Sequences
are specified using the C< sequenceRestart> tag in the TAS file, which is
expected to be at file level (i.e. not in an item list). If this tag is not
found, all the exercises are assumed to be in sequence zero. If found, the
sequence index is incremented and any subsequent list items are assumed to be in
a new sequence. Note that it is possible for a sequence to contain no items. 

=cut

use Carp qw( carp croak confess );
use IO::File;

use Tarp::Style;
use Tarp::LaTeXtract::Loader;
use Tarp::LaTeXtract::Loader::beginTag;
use Tarp::LaTeXtract::Loader::endTag;
use Tarp::LaTeXtract::Loader::itemTag;
use Tarp::LaTeXtract::Loader::sequenceRestart;

our $AUTOLOAD;

=head1 Enumerated Types

=head2 ALL_LEVELS

Supply this value to L</maxLevel> (see below) to extract all item levels.

=cut

sub ALL_LEVELS { -1 }

my $Debugging = '';
my $Verbose   = '';

# Autoloaded and constructor assigned fields
my %fields = (
    maxLevel        => Tarp::LaTeXtract::ALL_LEVELS,
    enforceOrder    => '',
    doubleClickable => '',
    context         => 3,  # how many good matches to print before tag error
    extractSeq      => -1,
    relax           => '',
    style           => undef,

    seqData         => [], # e.g. [ [1,2], [3,4] ] (line where seq starts and ends)
    matches         => {},
    variables       => {},
);

=head1 METHODS

=head2 new

    $xt = Tarp::LaTeXtract->new();

Initializes a new Tarp::LaTeXtract object.

This method imports C< Tarp::Style::ITM >, C< Tarp::Style::ITM::NLR > and
C< Tarp::LaTeXtract::Style >. 

=cut

sub new {
    my $class = shift;
    confess "check usage" if @_;
    
    my $self = bless {
        %fields,
        _lines      => [{}] , # e.g. 01a => 42 (ex. => line for each item)
        exPos       => undef, # e.g. 01a => 2 (ex. => file pos. for each item)
        fileOrder   => undef, # e.g. [ [ '01a', 0 ], ['01b', 0] ];
        _errStr     => '',
        _last_file  => '',
    }, $class;

    $self->{seqData}   = [];
    $self->{matches}   = {};
    $self->{variables} = {};
    
    Tarp::Style->import( map { "Tarp::Style::$_" } ( qw/ITM ITM::NLR/ ) );
    Tarp::Style->import( 'Tarp::LaTeXtract::Style' );
    
    my $s = Tarp::Style->new() or die "Check style plugins, stopped";
    $self->{style} = $s;
    
    bless $self, $class;
    return $self;
}

=head2 read

    $ok = $ltx->read( "in.tex" );

Attempts to parse 'in.tex'. If an unexpected tag is found, the return value is
undefined and an error string can be retrieved with errStr(). If successful, the
resulting line numbers can be queried using lines().

After matching against built-in tags specified in Tarp::LaTeXtract::Style, user
defined tags in the TAS file are matched. If a match is found, match information
is stored and can be retrieved later with matches(), and variables using
variables(). Only one tag is matched per line.

The tag precedence for built in tags is:

=over

=item 1.

sequenceRestart

=item 2.

beginTag

=item 3.

endTag

=item 4.

itemTag

=back

The value of maxLevel() does not affect this method: all item levels
are read.  These may or may not be visible with lines(), isLeaf() and other
methods depending on the value of maxLevel(), but they are still accounted for
while reading the LaTeX file.

=cut

sub read {
    my $self = shift;
    my $TEXfile = shift;

    confess "check usage" unless $TEXfile;
    return $self->_error( "File '$TEXfile' does not exist" )              unless -e $TEXfile;
    return $self->_error( "'$TEXfile' is a directory, not a file" )       unless -f _;
    return $self->_error( "Insufficient permissions to read '$TEXfile'" ) unless -r _;

    carp "LaTeXtracting '$TEXfile' " if $Debugging;
    $self->{_last_file} = $TEXfile;
    
    my $sty = $self->style();
    croak "Style is out of date! Stopped"
        unless $sty->parent()->isa( "Tarp::LaTeXtract::Style" );

    # Our tags are checked in this order (no subscripts)
    my @loadOrder = qw/sequenceRestart beginTag endTag itemTag/;
    
    {
        my %entries;    # Entries tag => (n), n being how many _n_ levels per tag
        # Add the rest of the zero level entries in the TAS file
        for my $e ( $self->style()->entries( 0 ) ) {
            next if $sty->exists( "$e\::EXCLUDE" );
            if ( $e =~ /(\w+)_\d+_/ ) {
                $entries{$1}  = exists $entries{$1} ? ++$entries{$1} : 1;
            } else {
                $entries{$e} = 1;
            }
        }
        
        # Put in the rest of the entries not already in @loadOrder
        # (alphabetically, to ensure repeatability)
        my %rest = %entries;
        delete @rest{@loadOrder};
        push @loadOrder, sort keys %rest;
    }

    # These are the default loaders shipped with LaTeXtract.
    my %loaders = map { $_ => "Tarp::LaTeXtract::Loader::$_" }
        qw/ beginTag endTag itemTag sequenceRestart /;

    $Carp::Verbose = 1;
    
    # "use" any other loaders that exist in @INC, for tags that don't have an
    # EXCLUDE sub entry.
    
    foreach my $t ( @loadOrder ) {
        my $loader = $self->loader( $t );
        next if defined $loaders{$t} && $loaders{$t} eq $loader;
        next if $sty->exists( "$t\::EXCLUDE" );
        carp "loading $t: $loader" if $Debugging;
        eval "use $loader";
        if ( ! $@ ) {
            $loaders{$t} = $loader;
        } else {
            # differentiate between not there and syntax errors
            croak $@ unless $@ =~ /\@INC/;
        }
    }
    
    #********************** Loading Starts Here ********************************
    my @itmData     = ({}); # ( { 01 => [ 1, 2 ], 02 => [ 3, 4 ], ... }, ...)
    my $seqData     = [];   # ([1, 5], ... )
    my $matches     = {};
    my $variables   = {};
    
    # Start first sequence at line one
    my $curSeq      = 0;
    push @$seqData, [ 1, undef ];  
    
    my $exStr       = '';
    my @itemStack   = ();
    my $lastExStr   = '';

    Tarp::LaTeXtract::Loader->begin();
    
    my $TEX = new IO::File "< $TEXfile";
    croak "Could not open '$TEXfile' for reading: $!, stopped"
        unless defined $TEX;

    LINE: while ( <$TEX> ) {
        chomp;
        # Remove trailing newline or carriage return
        # when reading files not written on the same platform
        s/\n$//; s/\r$//;
        
        # Skip any lines that just contain whitespace
        next unless $_ =~ /\S+/;
        next if /TECHARTS_DISABLED_TAG/;    # Skip lines matching this
        
        my $l_str = $_;
        
        my $tag_type;
        my $tag;

        my $m_idx = -2;         # TAS entry index that matched, e.g. 0
        my %mVars = ();         # Variable matches in (name => string) pairs
        my %mPos  = ();         # Variable positions in (name => int) pairs
        
        TAG: foreach ( @loadOrder ) { # entries will have dups so skip if
            $tag_type = $_;
            $tag      = $tag_type . "_" . ( 0 + @itemStack ) . "_";
            my $illegal = 0;
            
            # If a specialized tag for this level exists, use it.
            if ( $sty->exists( $tag ) ) {
                foreach ( $sty->values( $tag ) ) {
                    if ( /<illegal>/ ) {
                        # Fall back to $tt or ignore
                        next TAG unless $sty->exists( $tag_type );
                        carp "Falling back from '$tag' to '$tag_type'"
                            if $Debugging;
                        $tag = $tag_type;
                        $illegal = 1;
                    }
                }
            } else {
                $tag = $tag_type;
            }
            
            # The golden test: does a value in this entry match?
            if ( $sty->m( $tag => $l_str ) ) {
                $m_idx = $sty->userIndex( $tag, $sty->mIdx() );

                return $self->_tagError({
                    errorMessage => "$tag_type is illegal at level " . ( 0 + @itemStack ),
                    matches      => $matches,
                    line         => $.
                }) if $illegal;
                
                # Keep only the first value for mVars and mPos
                %mVars = map { $_ => $sty->mVars()->{$_}->[0] } keys %{$sty->mVars()};
                %mPos  = map { $_ => $sty->mPos()->{$_}->[0] }  keys %{$sty->mPos()};
                
                last TAG;
            } # if m()
        } # TAG loop

        # index -1 is the dummy tag (if any)
        next LINE unless $m_idx >= -1;
        
        if ( $tag_type eq "sequenceRestart" ) {
            # Wrap up current sequence and start a new one
            $seqData->[-1][1] = $. - 1;
            push( @$seqData, [ $. ,undef ] );
            $curSeq++;
        }

        next LINE unless ( $self->extractSeq == -1 ||
                           $self->extractSeq == $curSeq );

        #************* Call loaders *********

        if ( my $loader = $loaders{ $tag_type } ) {
            if ( ! $loader->load( $tag, { relax => $self->relax } ) ) {
                return $self->_tagError({
                    errorMessage => $loader->errStr(),
                    line         => $.,
                    matches      => $matches,
                });
            }
 
            # OKAY, MOVE FORWARD
            
            # Replace $exStr and @itemStack with values for this iteration
            
            $lastExStr = $exStr; # see below
            @itemStack   = @{$loader->itemStack()};
            $exStr     = $sty->itemString( \@itemStack );

            # We may want to check the stack if
            # - the current tag is an item tag
            # - the value at the top of the stack is greater than zero,
            #   meaning there was an item before, and
    
            if ( $tag_type eq "itemTag" && $itemStack[-1] ) {

                my $exp = $self->style->xformVars( { ITM => \@itemStack }, 
                    "itemStack" => "itemSplit" )->{ITM};

                if ( $self->{enforceOrder} ||               # Check all
                    @itemStack == 1 ) {               # Check level zero

                    # Check that the value stored
                    # is what was expected
            
                    if ( $mVars{ITM} ne $exp->[-1] ) {
                        return $self->_tagError({
                            errorMessage => "Unexpected tag: found $mVars{ITM}, expected $exp->[-1]",
                            matches => $matches, line => $.
                        });
                    }
                } else {
                    # If not enforcing order, check the contents of memory, and
                    # if OK take the memory as the good value and continue. When
                    # we are done loading we will check that all exercises are
                    # "connected". 
            
                    $exp->[-1] = $mVars{ITM};
                    @itemStack = @{ $self->style->xformVars( { ITM => $exp }, "itemSplit" => "itemStack" )->{ITM} };
                    $exStr = $sty->itemString( \@itemStack );
                    
                    return $self->_tagError({
                        errorMessage => "Already have item $exStr in sequence $curSeq",
                        matches => $matches,
                        line => $.
                    }) if( exists $itmData[$curSeq]{$exStr} );
                    
                }

            } # If itemTag (except the first)
            
            #**** Turn the notification flags into a line range
                
            if ( Tarp::LaTeXtract::Loader->rangeStarted() ) {
                $itmData[$curSeq]{$exStr}[0] = $.;
            }
            
            if ( Tarp::LaTeXtract::Loader->rangeEnded() ) {
                # End ranges for last item and all parents
                my $parentEx = $lastExStr;
                while ( $parentEx ) {
                    $itmData[$curSeq]{$parentEx}[1] = $. - 1;
                    $parentEx = $sty->parentEx( $parentEx );
                }
            }

        }

        # Save matches and variables
        $matches->{$.} = {
            tag  => $tag,
            idx  => $m_idx == -1 ? "dummy" : $m_idx,
            vars => { %mVars },
            pos  => { %mPos  },
        };
        
        while ( my ( $varName, $varVal ) = each %mVars ) {
            my $varPos = $mPos{$varName};
            my $vrec = \$variables->{"$tag\::$varName"};
            $$vrec = [] unless $$vrec;
            push( @$$vrec, {
                line    => $.,
                val     => $varVal,
                pos     => $varPos
            });
        }
        
    } # LINE
    # If the item stack is not empty, print an error
    return $self->_tagError({
        errorMessage => "Item stack not empty at EOF (missing endTag(s))",
        matches => $matches,
        TEXfile => $TEXfile,
        line => $.,
    }) if @itemStack;
    
    # Wrap up last sequence at the end of the TeX file.
    $seqData->[-1][1] = $.;
    
    Tarp::LaTeXtract::Loader->end();
    $TEX->close() or croak "Could not close '$TEXfile': $!, stopped";

    unless ( $self->{enforceOrder} ) {
        # If we are not enforcing order, there may be gaps in the exercises.
        $self->_check_continuity( \@itmData, $seqData, $matches )
            or return $self->_error;
    } # unless enforceOrder

    # Assign item positions within the file...

    my $exPos = [{}]; # [ { 01a => 1, 01b => 2, .... }]
    my $fileOrder = [[]]; #
    
    # Hash exercises by line number, sort numerically and store
    
    my $pos = 0;
    SEQ: for ( my $seq = 0; $seq < @$seqData; $seq++ ) {
        my %xdByLine;
        while ( my ( $ex, $rng ) = each %{$itmData[$seq]} ) {
            $xdByLine{ int $rng->[0] } = $ex;
        }
        # Sort numerically
        my @exsSorted = sort { $a <=> $b } keys %xdByLine;
    
        foreach my $line ( @exsSorted ) {
            my $ex = $xdByLine{$line};
            $fileOrder->[$pos] = [ $seq, $ex ];
            $exPos->[$seq]{$ex} = $pos;
            $pos++;
        }
    }

    if ( $Debugging ) {
        my $exc = 0;
        map { $exc += keys %$_} @itmData;
        carp "Done LaTeXtracting '$TEXfile': found $exc exercise(s) in "
            . ( 0 + @itmData ) . " sequence(s)" if $Debugging;
    }
    @{$self}{qw/seqData _lines exPos fileOrder matches variables/} =
        ( $seqData, \@itmData, $exPos, $fileOrder, $matches, $variables );
    return $self->_noError();
}

sub _check_continuity {
    my $self = shift;
    my $itmData = shift;
    my $seqData = shift;
    my $matches = shift;
    
    my $sty = $self->style;
    
    SEQ: for ( my $seq = 0; $seq < @$seqData; $seq++ ) {
        
        my @unsorted = keys %{$itmData->[$seq]};
        my @sorted = $sty->sort( @unsorted );
        
        my $lastEx = '';
        my $lastExLine = '';
        ITM: foreach my $ex ( @sorted ) {
            my $rng = $itmData->[$seq]{$ex};
            my $exLine = $rng->[0];

            if ( $lastEx && ! $sty->isInOrder( $lastEx, $ex ) ) {
                
                # Found a gap.  Complain.
                my $errorMessage = "Missing tag between $lastEx and $ex";
                
                # Since there is an ambiguity between the part letter i
                # and the first roman numeral i, try to provide a helpful
                # suggestion if the module found a letter i that could
                # have been a roman numeral i:
                # If there is a gap before item "i", it could
                # be due to a missing begin tag in a part list
                
                $sty->m( "itemString", $ex );
                my $itemSplit = $sty->xformVars( $sty->mVars(), "itemString" => "itemSplit" )->{ITM};

                $errorMessage .= " (maybe due to a missing beginTag?)"
                    if ( $itemSplit->[-1] eq "i" );
                
                my %m;
                
                # Show msgs up to whichever one is greater.
                my $lg = $exLine > $lastExLine ? $exLine : $lastExLine;
                foreach ( keys %$matches ) {
                    $m{$_} = $matches->{$_} if $_ <= $lg;
                }
                return $self->_tagError({
                    errorMessage => $errorMessage,
                    matches      => \%m,
                    line         => $lastExLine
                });
            } # if lastEx
            $lastEx = $ex;
            $lastExLine = $exLine;
        } # ITM loop
    } # SEQ loop
    return 1;
}

=head2 loader

    $class = Tarp::LaTeXtract->loader( $tag );

Returns the default loader class: Tarp::LaTeXtract::Loader::$tag

=cut

sub loader {
    my $tag = $_[1];
    confess "check usage" if ( ! defined( $tag ) || ref $tag );
    return "Tarp::LaTeXtract::Loader::" . $tag;
}

=head2 maxLevel

    $l = $ltx->maxLevel();
    $ltx->maxLevel( 2 );

The maximum item level to extract.  If set to C<Tarp::LaTeXtract::ALL_LEVELS>
all levels will be extracted.  B<Default: C<Tarp::LaTeXtract::ALL_LEVELS>>.

=head2 enforceOrder (boolean)

    $yes = $ltx->enforceOrder();
    $ltx->enforceOrder( 1 );

If true, while parsing the input file in read(), raise an exception if an unexpected item
number, letter or roman numeral is found at levels greater than zero.
If false, allow out-of-order exercises as long as there are no gaps
in the item sequence.  Zero-level exercises are always assumed to be in
sequence, regardless of the contents of this flag. B<Default: false>.

=head2 doubleClickable (boolean)

    $yes = $ltx->doubleClickable();
    $ltx->doubleClickable( 1 );

When exceptions are raised by the read() method, provide absolute filenames
in the error messages in order to make them "double-clickable" in some editors.
B<Default: false>.

=cut

# Print some good matches (if any) followed by a tag error, which will be
# hopefully double clickable in Komodo and others.  Uses the "context" field
# to determine how many good matches to print. 

sub _last_file {
    my $self = shift;
    my $fqfile = $self->{_last_file};
    
    if ( $self->doubleClickable ) {
        use File::Spec;
        use Cwd;
        $fqfile = File::Spec->catfile( cwd, $fqfile )   unless
            File::Spec->file_name_is_absolute( $fqfile );
    }
    return $fqfile;
}

sub _tagError {
    my $self = shift;
    my $details = shift;
    
    my ( $line, $errorMessage, $matches ) =
        @{$details}{ qw/line errorMessage matches / };
    
    my $fqfile = $self->_last_file;
        
    my $errorString = '';
    
    open( ERR, '>', \$errorString );
    
    print ERR "LaTeXtract didn't like a tag in $self->{_last_file}.\n";
    if ( $self->context ) {
        print ERR "Succesful matches prior to tag error: ";
        print ERR $self->_matchstr( $matches, $self->context );
    }

    print ERR "ERROR: $errorMessage, stopped at $fqfile line $line";
    close ERR;
    
    $self->matches( $matches );
    return $self->_error( $errorString );
}

sub _matchstr {
    my $self = shift;
    my $matches = shift;
    my $context = shift;
    
    my $fqfile = $self->_last_file;
    
    my $m = '';
    open M, '>', \$m;
        
    # Numerically sort matches by line
    my @matches = sort { $a <=> $b } keys %$matches;
    
    if ( ! @matches ) {
        print M "none.\n";
    } else {
        use Data::Dump qw/dump/;

        $context = @matches
            unless $context;

        print M "\n";
        my $errNum = 0;
        for ( my $i = -$context; $i < 0; $i++ ) {
            next if @matches < abs $i;
            my $matchLine = $matches[$i];
            my $match = $matches->{$matchLine};
            my ( $tag, $vars, $idx ) =
                @{$match}{qw/tag vars idx/};
            $errNum++;
            $tag =~ s/_(\d+)_/\[$1\]/;
            print M "($errNum) $tag\[$idx\] ";
            
            # Print variables if available as { foo => "a", bar => "b" }
            print M dump $vars;

            print M " at $fqfile line $matchLine\n";
        }
    }

    close M;
    return $m;
}

sub _noError {
    my $self = shift;
    $self->{_errStr} = '';
    1;
}

# Sets the errstr and exists.  Calling without an argument does not modify errstr,
# just returns false.
sub _error {
    my $self = shift;
    $self->{_errStr} = shift if @_;
    '';
}

=head2 errStr

    $err = $xtr->errStr()

Retrieves the error string

=cut

sub errStr {
    my $self = shift;
    return $self->{_errStr};
}

=head2 matches

    $m = $ltx->matches();
    $exp = $m->{42}{exp};    # Get expression that matched line 42 (if any)

Returns a reference to a hash of hashes containing match information found
by the last call to L</read>.  Each hash is structured as in the
following example:

    # keyed by line number, 42 and 71 in this example:
    
    matches = {
        42 => {
            tag  => "itemTag",         # The tag that matched
            exp  => "item\[$ITM$\.\]",  # The regular expression in that tag that matched
            vars => { ITM => 2 }        # Concents of variables, if any
            pos  => { ITM => 15 }       # Column where the variable was found
        }
        71 => {
            tag => ...
            ...
        }
    };

=head2 dumpMatches

    $ltx->dumpMatches( $io );

Dumps matches to the $io object in a human readable format.
The actual format produced by this method is subject to change.

=cut

sub dumpMatches {
    my $self = shift;
    my $io = shift;

    confess "check usage" unless defined $io;

    print $io $self->_matchstr( $self->{matches} );
}

=head2 dumpLines

    $xtr->dumpLines();

Prints sequence and item line numbers like this:

    seq0: 1 101
    01: 42 45
    02: 47 49

Exercises are sorted using Tarp::LaTeXtract::Style's sort() method.  The first
line is where the corresponding item tag was found, and the second is the last
line that belongs to that item (prior to the next itemTag or endTag)

=cut

sub dumpLines {
    my $self = shift;
    
    my $seqs = $self->seqData();

    for ( my $i = 0; $i < @$seqs; $i++ ) {
        print "seq$i: @{$seqs->[$i]}\n";    
    }

    for ( my $i = 0; $i < $self->seqCount(); $i++ ) {
        my $exD = $self->lines( $i );
        my @exs = $self->style()->sort( keys %$exD );
        foreach my $ex ( @exs ) {
            my $rng = $exD->{$ex};
            print "$ex: @$rng\n";
        }
    }            
}

=head2 variables

    $vars = $ltx->variables();
    $l = $vars->{"foo::bar"}[0]{line} # Get line of first matching foo::bar

Similar to matches(), returns match information keyed by the variable name.
The match information is an arrayref containing three element (line,val,pos)
hashes.  Match information for each variable is ordered by line.

    # keyed by variable name, ITM in this example:
    $vars = {
        foo::bar => [{
            line => 42,
            val  => "widgy",
            pos  => 15
        },{
            line => 71,
            val  => "nibbit",
            pos  => 14
        },{
        ...
        }],
        foo::bat => ...
    };

=head2 seqCount

    my $n = $x->seqCount();

Returns the amount of sequences found in the input file, or C<0> if the file
has not yet been read.

=cut

sub seqCount {
    my $self = shift;
    confess "check usage" if @_;
    return @{$self->{seqData}};
}

=head2 seqData

    my $d = $ltx->seqData();

Returns the numbering sequence data as an arrayref.  The format is [from, to]
where from and to are the starting and ending line numbers for each numbering
sequence.  If read() has not been called, the result is undefined.

=cut

=head2 exercises

    $exs = $ltx->exercises( 1 );

Returns an arrayref containing all of the exercises in the given sequence, in
the order they appear in the file.  If the given numbering sequence does not
exist, an undefined value is returned.

The list returned depends on maxLevel(). Only the same exercises visible through
_lines are returned.

=cut

sub exercises {
    my $self = shift;
    confess "check usage" unless @_ == 1;
    my $iseq = shift;
    
    my %exPos = %{$self->{exPos}[$iseq]};
    my %exsByPos = reverse %exPos;
    my @idxs = sort { $a <=> $b } keys( %exsByPos ); # sort numerically
    my @exs = @exsByPos{@idxs};
    
    return \@exs if $self->{maxLevel} == Tarp::LaTeXtract::ALL_LEVELS;
    
    my @pruned;
    foreach my $ex ( @exs ) {
        push @pruned, $ex
            unless @{ $self->style()->itemStack( $ex ) } - 1 > $self->{maxLevel}
            || ! $self->isLeaf( $ex, $iseq );
    }
    return \@pruned;
}

=head2 itemOnLine

    ( $ex, $seq ) = $xtr->itemOnLine( 111 )

Returns the item and sequence that contain the specified line.  The line that
an item number is on belongs to the exercise, up to the line before the tag that
ends the item region (another item or an "end" tag).

If the line number does not exist in the input file, C<undef> is returned.
If the line number is not in an item but does exist in the file, the exercise
is an empty string.

The return value is affected by maxLevel().  The item at the highest level
up to and including maxLevel is returned by this call.  If maxLevel is set to
Tarp::LaTeXtract::ALL_LEVELS, the highest level item (leaf) will be
returned.

=cut

sub itemOnLine {
    my $self = shift;
    my $line = shift;
    
    my ( $seqData, $maxLevel ) =
        @{$self}{qw/seqData maxLevel /};

    my ( $ex, $seq ) = ( '', undef );

    # which sequence is it in?    
    SEQ: for ( my $s = 0; $s < @$seqData; $s++ ) {
        if ( $seqData->[$s][0] <= $line &&
             $seqData->[$s][1] >= $line ) {
            $seq = $s;
            last SEQ;
        }
    }
    
    return unless defined $seq;
    
    my %sqData = %{$self->lines( $seq )};
    
    # Which exercise?
    ITM: while ( my ( $ex, $rng ) = each %sqData ) {
        if ( $rng->[0] <= $line &&
             $rng->[1] >= $line ) {
            if ( $maxLevel == Tarp::LaTeXtract::ALL_LEVELS  () ) {
                next ITM unless $self->isLeaf( $ex, $seq );
            }
            return ( $ex, $seq );
        }
    }
    return ( '', $seq );
}

=head2 lines

    $l = $x->lines( "01a", 0 );
    $l = $x->lines( 0 );

Returns a hashref holding the a copy of the item data for the C< $iseq >
numbering sequence. The structure is

    {
        "01a" => [ 42, 54 ]
        "01b" => [ 55, 63 ]
        .
        .
        .
    }

The keys are the exercises, and the values are the lines where those exercises
were found by the read() method.

If C< $iseq > is not a positive integer or does not exist in the TeX file, the
result is undefined. The result of this call is affected by maxLevel().
Exercises at a level higher than maxLevel() are not returned (if maxLevel >= 0).
Non leaf exercises are not returned in this case either. However, if maxLevel is
Tarp::LaTeXtract::ALL_LEVELS, all exercises including non leaf ones are
returned.

=cut

sub lines { 
    my $self = shift;
    my $iseq = shift;

    confess "check usage" unless defined $iseq && $iseq =~ /^\d+$/;

    my ( $_lines, $maxLevel ) =
        @{$self}{qw/_lines maxLevel/};
    
    return undef if ( $iseq < 0 || $iseq >= $self->seqCount() );
    
    # If all levels were being extracted, just return a copy of the
    # item data that was extracted.
    my %xd = %{$_lines->[ $iseq ]};
    return \%xd
        if ( $maxLevel == Tarp::LaTeXtract::ALL_LEVELS );

    # Otherwise, discard exercises above specified level...

    my %xd_trimmed = %xd;
    while ( my ( $ex ) = each %xd ) {
        my $level = @{ $self->style()->itemStack( $ex ) } - 1;
        delete $xd_trimmed{$ex} if $level > $maxLevel;
    }

    # ... then discard all non-leaf exercises...
    my %xd_slaughtered = %xd_trimmed;
    while ( my ( $ex ) = each %xd_trimmed ) {
        my $parent = $ex;
        while ( $parent = $self->style()->parentEx( $parent ) ) {
            delete $xd_slaughtered{$parent}
                if ( $parent && exists $xd_slaughtered{$parent} );
        }
    }
    
    # ... and return what is left.
    return \%xd_slaughtered;
}

=head2 item

    $xr = $xt->item( "01aiv", 0 );

Returns an item record, or an undefined value if the item does not exist
in the given numbering sequence.

=cut

sub item {
    confess "check usage" unless @_ == 3;
    my $self = shift;
    my $ex   = shift;
    my $iseq = shift;
    
    if ( ! $self->exists( $ex, $iseq )) {
        carp "Exercise $ex does not exist in sequence $iseq";
        return undef;
    }
    
    return $self->{_lines}[$iseq]{$ex};
}

=head2 exists

    $tf = $ltx->exists( "01a", 1 ) ? "yes" : "no";

Returns C<1> if the item given as a first argument exists in the numbering
sequence specified as a second argument, and an empty string otherwise.

All exercises in the file can be queried using this method, including those not
shown because of C<maxLevel>. Consequently, if an item exists, its ancestors
will also exist.

=cut

sub exists {
    my $self = shift;
    confess "check usage" unless @_ == 2;
    my $ex = shift;
    my $iseq = shift;
    
    my $exD = $self->{_lines}[ $iseq ];
    
    return defined $exD->{ $ex } ? 1 : '';
}

=head2 isSequential

    $tf = $x->isSequential( "01a", "01b", 0 ) ? "yes" : "no";

Returns C<1> if the given exercises exist and are sequential in the given
numbering sequence, the empty string if they exist in the given sequence but are
non-sequential, and C<undef> if one or both do not exist in the given numbering
sequence.

All exercises in the file can be queried using this method, including those not
shown because of C<maxLevel>.

=cut

sub isSequential {
    my $self = shift;
    confess "check usage" unless @_ == 3;
    
    my $first  = shift;
    my $second = shift;
    my $seq    = shift;

    foreach my $ex ( ( $first, $second ) ) {    
        if ( ! $self->exists( $ex, $seq ) ) {
            carp "Exercise $ex does not exist in sequence $seq"
                if $Debugging;
            return undef;
        }
    }
    
    # Sequential to
    # - next non-child
    # - first children of next in list
    
    my ( $exPos, $fileOrder )
        = @{$self}{qw/exPos fileOrder /};
    
    my @seqPositions;
    my $pos = $exPos->[$seq]{$first};
    
    return '' if $pos eq @$fileOrder - 1;
    
    my $lastChildPos = $pos;
    while ( $self->style()->isChild(
                $fileOrder->[$lastChildPos + 1][1],
                $first ) ) {
        $lastChildPos++;
    }
    my $nextNonChild = $lastChildPos + 1;
    push @seqPositions, $nextNonChild;
    
    # First children of next non-child
    my $firstChild = $nextNonChild;
    while ( $firstChild < @$fileOrder - 1 &&
            $self->style()->isChild( $fileOrder->[$firstChild + 1][1],
                            $fileOrder->[$firstChild][1] ) ) {
        $firstChild++;
        push @seqPositions, $firstChild;
    }
    
    # Sequential if the second value is one of those on the list.
    
    my $pos2 = $exPos->[$seq]{$second};
    my $found = '';
    
    foreach my $p ( @seqPositions ) {
        if ( $p == $pos2 ) {
            $found = 1;
            last;
        }
    }
    return $found;
}

=head2 isLeaf

    $yes = $ltx->isLeaf( "01", $seq );
    # true if there is no 01a, 01b etc. but false otherwise.

Returns C<1> if the given item is a "leaf" in the item tree - i.e.
it has no parts or subparts - and an empty string otherwise.  If the exercise
does not exist in the sequence given as a second argument, the result is
undefined.

The result of this call is affected by maxLevel. All existing exercises at the
maximum level are leaves (when maxLevel >= 0), even if they have parts or
subparts that are being ignored.

=cut

sub isLeaf {
    my $self = shift;
    confess "usage: OBJNAME->isLeaf( ex, seq )" unless @_ == 2;
    my $ex = shift;
    my $seq = shift;
    
    if ( ! $self->exists( $ex, $seq ) ) {
        carp "Exercise $ex does not exist in sequence $seq"
            if $Debugging;
        return undef;
    }
    
    my ( $maxLevel ) = @{$self}{qw/maxLevel/};
    
    my $es = $self->style()->itemStack( $ex );
    return 1 if @$es == 3;
    
    my @possibleChild = @$es;
    push( @possibleChild, 1 );
    
    return 1 if $#$es == $maxLevel;
    
    return $self->exists( $self->style()->itemString( \@possibleChild ), $seq ) ?
        '' : 1;
}

=head2 find

    (LINE, ITM, SEQ) = Tarp::LaTeXtract->find( "file.tex", qr/wyxnob/ );

Searches file.tex for a match with the regular expression given as a second
argument. Returns a three element array containing the first line, exercise
string and sequence where the regular expression matched, respectively. 


=cut

BEGIN {
    my $lastTEXfile = '';
    my $lastLine = -1;
    my $lastPos = -1;
    my $XTR = undef;
    
    sub find {
        my $class = shift;
        my $TEXfile = shift;
        my $exp = shift;
        my $opts = shift || {};
        
        if ( ! $XTR || $lastTEXfile ne $TEXfile ) {
            $XTR = Tarp::LaTeXtract->new();
            while ( my ( $opt, $val ) = each %$opts ) {
                $XTR->$opt( $val );
            }
            $XTR->style()->load() or die $XTR->style()->errStr() . ", stopped";
            $XTR->read( $TEXfile )
                or croak $XTR->errStr();
        }
        croak "Argument must be regular expression using qr//"
            unless ref $exp eq "Regexp";
        
        open TEX, $TEXfile or die "Could not open $TEXfile for reading: $!, stopped";
        
        LINE: while ( <TEX> ) {
            # Skip lines up to the last match
            next LINE if $. < $lastLine;
            my $remaining = substr $_, $lastPos;
            if ( $remaining =~ $exp ) {
                my ( $ex, $seq ) = $XTR->itemOnLine( $. );
                $lastLine = $.;
                $lastPos += $+[0];
                close TEX;
                return ( $lastLine, $ex, $seq );
            } else { $lastPos = 0; }
        }
        close TEX;
        $lastTEXfile = $TEXfile;
        return ( $lastLine );
    }
}

=head2 style

    $sty  = $ltx->style();
    $ltx->style( $sty );

Returns a reference to the C<Tarp::Style> object. Use Tarp::Style->import()
prior to L</new>() to affect behavior, or create Tarp classes using L</new>()
and then re-set the style using style( Tarp::Style->new() );

=cut

sub style {
    my $self = shift;
    if ( @_ ) {
        my $s = shift;
        confess "Argument to style() must be 'Tarp::Style' ref, stopped"
            unless defined $s && ref $s eq "Tarp::Style";
        carp "Setting style to a " . $s->parent() . " style" if $Debugging;
        $self->{style} = $s;
    } else {
        return $self->{style};
    }
}

=head1 Debugging Methods

=head2 debug

    Tarp::LaTeXtract->debug( 1 );
 
Sets the debugging level.  If set to a positive value, any method which returns
an undefined value will print a warning. Also, some debugging messages will be
printed to STDERR to aid in debugging.

=cut

sub debug {
    my $class = shift;
    confess "Class method called as object method" if (ref $class);
    confess "check usage" unless (@_ == 1);
    $Debugging = shift;
}

=head2 verbose

    Tarp::LaTeXtract->verbose( 1 );

Sets the verbosity level.

=cut

sub verbose {
    my $class = shift;
    confess "Class method called as object method"
        if (ref $class);
    confess "usage: CLASSNAME->verbose(bool)"
        unless (@_ == 1);
    $Verbose = shift;
}

=head2 context

    $n = $ltx->context();
    $ltx->context( 5 );

The amount of context (good matches) that read() puts in errStr() when a tag
error occurs. The default is three lines. The actual amount of lines may be
different if not enough matches are available.  

=cut

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{$name} && $name =~ /^[a-z]/ ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

=head1 SEE ALSO

=over

=item *

L<Tarp::LaTeXtract::TagLoader>

=item *

L<Tarp::LaTeXtract::BeginTagLoader>

=item *

L<Tarp::LaTeXtract::EndLoader>

=item *

L<Tarp::LaTeXtract::ItemTagLoader>

=item *

L<Tarp::LaTeXtract::SeqRestartLoader>

=item *

L<Tarp::LaTeXtract::TagLoader>

=back

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::LaTeXtract

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1; # End of Tarp::LaTeXtract