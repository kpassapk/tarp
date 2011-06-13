package Tarp::Burn;

=head1 NAME

Tarp::Burn - BUlk ReName a list (or files in this directory)

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

=head1 SYNOPSIS

    use Tarp::Burn;

    my $foo = Tarp::Burn->new();

    $foo->style()->load( "myStyle.tas" );
    
To rename files "foo.txt" and "bar.txt" in the current directory to "bat.txt"
and "mog.txt", respectively, specifying 1:1 transformations using a hash ref:

    # note that "name" is a variable in the default style's source entry
    $foo->bulkRename(
        name => {
            foo => "bat",
            bar => "mog"
        }
    );

A C< CODE > ref can also be used for more versatile transformations (here,
F< foo.txt > is renamed F< oof.txt >, F< bar.txt > is renamed F< rab.txt >. )

    $foo->bulkRename(
        name => sub {
            reverse shift;
        }
    );

=head1 DESCRIPTION

This module transforms (renames) lots of strings at once. It is intended
for renaming files in the current directory, but it can also be used on an
arbitrary list.

Original values are called "source" strings, and the new ones created by
Tarp::Burn are called "destination" strings. Destination strings are created by:

=over

=item 1.

Splitting up source strings into parts

=item 2.

Modifying (transforming) these parts

=item 3.

Rearranging and possibly eliminating some of these parts

=item 4.

Inserting other text (e.g. ".tex")

=back

The strength of this module is that a lot of these transformations (steps 1, 3, 4) can be done
by manipulating the style - typically by editing a C<TAS> file. Step 2 is
uses transformaions given to the bulkRename() method.

Source strings are split into parts by matching the source string against the
style's source entry. Variables in this entry contain substrings of the original
strings. If the source entry contains multiple values, each value is tried until
a match is found. The program remembers which value matched, and will construct
the output using the same value index in the destination entry (unless the
destination entry contains only one value, in which case that one is used) as a
catch-all.

Here's how to change behavior by modifying the source and destination entries:

=over

=item *

Change the way source strings are split up (step 1)

To do this, edit the source entry. Only one value needs to match, so use one
value for each kind of string you would like to treat differently, for example:

    source = $texfile$\.tex $htmlfile$$d$\.html
        source::texfile = .+
        source::htmlfile = .+
        source::d = \d

can be used to differentiate between .tex and .html files, where html files end
with a digit (e.g. index1.html, index2.html).  The $d$ variable will contain the
digit 1, 2 etc.

=item *

Change the way these variables appear in the output string (steps 3 and 4)

Change the destination entry.  For example:

    destination = $texfile$-new.tex html$d$.html
        destination::texfile = .*
        destination::d = \d

would result in .tex files from the previous example getting a "-new" appended
(so "foo.txt" becomes "foo-new.txt") and the .html files get renamed "html1.html",
"html2.html" and so on.  Notice that the $htmlfile$ variable has been left out,
so it disappears.

=back

=head1 METHODS

=cut

use Cwd;
use strict;
use warnings;
use Carp;

use Tarp::Style;
use File::Copy;    

our $AUTOLOAD = 1;

# Autoloaded fields
# If defaults change, change the documentation for the new() function.
my %fields = (
    style => undef,
);

=head2 new

    $burn = Tarp::Burn->new();

Creates a new Tarp::Burn object.

=cut

sub new {
    my $class = shift;
    my $self = bless {
        %fields,
        _values => []
    }, $class;
    Tarp::Style->import( "Tarp::Burn::Style" );
    $self->{style} = Tarp::Style->new();
    return $self;
}

=head2 values

    $burn->values( @list );
    @list = $burn->values();

=cut

sub values {
    my $self = shift;
    if ( @_ ) {
        return @{$self->{_values}} = @_;
    } else {
        return @{ $self->{_values} };
    }
}

=head2 bulkXform

    $brn->bulkXform( %xforms );

Renames all matching files in the current directory. Transformations come in two
flavors:

=over

=item C< CODE > Refs

The code is executed with the old variable contents as the first argument. The function
should return the new value. The current string being transformed is in C<$_>.

=item C< HASH > Refs

A hash can be supplied with a 1:1 transformation, with the key being the old
value and the value being the new value. If the old value is not found in the
hash, it is left unchanged.

=back

If no instruction is given for a variable, the original value is left unchanged.

=cut

sub bulkXform{
    my $self = shift;
    my %insts = @_;

    $self->_loadStyleAdapter();
    
    my $hlp = $self->style();
    $hlp->burnInsts( \%insts );

    my $src = $hlp->burnSource();
    my $dest = $hlp->burnDest();
    
    # Check that %inst values are either hashrefs or code refs.
    # and that the keys are among the source vars
    my %srcVars = map { $_ => 1 } $hlp->vars( $src );

    while ( my ( $var, $inst ) = each %insts ) {
        unless ( exists $srcVars{ $var } ) {
            carp "Instruction for '$var' will have no effect ('$src' has no such variable)";
        }
        unless ( ref $inst && ( ref $inst ) =~ /HASH|CODE/ ) {
            croak "Bad instruction for '$var': must be HASH or CODE ref";
        }
    }

    my @srcFiles = $self->values();
    my @destFiles;
    
    FILE: foreach my $f ( @srcFiles ) {        
        my $newName = $f;
        if ( $hlp->m( $src, $f ) ) {
            $hlp->burnString( $f );
            ( $newName ) = $hlp->xform( $f, $src => $dest );
        }
        push @destFiles, $newName;
    }

    $self->values( @destFiles );

    1;
}

=head2 bulkRename

    $burn->bulkRename( %xforms );

Like bulkXform, but uses the files in the current directory as source strings, and
renames each file using the result.

=cut

sub bulkRename {
    my $self = shift;
    my %xforms = @_;
    
    # 1. Get list of files.

    opendir( DIR, "." ) || die "can't opendir '.': $!";
    my @srcFiles = grep { -f $_ } readdir DIR;
    closedir DIR;

    $self->values( @srcFiles );
    
    $self->bulkXform( %xforms );

    my @destFiles = $self->values();
    
    my $moveCount = 0;
    while ( my $from = shift @srcFiles ) {
        my $to = shift @destFiles;
        next if $to eq $from;
        move $from, $to or croak "Could not rename '$from' to '$to': $!, stopped";
        $moveCount++;
    }
    
    print $moveCount . " file(s) renamed.\n";    
}

sub _loadStyleAdapter {
    my $self = shift;
    
    my $hlp = $self->style();
    my $src = $hlp->burnSource();
    my $dest = $hlp->burnDest();
    
    $hlp->save( "_tasTmp.tas" )
        or die "Could not save '_tasTmp.tas': " . $hlp->errStr();
    
    open PM, '>', "_burnAid.pm";
    print PM <<END_OF_PM;
package _burnAid;

my \%fields = (
    burnInsts => undef,
);

sub new {
    my \$class = shift;
    my \$self = \$class->SUPER::new();
    \@{\$self}{ keys \%fields } = values \%fields;
    bless \$self, \$class;
    return \$self;
}

sub _${src}2$dest {
    my \$self = shift;
    my \$var  = shift;
    my \$vals = shift;
    
    my \$insts = \$self->burnInsts();

    my \@nv = @\$vals;
    
    if ( my \$inst = \$insts->{ \$var } ) {
        # Instruction exists
        for ( my \$i = 0; \$i < @\$vals; \$i++ ) {
            my \$v = \$vals->[\$i];
            if ( ref \$inst eq "HASH" ) {
                \$nv[ \$i ] = \$inst->{\$v}
                    if exists \$inst->{\$v};
            } elsif ( ref \$inst eq "CODE" ) {
                \$_ = \$self->burnString();
                \$nv[ \$i ] = &\$inst( \$v );
            } else {
                die "Unknown instruction type: '" . ref \$inst . "'\n";
            }
        }
    }
    \\\@nv;
}

1;
END_OF_PM
close PM;
    push @INC, cwd();
    # could be ignored if re running this method
    Tarp::Style->import( "_burnAid" );
    unlink "_burnAid.pm";
    
    $hlp = Tarp::Style->new();
    $hlp->load( "_tasTmp.tas" )
        or die $hlp->errStr();
    unlink "_tasTmp.tas";
    
    $self->style( $hlp );

}

=head2 style

    $sty = $burn->style();
    $burn->style( $sty );

Accesses the Tarp::Burn::Style associated with this object.

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

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::Burn

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1; # End of Tarp::Burn
