package Tarp::TAS;

use strict;
use warnings;
use Carp qw/confess carp croak/;
use Data::Dump qw/dump/;
use Text::ParseWords qw/quotewords/;

=head1 NAME

Tarp::TAS - load TAS file

=head1 SYNOPSIS

    use Tarp::TAS;
    
    # Given a file style.tas that contains:
    # /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
    # |                                  |
    # | foo = foo\ $bar$\ $bat$$bat$     |
    # |                                  |
    # | foo::BAR = bar                   |
    # | foo::BAT = bat man               |
    # |                                  |
    # \/\/\/\/\/\/\/\/\/\/\/\/\/\/\//\/\/

    my $tas = Tarp::TAS->read( "style.tas" )
        or die "Error loading style.tas: " . Tarp::TAS->errStr() . "\n";

    my $e = $tas->{foo}->[0];      # 'foo $bar$ $bat$$bat$'
    my $ev = $tas->{foo}->[ -1 ];
    
    # Create a new entry
    $tas->{new} = [{}]
    
    for ( my ( $var, $val ) = each %$ev ) {
        print $var . ": " . $val->[0] . "\n";
    }

    # prints:
    # bar: bar
    # bat: bat
    
    
    
    $s = $tas->interpolate( "foo" );

    # $s contains "foo bar batman"

=head1 DESCRIPTION

Tarp::TAS loads style loads a Tarp Style (C<TAS>) file. This file has a very
smiple format consisting of named entries and zero or more values:

    entry = valueWith$VAR$ valueWithoutVar valueWith\#poundSign \
            valueOnNextLine \
            "value with spaces"
            value\ with\ \spaces\ and\ \"quotes\"
    
    # Sub values:
    entry::VAR = foo              # Comment

Entries may contain variables, couched between dollar signs.  Variables can be
in more than one value.  If a variable is found in a value, it must be defined
in a sub value to the entry containing that value. Sub values are scoped using
C<::> as shown. Variable definitions follow exactly the same rules as plain old
entries, and may contain variables of their own.

Variable definitions may be inserted into their parent value by using the
"interpolate" method. Successive occurences of the same variable in a string are
replaced by the values of the same index in the variable definition,
although if a variable definition contains only one value, this value will be
treated as "universal" and will be used for all occurences of the variable.

A non-existent entry is C<undef>.  An empty entry is represented by a one element
array containing an empty hashref: [{}].  Sub entries may denote something else
than variable definitions; this is not checked and is up to the user.  The only
check done (during load() or loadString()) is to ensure dollar-sign variables
are actually defined in a sub entry.

=head2 More on TAS files

=over

=item *

Variables may be shared between one or more values

    foo = foo$BAR$$BAT$ foo$BAT$

    foo::BAR = bar
    foo::BAT = bat

    # interpolated as "foobarbat" and "foobar"

=item *

Be careful with dollar signs:

    dollar = $          # matches $ or a$b

    dollarUnEsc = a$b   # ...however, this does not match a$b or a\$b

    dollarEsc = a\$b    # Matches a$b, not a\$b

=back

=cut

my $errStr = '';

my $ENAME = '[a-z]\w*(?:\[\d+\])?';
my $ISAPATH = qr/^$ENAME(?:::$ENAME)*$/i;


=head1 METHODS

=head2 new

    $tas = $tas->new();

Creates a new, empty TAS object.

=cut

sub new {
    my $class = ref $_[0] ? ref shift : shift;
    return $class->readString( '' );
}

=head2 read

    $tas = Tarp::TAS->read( "file.tas" );

Loads file.tas and returns the entry data structure.

=cut

sub read {
    my $class = ref $_[0] ? ref shift : shift;
    my $file = shift;
    confess "check usage" unless $file;
    return $class->_error( "File '$file' does not exist" )              unless -e $file;
    return $class->_error( "'$file' is a directory, not a file" )       unless -f _;
    return $class->_error( "Insufficient permissions to read '$file'" ) unless -r _;

    # Slurp in the file
    local $/ = undef;
#    local *TAS;
    open( TAS, $file )
        or return $class->_error( "Failed to open file '$file': $!" );
    my $contents = <TAS>;
    
    close TAS or return $class->_error( "Failed to close file '$file': $!" );

    return $class->readString( $contents );
}

=head2 readString

    $tas = Tarp::TAS->readString( $str );

Attempts to load a string and turn it into a TAS data structure.  This method
may fail (returning false and setting errStr) if the input string is not in the
right format or if there are orphan entries - entries with :: whose parent does
not exist.

$ variables are checked when this method is called. If a variable is not
defined in the immediate sub entry,

=cut

sub readString { 
    my $class  = shift;
    confess "Class method  called as object method" if ref $class;
    my $string = shift;
    
    confess "check usage" if ref $class;
    confess "check usage" unless defined $string;
    
    $class->_error( '' ); #reset the error string
    
    $string =~ s/([^\\])#.*\n/$1\n/g; # Get rid of comments
    $string =~ s/\\\s*\n//g; # get rid of trailing backslash and newline
    # Split the string into lines
    my @lines = grep { ! /^\s*(?:\#.*)?$/ } split /\n/, $string;

    my %e;
    my $l = 0;
    while ( @lines ) {
        $_ = shift @lines; $l++;
        s/\\#/#/;          # Fixed escaped comment
        if ( /(\S+?)\s*=.*$/ && $1 =~ $ISAPATH ) {
            my ( $name, $vals, @r ) = split qr/\s*=\s*/;
            $name =~ s/\s//g; # Get rid of whitespace in name
            $name =~ s/\[(\d+)\]$/_$1_/;
            return $class->_error( "Check for trailing backslash (or unescaped equal sign) in '$name'" ) if @r;
            my @vals = defined $vals ?
                grep { defined $_ } quotewords( '\s+', 1, $vals ) :
                ();
            return $class->_error( "Duplicate entry: '$name'" )
                if exists $e{$name};
            $e{$name} = \@vals;
            push @{$e{$name}}, {};
        } else {
            return $class->_error( "syntax error: badly formed entry '$_'" );
        }
    }
    
    # Move variables to where they belong
    my $parent = '';
    my %pe = ();
    while ( my ( $entry, $values ) = each %e ) {
        my $parent = '';
        my $e = $entry;
        if ( $e =~ /^(.*)::(.*?)$/ ) {
            $parent = $1;
            my $s = $2;
            my $p = $parent;
            $p =~ s/\[(\d+)\]$/_$1_/;
            if ( ! $e{$p} ) {
                return $class->_error( "Entry '$parent' referenced in '$entry' not found" );
            }
            $e{$p}->[-1]->{$s} = $values;
        }
    }

    my @nonVars = grep { ! /::/ } keys %e;
    my %nv;
    @nv{@nonVars} = @e{@nonVars};
    $class->_checkVars( \%nv )
        or return $class->_error;

    my $self = bless \%nv, $class;
    return $self;
}

=head2 write

    $tas->write( "out.tas" );

Writes all entries in $tas to "out.tas".

=cut

sub write {
    my $self = shift;
    my $file = shift;
    
    my $usage = "check usage: \$tas->write( \"file.tas\" )";
    croak $usage unless $file;
    
    open( TAS, ">$file" )
        or return $self->_error( "Failed to open file '$file' for writing: $!" );
    
    my $str = $self->writeString();
    print TAS $str;
    
    close TAS or croak "Could not close '$file': $!, stopped";
    return length $str ? 1 : '';
}

=head2 writeString

    $str = $tas->writeString();

Returns stringified TAS contents.

=cut

sub writeString {
    my $self = shift;
    my $str = $self->_writeTree( $self, '' );
    chomp $str;  # Remove the last newline
    return $str;
}

sub _writeTree {
    my $self = shift;
    my $entries = shift;
    my $pre = shift;
    
    my $str = '';
    # escape comments
    my $esc = sub { $_ = shift; s/#/\\#/g; $_;};
    
    my $indent = $pre;
    $indent = 4 * ( ( $indent =~ tr/:// ) / 2 );
    foreach my $entry ( sort keys %$entries ) {
        next if $entry =~ /^_/;
        my $es = $entries->{$entry};
        
        # Replace undescore endings with subscript
        my $printEntry = $entry;
        $printEntry =~ s/_(\d+)_/\[$1\]/;
        $str .= sprintf( "%*s", $indent, '' ) . "$pre$printEntry = ";
        if ( @$es == 1 ) {
            $str .= "\n";
        } elsif ( @$es == 2 ) {
            $str .= &$esc( $entries->{$entry}->[0] ) . "\n";
#            $str .= $entries->{$entry}->[0] . "\n";
        } else {
            $str .= "\\\n";
            for ( my $i = 0; $i < @$es; $i++ ) {
                $_ = $entries->{$entry}->[$i];
                next if $i == @$es - 1;
                $str .= sprintf( "%*s", $indent + 4, '' ) . &$esc( $_ );
#                $str .= sprintf( "%*s", $indent + 4, '' ) . $_;
                $str .= ( $i < @$es - 2 ) ? " \\\n" : "\n";
            }
        }
        $str .= "\n";
        my $vars = $entries->{$entry}->[-1];
        $str .= $self->_writeTree( $vars, "$pre$entry\::" );
    }
    return $str;
}

sub _checkVars {
    my $class = shift;
    my $root  = shift;
    my $pre   = shift || '';
    
    my $ok = 1;
    
    foreach my $e ( keys %$root ) {
        my $vals = $root->{$e};
        $ok &&= $class->_checkVars( $vals->[-1], "$pre$e\::" );
        foreach my $val ( @$vals ) {
            next if ref $val;
            my @vars = $class->varsIn( $val );
            foreach my $var ( @vars ) {
                $ok &&= defined $vals->[-1]->{$var} ? 1 :
                    $class->_error( "Variable '$pre$e\::$var' not defined" );
            }
        }
    }
    return $ok;
}

=head2 entries

    @e = $tas->entries();
    @e = $tas->entries( $level );

Returns a list of entries up to and including level $level. Level zero is the
plain old entries, one is the sub entries (e.g. 'foo::bar') etc. If $level is
not given, returns all entries.You can use this to iterate (inefficiently) over
the entries, using values() at each step.  The list is not sorted, but sub
entries appear immediately after their parent entry. 

=cut

sub entries {
    my $self = shift;
    my $maxLev = defined $_[0] ? shift : -1;
    
    my $class = ref $self;
    return $class->_getEntryList( $self, '', $maxLev );
}

sub _getEntryList {
    my $class = shift;
    my $root = shift;
    my $pre = shift;
    my $maxLev = shift;

    $_ = $pre;
    my $l = tr/:// / 2;
    
    my @entries = ();
    foreach my $e ( keys %$root ) {
        next if $e =~ /^_/;
        my $fqe = "$pre$e";
        push @entries, $fqe;
        unless ( ref $root->{$e} eq "ARRAY" && @{ $root->{$e} }
                && ref $root->{$e}->[-1] eq "HASH" ) {
            croak $class->_bad_tas( $fqe, $root->{$e} );
        }
        push @entries, $class->_getEntryList( $root->{$e}->[-1], "$fqe\::", $maxLev )
            if $maxLev < 0 || $l < $maxLev;
    }
    return @entries;
}

sub _bad_tas {
    my $class = ref $_[0] ? ref shift : shift;
    my $estring = shift;
    my $r = shift;

    use Data::Dump qw/dump/;
    return "Bad TAS data structure for '$estring': " . dump( $r  ) . "(should be [ \"foo\", \"bar\", {}]), stopped";
    
}

=head2 values

    $array = $tas->values( "foo::bar" );
    $tas->values( "foo::bar", qw/a b$c$/ );

Returns the values of entry C<foo::bar> as an arrayref. In the second form, sets
the values and returns them. The return value is undefined if "foo::bar" does
not exist in the tas file.  An entry "foo::bar" can only be added if "foo"
already exists. If setting values with variables, like in the example above, a
new placeholder entry for each variable consisting of C<.+> will also be added.
In the example above, the line will be "foo::bar::c = .+"

The last element in the arrayref is a hashref that contains variable definitions
and other sub values.  This can be retrieved as values()->[-1] or
values()->[ -1 ] for clarity.

sub values {
    my $self = shift;
    my $path = shift;
    my @vals = @_;
    
    return $self->_error( "invalid path: '$path'" )
        unless $path =~ $ISAPATH;
    my @le = split /::/, $path;
    my @p = map { "{$_}" } split /::/, $path;
    @p[ 0 .. @p - 2] = map { $_ . "->[-1]->" } @p[ 0 .. @p-2 ] if @p > 1;
    my $v;
    my $x = '$v = $self->' . join '', @p;
    my $e = ''; # "exists"
    if ( @vals ) {
        my %evars = ();
        foreach my $val ( @vals ) {
            my @ev = $self->varsIn( $val );
            @evars{@ev} = map { [".+", {} ] } @ev;
        }
        # Make new variable definition sub-entries
        my $evars = dump %evars;
        eval $x . " = [ \@vals, { $evars } ]";
        if ( ! $@ ) {
            $self->_loadVars( [ $self ] );
            $e = 1;
        }
    } else {
        eval $x;
#        my $r = $self;
#        $e = 1;
#        foreach ( @le ) {
#            croak $self->_bad_tas( $r ) unless ref $r eq "HASH";
#            if ( ! defined $r->{$_} ) {
#                $e = '';
#                last;
#            }
 #           $r = $r->{$_}->[-1];
 #       }
        $e = 1 if $v;
    }
    return $self->_error( "Entry '$path' does not exist" ) unless $e;
    return $v;
}

=cut

sub values {
    my $self = shift;
    my $path = shift;
    
    croak "check usage" if @_;
    croak "check usage" unless defined $path;
    croak "invalid path: '$path'" unless $path =~ $ISAPATH;
    my @le = split /::/, $path;

    my $r = $self;  # root hash
    my $a = undef;  # array of values
    my @d = ();     # "done"
    
    foreach ( @le ) {
        push @d, $_;
        if ( exists $r->{$_} ) {
            $a = $r->{$_};
            if ( ref $a eq "ARRAY" && ref $a->[-1] eq "HASH" ) {
                $r = $a->[-1];
                next;
            } else {
                croak $self->_bad_tas( join "::", @d, $a );
            }
        } else {
            $self->_error( "'$path' does not exist" );
            return '';
        }
    }
    return $a;
}

=head2 interpolate

    $array = $tas->interpolate( "foo" );
    $array = $tas->interpolate( "foo", FORMAT, LIST );

Similar to values(), but also interpolates dollar sign variables with values
in the immediate sub entry. If variable definitions have multiple values, these
are subbed in to each appearance of the variable in the original string:

    # tas:
    entry = "$a$ your $a$ down the $a$"
        entry::a = row boat stream
    
    # ---
    
    $str = $tas->interpolate( "entry" );
    # $str contains "row your boat down the stream"

But if you have only a single value, that is OK too:

    # tas:
    entry = "a $b$ is a $b$"
        entry::a = deal
    
    # ---

    $str = $tas->interpolate( "entry" );
    # $str contains "a deal is a deal"

C<FORMAT> and C<LIST> are optional sprintf arguments to format the variable
values prior to interpolation. In LIST you can use C<$VAR$> to mean the name of
the variable being interpolated (not fully qualified) and C<$VAL$> to mean the
value.

For example, suppose entry $foo contains regular expressions with variables that
should be kept as regexp memory (parens) using named capture buffers. Then this,

    $array = $tas->interpolate( "foo", "(?:<%s>%s)", '$VAR$', '$VAL$' );

will give you a string that you can match against and extract the submatches
using %-.  See L<perlvar/%-> for more information.  Note that named capture
buffers were introduced in Perl 5.010. 

This method can return C< undef > if the TAS data structure is inconsistent
or if the path does not exist.

=cut

sub interpolate {
    my $self = shift;
    my $path = shift;
    my $fmat = shift || "%s";
    my @list = $_[0] ? @_ : ( '$VAL$' );
    
    my $vals = $self->values( $path )
        or return $self->_error( $self->errStr() );
    
    my @iv;
    for ( my $i = 0; $i < @$vals - 1; $i++ ) {
        my $v = $self->_interpolateTree( $vals, $i, $path, $fmat, @list );
        return unless defined $v;
        push @iv, $v;
    }
    \@iv;
}

=head2 interpolateValues

    $array = Tarp::TAS->interpolateValues( $vals );
    $array = Tarp::TAS->interpolateValues( $vals, FORMAT, LIST );

Similar to L< /interpolate >, but takes a reference to a C< TAS > data structure
instead (a ref to a list of values terminated by an array ref containing variable
definitions).  C< FORMAT > and C< LIST > affect the output in the same way as
explained in interpolate().

This method may return C<undef> if the TAS data structure is inconsistent.  

=cut

sub interpolateValues {
    my $class = shift;
    my $vals  = shift;
    my $fmat  = shift || "%s";
    my @list  = $_[0] ? @_ : ( '$VAL$' );
    
    my $path  = '';

    my @iv;
    for ( my $i = 0; $i < @$vals - 1; $i++ ) {
        my $v = $class->_interpolateTree( $vals, $i, $path, $fmat, @list );
        return unless defined $v;
        push @iv, $v;
    }
    \@iv;
}

sub _interpolateTree {
    my $class = ref $_[0] ? ref shift : shift;
    my $vals  = shift; # ARRAY ref with tas data
    my $idx   = shift; # Index to interpolate
    my $pre   = shift; # Prepend this to path followed by :: (e.g. "foo::")
    my $fmat  = shift; # format string for sprintf
    my @list  = @_;    # list for sprintf
    
    return $class->_error( "Inconsistent TAS data for '$pre': last element is not ARRAY ref" )
        unless ref $vals eq "ARRAY";
    my $vars = $vals->[ -1 ];
    if ( @$vals == 1 ) {
        carp "Warning: entry '$pre' is empty";
        return '';
    } elsif ( $idx < @$vals - 1 ) {
        # in range
        if ( ! keys %$vars ) {
            return $vals->[$idx];
        }
    } else {
        # Out of range
        carp "warning: index '$idx' out of range of entry '$pre'"
            if ( @$vals > 2 ); # otherwise use zero as universal
        return $class->_interpolateTree( $vals, 0, $pre, $fmat, @list );
    }
    my $valString = $vals->[ $idx ];
    my @entryVars = $class->varsIn( $valString );
    my %c = map { $_ => 0 } @entryVars;
    foreach my $var ( @entryVars ) {
        croak "$pre\::$var does not exist" unless $vars->{$var};
        my @varVals = @{$vars->{$var}};
        my $rep = $class->_interpolateTree(
            $vars->{$var}, $c{$var}++, "$pre\::$var", $fmat, @list );
        my %r = ( '$VAL$'  => $rep, '$VAR$'  => $var );
        my @l = map { exists $r{$_} ? $r{$_} : $_ } @list;
        $rep = sprintf $fmat, @l;
        $valString =~ s/\$$var\$/$rep/;
    }
    return $valString;
}

=head2 varsIn

    @v = Tarp::TAS->varsIn( "foo$bar$" );
    @v = $tas->varsIn( "foo$bar$" );

Returns a list of the variables in the specified string, minus the bracketing
dollar signs, in left-to-right order.  The only semi clever thing that this
method does is ignore escaped dollar signs. 

=cut

sub varsIn {
    my $class = ref $_[0] ? ref shift : shift;
    my $str = shift;
    
    my @vars = ();
    
    while ( $str =~ /\$(\w+?)\$/g ) {
        # Get character before the match, or empty string if the
        # match was at the beginning of the string.
        my $pre = $-[0] ? substr $str,  $-[0] - 1, 1 : '';
        if ( $pre eq "\\" ) {              # if escaped
            pos( $str ) = pos( $str ) - 1; # go back one character
        } else {
            push @vars, $1;
        }
    }
#    if ( ! @vars ) {
#        while ( $str =~ /\(\?\<(\w+)\>.*?\)/g ) {
#            push @vars, $1;
#        }        
#    }
    @vars;
}

sub _error {
    $errStr = $_[1] if defined $_[1];
    undef;
}

=head2 errStr

    $tas->errStr();
    Tarp::TAS->errStr();
    
Returns an error string for the last error encountered.

=cut

sub errStr {
    return $errStr;
}

1; # End of Tarp::TAS