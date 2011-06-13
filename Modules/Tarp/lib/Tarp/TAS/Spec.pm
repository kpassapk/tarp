package Tarp::TAS::Spec;

=head1 NAME

Tarp::TAS::Spec - check TAS against a specification

=head1 SYNOPSIS

    use Tarp::TAS;
    use Tarp::TAS::Spec;
    
    my $tas = Tarp::TAS->read( "bar.tas" );
    
    # Check entries "foo", "bar", "bat", and "alf" for correctness:
    
    Tarp::TAS::Spec->check( $tas,
        foo => Tarp::TAS::Spec->simple(
            allowEmpty    => 1,
            allowMultiple => '',
            requireVars   => [ qw/b/ ] ), # for all values

        # "bar" should have three values
        bar => [
            sub {
                my $v = shift;
                my $n = shift; # gets "3"
                @$v != $n ? ( "entry must have $n values" ) : ();
            }, 3 ],
            
        # Another subroutine: notice values are @_, not $_[0]!
        bat => sub {
            @_ && $_[0] =~ /bla/ ? () :
            ( "First value must contain 'bla'" )
        },
        
        # Make sure alien life forms exist
        alf => Tarp::Tas::Spec->exists()
    
    ) or die "bar.tas is not up to spec:\n" .
        Tarp::TAS::Spec->errStr() . "\n";

=head1 DESCRIPTION

This module provides a check() function which is used to check a TAS data
structure for correctness by passing it through a constraints hash. The
constraints hash contains a check function for each TAS entry, which determines
whether its values are "correct" or not. A check function may allow or disallow
entries altogether, or require the values to have variables.

Checks are user defined functions. For convenience, though, a simple() check is
bundled with this module. Checks may be combined by using the multi(), method.
If you just want to check if an entry exists, use exists().

If the tas data structure is not up to spec, the errStr>() class method can be used
to get a (long) entry by entry description of what the problem was.

=head2 Check Functions

There are two ways to specify a check function:

=over

=item CODE check

A subroutine that returns a list of errors (or empty list for no errors).
See the "bat" entry above for an example.

=item ARRAY check

An array where the first element is a code ref to a check function, and the
remaining elements are passed as arguments to the check function at runtime.
See the "bar" entry above for an example.

=back

=cut

use strict;
use Carp;

use Tarp::TAS;

my $errStr = '';
my @errors = ();

=head1 METHODS

=head2 check

    $ok = Tarp::TAS::Spec->check( $tas, %constraints );

Returns true if $tas meets the %constraints (see above), false otherwise.
If a constraint is given for a non existent entry, the constraint is not applied
and an error reporting the missing entry is added to the error string.  For
efficiency, if all you want to do is check for existence, use the exists()
method.

Variables C<$VAR$> are interpolated as C< (?<$VAR$>) > before checking, in order
to preserve the variable name but ensure correctness as a regular expression.
Since the sub values are not included, if you need to check the contents of the
entire (interpolated) entry, you need to use an C< ARRAY > check. Suppose you had an
entry

    my_entry = foo$b$
        my_entry::b = bar

and you want to ensure my_entry is "foobar":

    sub entryCheck {
        shift;          # ignore these...
        my $v = shift;  # and use these instead

        if ( $v->[0] eq "foobar" ) {
            return ();
        } else {
            return "not 'foobar'";
        }
    }
    
    $ok = Tarp::TAS::Spec->check(
        $tas,
        my_entry => [ \&filenameMatches, $tas->interpolate( "filename" ) ],
    );
);


=cut

sub check {
    my $class = shift;
    my $tas = shift;
    confess "check usage" if ! $tas || ref $tas ne "Tarp::TAS" || @_ % 2;
    my %constraints = @_;
    @errors = ();
    my $aok = 1;
    
    # "reverse" makes them show up alphabetically, because errStr
    # reverses the order of the error string. 
    foreach my $e ( reverse sort keys %constraints ) {
        my $c = $constraints{$e};
        
        my $vals = $tas->interpolate( $e, "(?<%s>)", '$VAR$' );
        if ( $vals ) {
            my @errs = $class->checkValues( $vals, $c );
            foreach ( @errs ) {
                $class->_entry_error( $e, $_ );
            }
            $aok &&= ! @errs;
        } else {
            # Check if we have subscripts.
            my $ilev = 0;
            while ( $vals = $tas->interpolate( $e . "_$ilev\_", "(?<%s>)", '$VAR$' ) ) {
                my @errs = $class->checkValues( $vals, $c );
                foreach ( @errs ) {
                    $class->_entry_error( $e . "[$ilev\]", $_ );
#                    $class->_error( '| ' . sprintf( "%-18s", $e . "[$ilev\]" ) . "| $_" );
                }
                $aok &&= ! @errs;
                $ilev++;
            }
            if ( ! $ilev ) {
#                if ( Tarp::TAS->errStr() =~ qr/does not exist/ ) {
                    $aok = $class->_entry_error( $e, "Not found" );
#                    $aok = $class->_error( '| ' . sprintf( "%-18s", $e ) . "| Not found" )                
#                } else {
#                    use Data::Dumper;
#                    warn Dumper $tas->{$e};
#                    croak( "Entry $e", Tarp::TAS->errStr() );
#                }
            }
        }
    }
    return $aok;
}

=head2 checkValues

    Tarp::TAS::Spec->checkValues( [ qw/a b c/], sub { ... } );
    Tarp::TAS::Spec->checkValues( [ qw/a b c/], [ sub { ... }, ... ] );

Checks the values using using the constraint (C<ARRAY> or C<CODE> ref), returning a
list of errors or an empty list if the values meet the spec.

=cut

sub checkValues {
    my $class = shift;
    my $vals = shift;
    my $constraints = shift;

    my $f = "_check" . ref $constraints;
    $class->$f( $vals, $constraints );
}

=head2 exists

    $array = Tarp::TAS::Spec->exists();

Returns an C<ARRAY> check that always returns true. Use this to return a null
check that does not actually check anything, but when given to check() can be
used to print an error if an entry does not exist.

=cut

sub exists {
    return [ sub {()} ];
}

=head2 simple

    $array = Tarp::TAS::Spec->simple( %flags );

Returns an array check using the following flags:

=over

=item allowEmpty

Allow or disallow empty entries. Default is true (C<1>).

=item allowMultiple

Allow or disallow multiple entries.  Default is true (C<1>).

=item requireVars

Require variables (use with C< allowEmpty =E<gt> 0 >). You can give a
I<true/false> value to require an entry to have at least one variable or an
array reference with some variable names to require specific variables. Default
is false (C<0>).

Examples:

    requireVars => 1         # any variable
    requireVars => [ "foo" ] # a variable called $foo$

=back

=cut

sub simple {
    my $class = shift;
    my %opts = @_;
    
    my %defaults = (
        allowEmpty    => 1,
        allowMultiple => 1,
        requireVars   => '',
    );

    my %c = %defaults;
    for ( keys %opts ) {
        if ( exists $defaults{ $_ } ) {
            $c{ $_ } = $opts{$_};
        } else {
            carp "Warning: unknown constraint '$_'";
        }
    }

    if ( $c{allowEmpty} && $c{requireVars} ) {
        carp "Warning: check constraints: 'requireVars' cannot be used with 'allowEmpty', ";
        $c{allowEmpty} = 0;
    }
    
    my $check = sub {
        my $values = shift;
        my $allowEmpty = shift;
        my $allowMultiple = shift;
        my $requireVars = shift;
        
        my @errs = ();
        
        push @errs, "Empty list not allowed"
        if ( ! @$values && ! $allowEmpty );
    
        push @errs, "Multiple values not allowed"
            if ( @$values > 1 ) && ! $allowMultiple;
    
        if ( ref $requireVars eq "ARRAY" && @$requireVars ) {
            for ( my $i = 0; $i < @$values; $i++ ) {
                my $v = $values->[$i];
#                my %vars = map { $_ => 1 } Tarp::TAS->varsIn( $v );
                my %vars;
                while ( $v =~ /\(?<(\w+)>/g ) {
                    $vars{$1} = 1;
                }
                foreach my $rq ( @$requireVars ) {
                    push @errs, "Your value '$v' should contain '\$$rq\$'"
                        unless $vars{$rq}; 
                }
            }
        } elsif ( $requireVars ) {
            for ( my $i = 0; $i < @$values; $i++ ) {
                my %vars;
                while ( $values->[$i] =~ /\(?<(\w+)>/g ) {
                    $vars{$1} = 1;
                }
                push @errs, "'$values->[$i]' should contain variables"
                    unless keys %vars;
            }
        }
        return @errs;
    };
    
    return [ $check, @c{qw/allowEmpty allowMultiple requireVars/} ];
}

=head2 multi

    Tarp::TAS::Spec->check(
        foo => Tarp::TAS::Spec->multi(
            Tarp::TAS::Spec->simple( allowEmpty => 0 ),
            Tarp::TAS::Spec->simple( allowMultiple => 0 ),
        )
    );

Combines more than one check in an "AND" relationship.  At present, arguments
to this method must be ARRAY ref checks (see above)

=cut

sub multi {
    my $class = shift;
    my @checks = @_;
    foreach ( @checks ) { croak "This method takes a list of ARRAY refs" unless ref $_ eq "ARRAY" }
    
    my $multi = sub {
        my $values = shift;
        my @ch = @_;
        my @allErrs = ();
        foreach ( @checks ) {
            push @allErrs, $class->_checkARRAY( $values, $_ );
        }
        return @allErrs;
    };
    return [ $multi, @checks ];
}

sub _checkCODE {
    my $self = shift;
    my $values = shift;
    my $cs = shift;

    my @errs = ( $cs->( @$values ) );
    @errs;
}

sub _checkARRAY {
    my $self = shift;
    my $values = shift;
    my @cs = @{shift()};

    my @errs = ();
    my $code = shift @cs;
    if ( ref $code eq "CODE" ) {
        @errs = ( $code->( $values, @cs ) );
    } else {
        carp "Check constraint: first element must be code ref, '";
    }
    @errs;
}

=head2 errStr

    $sty->errStr();

Returns a pretty error message with "entry" and "error" columns, and all the 
errors encountered in the last call to check(), or the empty string of there
are no errors.

=cut

sub errStr {
    return '' unless @errors;
    push @errors, "-------------------- ----------------------------------------";
    push @errors, "|      entry        |                error                  |";
    push @errors, "-------------------- ----------------------------------------";
    return join "\n", reverse @errors;
}

sub _entry_error {
    my $class = shift;
    my $tag = shift;
    my $error = shift;

    return $class->_error( '| ' . sprintf( "%-18s", $tag ) . "| " . $error );
}

sub _error {
    my $err = $_[1];
    push @errors, $err;
    '';
}

1;
