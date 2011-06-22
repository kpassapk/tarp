package Tarp::Style;

=head1 NAME

Tarp::Style - stylesheet using regular expressions

=head1 SYNOPSIS

    use Tarp::Style;
    
    # Import "Foo::Style" and specialization
    Tarp::Style->import( "Foo::Style", "Foo::Special::Style" );

    # Ignored: already have a "Foo::Style"
    Tarp::Style->import( "Foo::Style", "AnotherStyle" );
    
    # Not ignored:
    Tarp::Style->import( "Bar::Style" );

    my $sty = Tarp::Style->new();

    ----- numbers.tas -----

    hex = $num$
        hex::num = 0x(?:\\d|[a-f])+
        hex::EXACT = 1

    dec = $num$
        dec::num = \d+
    
    ----------------------
    
    $sty->load( "numbers.tas" ) or die $sty->errStr();
    
    my $hex = "0x02a";
    $sty->impXforms( 1 ); # to convert to integer
    
    my ( $dec ) = $sty->xform( $hex, "hex" => "dec" );
    print $dec;  # prints "42"

    # Reset
    $sty->loadString( $sty->emptyFileContents() );

=head1 DESCRIPTION

Tarp::Style maintains a hash of regular expressions. These can be loaded and
saved as TAS file entries with a very simple syntax (a bit like a Makefile).
Tarp::Style does not do anything with the entries themselves, although the user
or a Tarp::Style plugin may give them special significance. Values for each
entry are a list of regular expressions that typically represent various ways
something can be written in a file, for example:

    titleLine = \
        title:\s$title$$ \
        title\($title$\)

        titleLine::title = .*

would mean that a title line is written either

    title: Goldilocks and the Three Bears

or

    title(Goldilocks and the Three Bears)

So we can think of 'titleEntry' as a definition of the title "style". We can use
this entry to do a couple of useful things:

=over

=item *

If we have a string, determine whether it is a title string.  And if so, get the
actual title ("Goldilocks and the Three Bears") without the surrounding text.

To do this, we simply retrieve the regular expression list and match each item
against the string.  The qr() and m() methods are provided for this.

=item *

If we have a title, create a title string using the regular expression as a
template.

To do this, we use the interpolateVars() method.

=back

The only way in which Tarp:Style entries are not pure regular expressions is that
they may contain variables bracketed in dollar signs.  Variables hold little bits
of regular expressions that may be factored out of a regexp list, and remembered
by name when matching against the regexp.

In typical usage, Tarp::Style plugins are imported first, then a new Tarp::Style
object is instantiated. The user can then manipulate the entries and values
(regular expressions) maintained by the object, and use qr() and m() to match a
string against them. Matching against an entry in this way can be thought of as
an "is a" type check.  Also, going with this idea, a string can be converted
from one type to another.  To do this we create another entry with the same variable:

    ucTitle = my book is $title$
        ucTitle::title = [A-Z ]+   # uppercase!

    my $title = "title: Alice in Wonderland";
    
    # Uppercase the title string
    my ( $newTitle ) = $sty->xform( $title, "titleLine" => "ucTitle" );
    print $newTitle;  # prints "my book is ALICE IN WONDERLAND"

This example would require a style plugin to be loaded with a method like
the following:

    titleLine2ucTitle {
        my $oldTitle = $_[1][0];
        $oldTitle =~ s/[a-z]/[A-Z]/;
    }

Although a bit long winded for a small program, the benefit of this approach is
that it gives a nice and easy way to override the default behavior by reimplementing
methods like the one above.  Reimplemented methods are put into a style "plugin"
(more on this bleow).  Even without plugins, Tarp::Style is useful as a no frills
stylesheet that is flexible, easy to write and easy to understand.

This is how the most important methods are grouped by function:

=over

=item Manipulating entries

    exists(), entries(), values(), load(), save(), loadString(), saveString()

=item Matching & Variables

    qr(), m(), interpolate(), interpolateVars(), stripVars(), vars(), varsIn()

=item Variable Transforms

xform(), xformVars(), filterVars().

=item Plugin Mechanism

User calls:

    import()

Plugin optionally reimplements:

    emptyFileContents(), preRead(), postRead(), preWrite(), postWrite(), constraints()

=back

A style plugin may provide built-in entries.  These entries are available
through the style object but are not saved or loaded from a .tas file;
any changes made to these entries by the user will therefore not be loaded
or saved.  It is better to subclass a plugin and reimplement the read/write
methods below instead.

=head2 Style Plugins

Style plugins are packages loaded using import() that may reimplement
emptyFileContents(), constraints(), preRead(), postRead(), preWrite() and
postWrite() to affect the default and loaded/saved entries and verify those
loaded by the user.

By using a plugin, certain entries can exist by default when a new style is
created; also, when loading a C< TAS > file from disk, a set of constraints can
be enforced using Tarp::Tas::Spec.

See L<Tarp::Style::Plugin> for more.

=head2 Transformations

An implicit transformation is done if there is no "foo2bar" conversion to
transform variables from "foo" to "bar" context. In this case, common variables
are filtered out using filterVars, and some very basic transformations are
carried out using the source and destination variable definitions:

=over

=item integers

If the target variable definition is "\d+", the source value is typecast as an
integer.

=back

Implicit conversions can be disabled if the C<impXforms> flag is set to false:

    $hlp->impXforms( 0 );

Alternatively, an explicit conversion from entry "foo" to entry "bar" can be
specified by importing your own style plugin and implementing a method "_foo2bar".
The method will be called with the variable name as the first argument and an
array ref. containing the variable values as a second argument.

=cut

use Carp;
use Tarp::Style::Base;

my %fields = (
    parent => undef,
);

=head1 METHODS

=head2 import

    Tarp::Style->import( "Foo", "Bar" );

Imports style modules "Foo" and "Bar". Importing is done simply by inheriting
each of the arguments in a chain, and having Tarp::Style inherit the whole
chain, with Tarp::Style::Base at the bottom. The modules given as arguments are
inserted into the inheritance hierarchy between the last module imported and
Tarp::Style, or Tarp::Style::Base if import() has not been called. See
L< Tarp::Style/Plugin > for more.

=cut

sub import {
    my $class = shift;
    croak "Class method called as object method, stopped"
        if ref $class;
    my @plugins = @_;

    for ( @plugins ) {
        if ( $class->isa( $_ ) ) {
            carp "Ignoring import of '@plugins'" if Tarp::Style::Base->debug;
            return;
        }
    }

    no strict 'refs';
    my ( $p ) = @{"${class}::ISA"};
    use strict 'refs';
    
    $p = 'Tarp::Style::Base' unless defined $p;

    @plugins = ( $p, @plugins, $class);

    my $parent;

    carp "Importing '@plugins' " if Tarp::Style::Base->debug;

    while (my $child = shift @plugins) {
        eval "require $child";
        if ( $@ ) {
            $@ =~ /(.*) at/;
            my $err = $1;
            croak "Couldn't load style plugin '$child': $err, stopped";
        }
        ## no critic
        no strict 'refs'; #Violates ProhibitNoStrict
        @{"${child}::ISA"} = ( $parent ) if $parent;
        use strict 'refs';
        ## use critic

        $parent = $child;
    }

    return;
}

=head2 new

    $h = Tarp::Style->new();

Creates a new style by loading 'emptyFileContents()'.

=cut

sub new {
    my $class = shift;
    my ( $parent ) = @ISA;
    my $self = $class->SUPER::new();
    $self->{parent} = $parent;
    carp "Creating new '$parent' style"
        if Tarp::Style->debug;
    $self->loadString( $self->emptyFileContents() )
        or croak $self->errStr(). "\nStopped";
    return $self;
}

=head2 load

    $hlp->load();
    $hlp->load( "style.tas" );

In the first form, loads the file previuosly specified using the file()
method (or if none has been specified, the default TAS file.)  In the second
form, loads "style.tas".  Returns true if loading was successful, or false
otherwise.

=cut

sub loadString {
    my $self = shift;
    my ( $cp ) = @ISA;
    return $self->_error( "This object created with '$self->{parent}' parent")
        unless $cp eq $self->{parent};
    return $self->SUPER::loadString( @_ );
}

=head2 loadString

    $sty->loadString( $str );

Loads a stringified tasfile.  The preRead() method is first called with the
string contents, then the result is passed on to Tarp::TAS's readString() method,
and finally postRead() is called with the resulting data structure.  If successful
this is then checked against the constraints() using Tarp::TAS::Spec, returning
a true value if the string was up to spec and false otherwise.

=head2 saveString

    $str = $hlp->saveString();

Saves style information into a string.

=head2 save

    $hlp->save( "file.out" );

Saves style info to F<file.out>.


=head2 file

    $tas = $hlp->file();

Returns the name of the last TAS file used by the C<load()>
method, or an empty string if the method has not yet been called
or was unsuccessful.

=head2 vars

    @vars = $hlp->vars();               # all tas file
    @vars = $hlp->vars( "foo" );        # all 'foo' values
    @vars = $hlp->vars( "foo", 0 );     # 'foo' value 0

Returns a list TAS variables.  If an entry name is
given, returns only variables in that entry and its sub entries.  If an index
is specified, only the variables in the entry's value with that index are
returned (in this case, sub entry variables are not included).

In the first two forms, the order of the variables returned is undefined; in the
last, the list contains the variables as they appear left-to-right within the
entry. The return value undefined if the entry and/or index does not exist.

=head2 varsIn

    @vars = Tarp::Style->vasIn( "foo$bar$" );
    @vars = $hlp->varsIn( "foo$bar$" );

Returns a list of the variables in the specified string, minus the bracketing
dollar signs, in left-to-right order.

=head2 entries

    @list = $sty->entries();
    @e = $tas->entries( $level );

Returns a list of entries up to and including level $level. Level zero is the
plain old entries, one is the sub entries (e.g. 'foo::bar') etc. If $level is
not given, returns all entries. You can use this to iterate (inneficiently) over
the entries, using values() at each step. The list is not sorted, but sub
entries appear immediately after their parent entry.

=head2 exists

    $yes = $sty->exists( "entry" );

Returns a true value if "entry" exists, false otherwise.

=head2 values

    @vals = $hlp->values( "foo" );
    $hlp->values( "foo", qw/a b$c$/ );

Sets or gets the values for entry "foo". Sub entries are added if the new values
contain variables, and have a default value of '.+' If the entry does not
exist, an empty array is returned. Use exists() to find out if an entry exists or
not.

=head2 interpolate

    @array = $hlp->interpolate( "foo" );
    @array = $hlp->interpolate( "foo", Tarp::Style->NCBUFS () );

Returns interpolated values for entry "foo".  The second argument affects how
the sub values are inserted into the $ sign variables:

=over

=item INLINE

Interpolate variables straight into the string

=item PARENS

Interpolate variables using parenthesis capture buffers

=item NCBUFS

Interpolate using named capture buffers: (?<var>val)

=back

C< NCBUFS > is used by default. If you want to use the return values for pattern
matching, qr() will be quicker.

=head2 stripVars

    @vals = $sty->stripVars( "val1", "val2" );

=head2 interpolateVars

    @vals = $sty->interpolateVars( 'a$foo$' 'b$bar$',
        { foo => [ "foo" ],
          bar => [ "bar" ] } );

Interpolates the values with the variables specified as the last argument.
Variables are in the same format as %- (see also L<perlre>).

=head2 qr

    @qrs = $hl->qr( "foo" );
    if ( 'foo' =~ $qr[0] ) { ... }

Returns an array of precompiled regular expressions for entry "foo" The
following subvalues of 'foo' can modify the resulting regexp.

=over

=item C< CSENS > (C< 1 >)

If zero, modifies the regexp with /i. Default is one.

=item C< EXACT > (C< 0 >)

If one, brackets search terms with ^ and $.  Default is zero.

=item C< WORD > (C< 0 >)

If one, brackets search terms with \b.  Default is zero.

=back

=head2 m

    $yes = $sty->m( "entry" );
    $yes = $sty->m( "entry", $str );

A bit like perl's C<m//> operator, returns true if the string matches "entry",
false if it doesn't, and C<undef> if "entry" does not exist. If a string is not
specified, C<$_> is used. An entry matches if any one of its values matches.
After calling this method, the following accessor methods retrieve match
information:

=over

=item mIdx

Index of the value that matched (zero is the first value).

=item mParens

Holds paren match contents plus the matching text of the entire match in the
first element.  Equivalent to ( $&, $1, $2, $3... ).

=item mVars

A hash ref containing variable captures, alla %- (see L<perlre>).

=item mPos

A hash similar to the one returned by mVars but containing offsets where each
variable was found. This is a bit like a cross betwen %- and @-.

=back

Because all of these variables are saved, using m// is probably not as fast as
using qr// directly, but may be more convenient.

=head2 xform

    ( STR, VARS ) = $sty->xform( $str, "foo" => "bar" );

Transforms $str from "foo" to "bar" context.  $str is first matched against
"foo" values, stopping at the first match.  Variables captured are then
transformed using xformVars.  The resulting variables are then interpolated
into the value of the same index of "bar" (or the first if "bar" has only
one value).  Finally, the resulting string is matched against "bar", this time
using it as a regular expression.  Entries "foo" and "bar", then, are used
not only to deconstruct and reconstruct $str, but also to do some sanity
checking on the values coming in and out.

If $str does not match "foo" or its variables could not be transformed, returns
C<undef> and sets the C< errStr() >.  This method requires C< foo::EXACT > and
C< bar::EXACT > to be true.

=head2 xformVars

    $newVars = $sty->xformVars( \%-, "foo" => "bar" );

Transforms variables from "foo" context to "bar" context by calling "foo2bar"
methods or performing an implicit conversion.  See "Implicit Conversions" above
for more details.

=head2 filterVars

    $newVars = $sty->filterVars( \%-, "foo" => "bar" );

Returns (a array ref to) the variables in the first argument that exist in "foo"
and "bar", and removes those that exist in "foo" but not "bar".

=head2 errStr
    
    $sty->errStr();

Returns an error string for the last error encountered.

=head2 constraints

    $sty->constraints( $tas );

If you don't import any plugins, this class returns a constraints hash (see
Tarp::TAS::Spec) for every entry in $tas that checks regular expression syntax.

You could write a plug in that checks for the existence of some_entry
when new(), load() or loadString() is called, as follows:

    package MyStyle;
    sub new { my $class = shift; return bless $class->SUPER::new(), $class }
    
    sub emptyFileContents {
        my $self = shift;
        return $self->SUPER::emptyFileContents() . <<EOT
    
    some_entry = bla
    
    EOT
    }
    
    sub constraints {
        my $self = shift;
        my $tas = shift;
        my %c = $self->SUPER::constraints( $tas );
        $c{some_entry} = Tarp::TAS::Spec->exists();
        return %c;
    }

The default value for some_entry is set in emptyFileContents().  A check
for user written files is given in constraints().

=head2 defaultTASfile

    my $f = $hlp->defaultTASfile();

Returns the name of the default TAS file that exists in the current directory.
Possible defaults are 'TASfile', 'TASfile.tas' and 'TASfile.txt'.  Returns
undefined and sets the error string if no suitable default could be found, or
if more than one default was found.

=head1 DEBUGGING METHODS

=head2 debug

    Tarp::Style->debug( 1 );

Sets the amount of debugging messages printed.  Level zero is none, one gives
a good amount and two gives lots and lots of messages.  The default is zero.

=cut

1; # End of Tarp::Style
