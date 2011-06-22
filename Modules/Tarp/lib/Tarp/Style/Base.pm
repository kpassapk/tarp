package Tarp::Style::Base;

=head1 NAME

Tarp::Style::Base - Implements basic Tarp::Style methods

=head1 SYNOPSIS

This module is always used through Tarp::Style.

See L<Tarp::Style> for more information.

=cut

use strict;
use warnings;

use Carp;
use Data::Dump qw/dump/;
use Storable qw/dclone/;

use Tarp::TAS;
use Tarp::TAS::Spec;

our $AUTOLOAD;
my %fields = (
    file      => undef,
    mEntry    => '',
    mIdx      => '',
    mParens   => undef,
    mPos      => undef,
    mVars     => undef,
    impXforms => '',
);

my $Debugging = 0;

=head1 ENUMS

=over

=item INLINE

Interpolate variables straight into the string

=item PARENS

Interpolate variables using parenthesis capture buffers

=item NCBUFS

Interpolate using named capture buffers

=back

=cut

sub INLINE { 1 }
sub PARENS { 2 }
sub NCBUFS { 3 }

=head1 METHODS

=head2 new

    Tarp::Style->import();
    $h = Tarp::Style->new();

As default Tarp::Style import implements the following Tarp::Style methods.
See Tarp::Style for documentation.

=over

=item emptyFileContents

=item load

=item loadString

=item save

=item saveString

=item vars

=item varsIn

=item entries

=item exists

=item values

=item interpolate

=item interpolateVars

=item stripVars

=item m

=item qr

=item match

=item xform

=item xformVars

=item filterVars

=item errStr

=item defaultTASfile

=back

=cut

sub new {
    my $class = shift;
    my $self = bless {
        %fields,
        _TAS                => undef,
    }, $class;
    $self->{_errStr} = '';
    $self->{_rxError} = '';
    $self->{_qrs} = {};
    bless $self, $class;
    return $self;
}

=head1 Methods To Reimplement

The following defaults are implemented for the following methods which you will
probably want to reimplement your own style class:

=head2 emptyFileContents

Returns a single newline.

=cut

sub emptyFileContents { "\n" }

sub load {
    my $self    = shift;
    confess "check usage" unless ref $self;
    my $TASfile = shift || $self->{file} || $self->defaultTASfile()
            or return $self->_error( 'TAS file not specified and ' . $self->errStr() );

    carp "Loading style from $TASfile\n" if Tarp::Style::Base->debug;

    return $self->_error( "File '$TASfile' does not exist" )              unless -e $TASfile;
    return $self->_error( "'$TASfile' is a directory, not a file" )       unless -f _;
    return $self->_error( "Insufficient permissions to read '$TASfile'" ) unless -r _;

    # Slurp in the file
    local $/ = undef;
#    local *TAS;
    open( TAS, $TASfile )
        or return $self->_error( "Failed to open file '$TASfile': $!" );
    my $contents = <TAS>;
    close TAS or return $self->_error( "Failed to close file '$TASfile': $!" );
    
    $self->loadString( $contents, $TASfile ) or return;
    
    $self->{file} = $TASfile;
    carp "Loaded " . ( 0 + keys %{$self->{_TAS}} ) . " entries"
        if Tarp::Style::Base->debug;
    1;
}

sub loadString {
    my $self = shift;
    my $string = shift;
    my $TASfile = shift;
    $TASfile = $TASfile ? "'" . $TASfile . "'" : "string";

    confess "check arguments" unless defined $string;
    
    # stream must end in a newline becuase I am concatenating the
    # input strings in plugins
    return $self->_error( "$TASfile does not end with a newline" )
        unless $string =~ /\n$/;

    my $contents = $self->preRead( $string );
    my $tas = Tarp::TAS->readString( $contents )
        or return $self->_error( Tarp::TAS->errStr() );
    
    $self->_loadVars( [ $tas ] );

    $self->postRead( $tas );
    
    if ( Tarp::TAS::Spec->check( $tas, $self->constraints( $tas ) ) ) {
        $self->{_TAS} = $tas;
        $self->{_qrs} = {};
        return 1;
    } else {
        $self->_error( "$TASfile is not up to spec.\n\n" . Tarp::TAS::Spec->errStr()
                             . $self->{_rxError} );
        return '';
    }
}

sub saveString {
    my $self = shift;
    
    my $tas = dclone $self->{_TAS};
    $self->preWrite( $tas );
    my $str = $tas->writeString();
    # add extra newline b/c loadString requries it
    return $self->postWrite( $str ) . "\n";
}

sub save {
    my $self    = shift;
    my $outFile = shift;
  
    open ( OUT, '>', $outFile )
        or croak "Could not open '$outFile' for writing: $!, stopped";    
    print OUT $self->saveString();
    close OUT or croak "Error while closing '$outFile' handle: $!, stopped";
}

sub _loadVars {
    my $self = shift;
    my $rec = shift;

    my %uv = ();
    my $sub = $rec->[-1];
    foreach ( keys %$sub ) {
        next if /^_/;
        $self->_loadVars( $sub->{$_} );
        my @subVars = @{$sub->{$_}->[-1]->{_VARS}};
        @uv{ @subVars } = map { 1 } @subVars;
    }
    
    for ( my $iv = 0; $iv < @$rec - 1; $iv++ ) {
        my @vars = $self->varsIn( $rec->[ $iv ] );
        @uv{ @vars } = map { 1 } @vars;
    }
    $sub->{_VARS} = [ keys %uv ];
}

sub vars {
    my $self = shift;
    my $entry = shift;
    my $index = shift;
    
    return @{$self->{_TAS}->{_VARS}} if ! defined $entry; # form 1
    my $values = $self->{_TAS}->values( $entry );
    if ( defined $index ) { # form 3
        return $self->_error( "index $index out of range" )
            unless defined $values->[ $index ];
        return $self->{_TAS}->varsIn( $values->[ $index ] );
    } else {
        return @{$values->[-1]->{_VARS}}; # form 2
    }
}

sub varsIn {
    shift;
    return Tarp::TAS->varsIn( @_ );
}

sub entries {
    my $self = shift;

    return $self->{_TAS}->entries( @_ )
        or $self->_error( $self->{_TAS}->errStr() );
}

sub exists {
    my $self = shift;
    return $self->{_TAS}->values( @_ ) ? 1 : '';
}

sub values {
    my $self   = shift;
    my $entry  = shift;
    my @vals   = @_;
    
    my $tas = $self->{_TAS};
    # $_ = $entry;
    
    my $vs;
    eval { $vs = $tas->values( $entry ) };
    if( $@ ) {
        $@ =~ s/ at .*//;
        chomp $@;
        croak $@;
    }
    
    if ( @vals ) {
        # Storing new values.  Must process variables.

        my %ev;
        for ( @vals ) {
            my @vs = $self->varsIn( $_ );
            @ev{ @vs } = map { [ ".+", {} ] } @vs;
        }

        my ( $p, $e ) = $entry =~ /(.*)::(\w+)/ ? ( $1, $2 ) : ( '', $entry );
        # warn "*** $entry: $p $e";
        if ( ! $vs ) {
            # does not exist.  add only if last good path is the parent of the
            # entry we are setting
            
            if ( $p ) {
                $vs = $tas->values( $p );
                croak "'$p' does not exist, stopped" unless $vs;
                
                $vs = $vs->[-1]->{$e} = [ @vals, \%ev ];
            } else {
                # root entry.
                $vs = $tas->{$e} = [ @vals, \%ev ];
            }
        } else {
            # leave existing variables, but add a .+ if a variable
            # was missing.  This may create sub entries that are not
            # referenced by $ sign variables in the parent expression,
            # but oh well.
            @ev{ keys %{$vs->[-1]} } = values %{$vs->[-1]};
            # replacing existing values.
            @$vs = ( @vals, \%ev );
        }
        
        # chop end off path, removing saved _qrs for each portion (if any)
        $p = $entry;
        while ( $p ) {
            delete $self->{_qrs}->{$p};
            $p =~ s/(?:::)?(\w)+$//;
        }

        $self->_loadVars( [ $tas ] );
    } else {
        if ( ! $vs ) {
            my $a = ();
            return $a;
        }
    }

    my @v = @$vs;
    pop @v;
    
    @v;
}

sub interpolate {
    my $self = shift;
    my $e    = shift;
    my $ierp = shift || NCBUFS ();

    my $_TAS = $self->{_TAS};
    my %act = (
        INLINE () => sub { $_TAS->interpolate( $e ) },
        PARENS () => sub { $_TAS->interpolate( $e, "(%s)", '$VAL$' ) },
        NCBUFS () => sub { $_TAS->interpolate( $e, "(?<%s>%s)", '$VAR$', '$VAL$' );},
    );
    my $code = ( $act{ $ierp } );
    my $a = &$code; # Get the values
    croak( Tarp::TAS->errStr() . ", stopped" ) unless $a;
    return @$a;
}

sub interpolateVars {
    my $self = shift;
    my @v = @_;
    
    confess "check usage"
        unless @v && ref $v[-1] eq "HASH";
    
    my %vars = %{pop @v}; # create a copy
    while ( my ( $v, $l ) = each %vars ) {
        confess "check usage" unless ref $l eq "ARRAY";
        push @$l, {}; # conform to TAS data structure
    }
    
    my $vs = Tarp::TAS->interpolateValues( [ @v, \%vars ] )
        or die Tarp::TAS->errStr();

    @$vs;
}

sub stripVars {
    my $class = ref $_[0] ? ref shift : shift;
    confess "$class->stripVars() not implemented yet";
}

sub m {
    my $self = shift;
    my $entry = shift;
    my $str = defined $_[0] ? shift : $_;
    
    return '' unless defined $str;
    
    my @qr = $self->qr( $entry );
    for ( my $i = 0; $i < @qr; $i++ ) {
        if ( $str =~ $qr[$i] ) {
            $self->mEntry( $entry );
            my %mv = %-;
            my @mr = ();
            for ( my $j = 0; $j < @-; $j++ ) {
                next if ! defined $-[ $j ];
                $mr[ $j ] = substr( $str, $-[$j], $+[$j] - $-[$j] );
            }
            my %mp;
            my @ev = $self->vars( $entry, $i );
            # make mPos like %-, but using offsets in @-
            for ( my $j = 0; $j < @ev; $j++ ) {
                if ( $mp{ $ev[$j] } ) {
                    push @{ $mp{ $ev[$j] } }, $-[$j+1];
                } else {
                    $mp{ $ev[$j] } = [ $-[$j+1] ];
                }
            }
            @{$self}{qw/mIdx mParens mVars mPos/} = ( $i, \@mr, \%mv, \%mp );
            return 1;
        }
    }
    '';
}

sub qr {
    my $self = shift;
    my $entry = shift;

    # Return cached value if we have it
    if ( my $saved = $self->{_qrs}->{$entry} ) {
        return @$saved;
    }
    
    # Otherwise construct the qr and save it

    my @qrs = @{ $self->_get_qr( $entry ) };

    # Top level entries can have EXACT and CSENS
    
    my $vr = $self->{_TAS}->values( $entry )->[-1];
    if ( $vr->{EXACT} && $vr->{EXACT}->[0] ) {
        @qrs = map { '^' . $_ . '$' } @qrs;
    }
    if ( ! $vr->{CSENS} || $vr->{CSENS}->[0] ) {
        @qrs = map { "(?-xism:$_)" } @qrs;
    } else {
        @qrs = map { "(?i-xsm:$_)" } @qrs;
    }
    
    # Finally construct the regexp    
    @qrs = map { qr/$_/ } @qrs;
    $self->{_qrs}->{$entry} = \@qrs;
    @qrs;
}

sub _get_qr {
    my $self  = shift;
    my $entry = shift;
    my $path  = shift || '';
    
    my $fqe = "$path$entry";
    
    # Interpolate variables using the WORD, EXACT and CSENS sub values,
    # and return interpolated string in regexp format.

    my @vals = @{ $self->{_TAS}->values( $fqe ) };
    my @vars = keys %{ $vals[-1] };
    pop @vals;
    
    # Remove double quotes
    for ( @vals ) {
        s/^"(.*)"$/$1/;
    }

    # Sub in variables recursively

    my %qrvars;    
    foreach my $v( @vars ) {
        next if $v =~ /^_/ || $v eq 'WORD' || $v eq 'CSENS';
        my $qrs = $self->_get_qr( $v, "$fqe\::" );
        push @$qrs, {};
        $qrvars{$v} = $qrs;
    }
    
    # Replace values with interpolated values
    @vals = @{ $self->{_TAS}->interpolateValues( [ @vals, \%qrvars ] ) };
    
    if ( $path ) {
        # For non top level entries, use CSENS and WORD to modify the regex
        # and set named capture buffers
        # ::WORD  - bracket in \b
        # ::CSENS - (?i-xsm) flag

        my $vr = $self->{_TAS}->values( $fqe )->[-1];
        if ( $vr->{WORD} && $vr->{WORD}->[0] ) {
            @vals = map { '\b' . $_ . '\b' } @vals;
        }
        if ( ! $vr->{CSENS} || $vr->{CSENS}->[0] ) {
            @vals = map { "(?-xism:(?<$entry>$_))" } @vals;
        } else {
            @vals = map { "(?i-xsm:(?<$entry>$_))" } @vals;
        }
        return \@vals;

    } else {
        # Top level entry
        return \@vals;
    }
}

sub xform {
    my $self = shift;
    my $str = shift;
    my $src = shift;
    my $dest = shift;
    
    my $srcx = $self->{_TAS}->values( $src . "::EXACT" );
    my $destx = $self->{_TAS}->values( $dest . "::EXACT" );
    
    # source and destination entries need to be EXACT...
    # this method doesn't make much sense otherwise.
    if ( ! $srcx || ! $srcx->[0] ) {
        carp "Warning: '$str' xform requires '$src\::EXACT' (resetting)";
        $self->values( $src . '::EXACT', 1 );
    }    
    if ( ! $destx || ! $destx->[0] ) {
        carp "Warning: '$str' xform requires '$dest\::EXACT' (resetting)";
        $self->values( $dest . '::EXACT', 1 );
    }

    my $newStr;    # transformed string
    my $newVars;   # transformed variables
    if ( $self->m( $src, $str ) ) {
        my $mIdx = $self->mIdx();   # index that matched
        my $mVars = $self->mVars(); # the variables extracted
        $newVars = $self->xformVars( $mVars, $src, $dest );
        my @destVals = $self->values( $dest );
        # Get format string - value w/ same index or first if n/a
        # Then turn it printable by removing
        # all backslashes that are not followed by another backslash.
        if ( @destVals > 1 ) {
            return $self->_error( "'$dest' value $mIdx out of range" )
                unless defined $destVals[ $mIdx ];
        } else {
            $mIdx = 0;
        }
        my $fmatStr = $destVals[ $mIdx ];
        $fmatStr =~ s/\\([^\\])/$1/g;
        
        # Interpolate new variables into format string
        ( $newStr ) = $self->interpolateVars( $fmatStr, $newVars );
        
        # Verify: matches destination entry with the same index?
        my @qrs = $self->qr( $dest );
        if ( ! $newStr =~ $qrs[ $mIdx ] ) {
            return $self->_error( "'$newStr' does not match destination spec '$qrs[$mIdx]'" );
        }
    } else {
        return $self->_error( "'$str' does not match '$src' entry" );
    }
    return ( $newStr, $newVars );
}

BEGIN {
    my %xfPreload = ();
    
sub xformVars {
    my $self = shift;
    my $vars = shift;
    my $from = shift;
    my $to   = shift;

    confess "check usage" unless ref $vars eq "HASH";
    
    my @path;
    if ( $xfPreload{"${from}2$to"} ) {
        @path = @{$xfPreload{"${from}2$to"}};
    } else {
        croak "Entry '$from' does not exist or is sub entry, stopped"
            unless $self->{_TAS}->{$from};
        croak "Entry '$to' does not exist or is sub entry, stopped"
            unless $self->{_TAS}->{$to};
        
        my @poss = ( $to );
        foreach ( $self->{_TAS}->entries( 0 ) ) {
            next if $_ eq $from || $_ eq $to;
            push @poss, $_;
        }
        
        # Find path betweeen 'from' and 'to', providing 'foo2bar' methods
        @path = ( $from );
        SRCH: while ( 1 ) {
            POSS: for ( @poss ) {
                for my $p ( @path ) {
                    next POSS if $_ eq $p; # Avoid repeating
                }
                my $m = "_$path[-1]2$_";
                if ( $self->can( $m ) ) {
                    push @path, $_;
                    last SRCH if $_ eq $to;
                    next SRCH;
                }
            }
            
            if ( @path > 3 ) {
                croak "Maximum path length exceeded while searching for '$from' to " ,
                      "'$to' conversion, stopped";
            }
            if ( @path == 1 ) {
                croak "Could not find path from '$from' to '$to', stopped"
                    unless $self->{impXforms};
                # Do an implicit conversion:
                # Filter out variables and return as-is.
                my $cVars = $self->filterVars( $vars, $from, $to );
                my $dbg_imp0 = dump $cVars; # Stringify to remember
                foreach my $v ( keys %$cVars ) {
                    my $vDef = $self->{_TAS}->{$to}->[-1]->{$v}; 
                    if ( @$vDef == 2 && $vDef->[0] eq '\d+' ) {
                        for ( my $i = 0; $i < @{$cVars->{$v}}; $i++ ) {
                            $cVars->{$v}->[$i] = eval "0 + $cVars->{$v}->[$i]";
                        }
                    }
                    # TODO:
                    # If source is [a-z ]+ and target is [A-Z ]+, tr// it uppercase?
                }
                warn "Implicit xform: " . $dbg_imp0 . " to " . dump( $cVars )
                    if Tarp::Style::Base->debug > 1;
                return $cVars;
            }
            pop @path;
        }
        $xfPreload{"${from}2$to"} = \@path;
    }
    # Navigate path from start to finish, transforming variables at each step
    my %xv = %$vars;
    for ( my $i = 0; $i < @path - 1; $i++ ) {
        my $str = "_$path[$i]2$path[$i+1]";         # foo2bar
        foreach my $var ( keys %xv ) {
            my $list = $xv{$var};
            my $nv = $self->$str( $var, $list );
            if ( defined $nv ) {
                croak "$str( $var, $list ) should return ARRAY ref, stopped"
                    unless ref $nv eq "ARRAY";
                $xv{ $var } = $nv;
            } else {
                delete $xv{$var};
            }
        }
    }
    return \%xv;
}

} # BEGIN

sub filterVars {
    my $self = shift;
    my $vars = shift;
    my $from = shift;
    my $to = shift;

    my %srcVars  = map { $_ => 1 } @{$self->{_TAS}->{$from}->[-1]->{_VARS}};
    my %destVars = map { $_ => 1 } @{$self->{_TAS}->{$to}->[-1]->{_VARS}};
    my %cVars = ();
    foreach my $v ( keys %$vars ) {
        croak "'$from' entry does not contain \$$v\$, stopped"
            unless $srcVars{$v};
        $cVars{$v} = $vars->{$v} if $destVars{$v};
    }
    return \%cVars;
    
}

# errStr is unchanged if called w/o argument
sub _error {
    my $self = shift;
    $self->{_errStr} = shift if @_;
    '';
}

sub errStr {
    my $self = shift;
    return $self->{_errStr};
}

=head2 constraints

    %cs = $sty->constraints( $tas );

Assigns constraints for every entry in $tas that checks regular expression
syntax.

=cut

sub constraints {
    my $self = shift;
    my $tas  = shift;
    
    confess "object method called as class method" unless ref $self;
    confess "check usage" unless ref $tas eq "Tarp::TAS";
    
    # All entries are Regexps
    my @getRx = ( sub {
        my $vals = shift;
        my $sty = shift;
        my $tag = shift;
        
        my @errs = ();
        for ( @$vals ) {
            eval "qr/$_/";
            if ( $@ ) {
                push @errs, "Regexp Error";
                my $perlHint = $@;
                $perlHint =~ s/\sat\s.*?$//;
                $sty->{_rxError} = "\nPerl didn't like a regular expression in '$tag'.\nhint:\n" . $perlHint;
            }
        }

        return @errs;
    }, $self );

    $self->{_rxError} = '';
    
    my %rxChecks;
    foreach ( $tas->entries() ) {
        s/_\d+_$//;
        if ( ! exists $rxChecks{$_} ) {
            $rxChecks{$_} = [ @getRx, $_ ];
        }
    }
    return %rxChecks;
};

=head2 preRead, postRead, preWrite, postWrite

    $sty->preRead( $str )
    $sty->postRead( $tas );
    $sty->preWrite( $tas );
    $sty->postWrite( $str );

Return $tas and $str unchanged.

=cut

sub preRead { $_[1] }

sub postRead { 1 }

sub preWrite { 1 }

sub postWrite { $_[1] }

sub defaultTASfile {
    my $self = shift;
    my @defaultTAS = ( qw/TASfile TASfile.tas TASfile.txt/ );
    my @ok = grep { -e $_ } @defaultTAS;
    # TAS file not specified and  ...
    return $self->_error( "no suitable default could be found" ) unless @ok;
    return $self->_error( "cannot decide between defaults: @ok" ) if @ok > 1;
    return $ok[0];
}

=head2 debug

    Tarp::Style::Base->debug( 1 );

=cut

sub debug {
    my $class = shift;
    if (ref $class)  { confess "Class method called as object method" }
    if ( @_ ) {
        $Debugging = shift;
    }
    $Debugging;
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

    perldoc Tarp::Style

=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.

=cut

1; # End of Tarp::Style