package Tarp::varExtract;

use warnings;
use strict;

=head1 NAME

Tarp::varExtract - practical content extractor using TAS variables

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

=head1 SYNOPSIS

    #- If 'test.tex' contains: 
    
    test: bla
    
    #-#-#-#-#-#-#-

    use Tarp::varExtract;

    my $vex = Tarp::varExtract->new();
    $vex->style()->values( "fileBase_search", 'test:\s$foo$' );

    $vex->extract();

    $vex->write( "out.yml" );

    #- out.yml -#-#-#-#-#-#-#-#-#-

    ---
    test:
      foo: bla

=head1 DESCRIPTION

This module extracts content from a collection of files in the current directory
using TAS variables.  The extraction of variables is performed as follows:

=over

=item 1.

The name of each file in the current directory is matched against the
C<filename> entry in the TAS file, whose variables split the filename into
pieces (by default the file base name and the extension, see Tarp::varExtract::Style)

If the entry contains multiple values, each is tested until a match is found.
Multiple expressions are useful for defining file "templates" to be processed
differently, as explained below. To use another entry instead of "filename", use
the style's C<fnameEntry()> method.

=item 2.

If a match is found, another tag in the C<TAS> file (named the same as each
variable in the matching entry with C<_search> appended) is used for patterns
to be searched for in this file's header. When an expression matches, the
content of any variables in this expression are saved.  All values of the
C<*_search> entries are matched against.

Because C<*_search> terms are used only for the variables in the matching
C<filename> entry, you can search for different variables in different kinds
of files.  Suppose you have both .txt and .html files in the current directory.
In your TAS file you could say,

    filename = $file$\.$txt$ $file$\.$html$
        filename::txt  = txt
        filename::html = html

    txt_search = "The $dog_color$ dog jumped over the $fox_mood$ fox"
        txt_search::dog_color = \w+
        txt_search::fox_mood = \w+
    
    html_search = <title>$title$</title>
        html_search::title = .*

The C<filename> tag gives two "templates" for the input filenames to search for;
each template is processed differently because in *.txt files we search for
dog color and in html files we search for a title.  

By default the first 30 lines of each file are treated as the header.  This
can be changed by setting C< $Tarp::varExtract::HEADER_LINES >.

=item 3.

The search proceeds until all files in the current directory have been searched.

=back

The resulting variables can be printed to a C<YAML> file using the write() method
or accessed using the vars() method.  In C<YAML> syntax, the structure is

    file1:
        dog_color: brown
        fox_mood: lazy
    file2:
        title: Moby Dick
    ...

The keys are file base names, used as a "nickname" for the file itself.  If there
is a nickname conflict (for example, if there are files called "foo.tex" and
"foo.txt" that would both hav a nickname "foo") then the file names themselves
are used as keys and a warning is printed.

Nicknames are determined by getting the contents of the first variable match
in C<filename> (by default the file base name, see L<Tarp::varExtract::Style>).
This can be changed to another variable index by using the nicknameVar() method.

=cut

use Carp;

use YAML::Tiny;
use Tarp::Style;

my $HEADER_LINES = 30;

my %fields = (
    nicknameVar => 0,      # first
    vars        => undef,
    style       => undef,
);

my $Verbose = '';

our $AUTOLOAD;

=head1 METHODS

=head2 new

    $vex = Tarp::varExtract->new();

Initializes a new Tarp::varExtract object.  Style is imported from
Tarp::varExtract::Style.  The following can be set through accessor methods:

=over

=item nicknameVar

The index of the variable in the matching C<filename> I<TAS> entry to use as a
nickname for the file. If a variable with this index does not exist in the
matching I<TAS> entry, the filename will be used. Default: C<0> (use the first
variable).

If set to an empty string, the filename will be used instead.

=back

=cut

sub new {
    my $class = shift;
    return if @_;
    
    my $self  = {
        %fields,
        _nicknames  => {},
        _files      => {},
    };

    Tarp::Style->import( 'Tarp::varExtract::Style' );
    my $sty = Tarp::Style->new();
    $self->{style} = $sty;    
    $self->{vars} = {};
        
    bless $self, $class;
    return $self;
}

=head2 extract

    $vex->extract();

Extracts variables from the current directory.  Variables can then be queried
with the vars() method.

=cut

sub extract {
    my $self = shift;
    
    my $sty = $self->{style};
    
    my %dirVars = (); # variables in all files in cwd
    
    opendir DIR, "." or die "Could not opendir '.': $!, stopped";
    my @files = grep { -f $_ } readdir DIR;
    closedir DIR;
    
    FILE: foreach my $file ( @files ) {
        
        if ( $sty->m( $sty->fnameEntry(), $file ) ) {
        
            print $file . ": " if $self->verbose;
            # A file matches this pattern.

            my %varsFound = %{$sty->mVars()};
            my $section = $file;
            if ( $self->{nicknameVar} =~ /^-?\d+$/ ) {
                my @filenameVars = $sty->vars( $sty->fnameEntry(), $sty->mIdx() );
                my $sectionVar = $filenameVars[ $self->{nicknameVar} ]; 
                $section = $varsFound{ $sectionVar }[ 0 ]
                    if defined $sectionVar;
            }
            if ( $dirVars{ $section } ) {
                warn "Warning: Files '$self->{_files}{ $section }' and '$file' ",
                    "both have the same nickname '$section'.  " ,
                    "Using filenames instead.\n";
                $self->{nicknameVar} = '';
                # This should not result in deep recursion, because
                # filenames are unique within a directory!
                return $self->extract(); # re extract with filenames.
            }
            $self->{_nicknames}{$file} = $section;
            $self->{_files}{$section} = $file;
            my %fileVars = ();
    
            while ( my ( $var, $vals ) = each %varsFound ) {
                my $titleEntry = "$var\_search";
                
                if ( $sty->exists( $titleEntry ) ) {
                    my @searchExps = $sty->qr( $titleEntry );
                    open FILE, '<', $file
                        or croak "Could not open $file for reading: $!, stopped";
                    
                    LINE: while ( <FILE> ) {
                        chomp;
                        s/\n$//; s/\r$//;
                        foreach my $fre ( @searchExps ) {
                            if ( $_ =~ $fre ) {
                                # Take only first value in %-
                                my %expVars = map { $_ => $-{$_}->[0] } keys %-;
                                # Add this entry's matches to %fileVars.
                                @fileVars{ keys %expVars } = values %expVars;
                                print join( ' ', keys %expVars ) if $self->verbose;
                            }
                        }
                        last LINE if $. > $HEADER_LINES;
                    }
                    close FILE;
                } # if a search term exists
            } # for each variable found
            print "\n" if $self->verbose;
            $dirVars{ $section } = \%fileVars;
        } # if ( m(filename) )
    } # foreach @files
    $self->{vars} = \%dirVars;
    1;
}

=head2 vars

    $v = $vex->vars();

Gets a hash ref with the variable match contents for every file in the current
directory resulting from the last call to L</extract>(), keyed by each file's
nickname.

=head2 nickname

    $vex->nickname( "file.tex" )

Returns the nickname for 'file.tex', or C<undef> if this file was not processed
by L<extract>().

=cut

sub nickname {
    my $self = shift;
    my $file = shift;
    return $self->{_nicknames}{ $file };
}

=head2 file

    $vex->file( "01" );

Returns the file with nickname '01'.

=cut

sub file {
    my $self = shift;
    my $nickname = shift;
    return $self->{_files}{ $nickname };
}

=head2 write

    $vex->write( "out.yml" );

Writes output variables to the specified file.

=cut

sub write {
    my $self = shift;
    my $outFile = shift;
    
    confess "check usage" unless $outFile;
    
    my $vars = $self->{vars};
    
    my $yaml = YAML::Tiny->new();

    @{$yaml->[0]}{ keys %$vars } = values %$vars;
    
    $yaml->write( $outFile )
        or croak "Error while writing '$outFile': " . $yaml->errstr . ", stopped";
}

=head2 style

    $sty = $vex->style();
    $vex->style( $sty );

Accesses the C<Tarp::Style> object associated with this object.

=head2 verbose

    $vex->verbose( 1 );
    $yes = $vex->verbose();

Sets or gets the 'verbose' flag

=cut

sub verbose {
    my $class = ref $_[0] ? ref shift : shift;
    if ( @_ ) {
        return $Verbose = shift;
    } else {
        return $Verbose;
    }
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless ( exists $self->{$name} && $name =~ /^[a-z]/ ) {
        croak "Can't access `$name' field in class $type";
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

    perldoc Tarp::varExtract

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1; # End of Tarp::varExtract
