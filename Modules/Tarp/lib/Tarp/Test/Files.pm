package Tarp::Test::Files;
use strict;

=head1 NAME

Tarp::Test::Files - Test out/ and out-expected/ files and clean up

=head1 SYNOPSIS

    use Tarp::Test::Files;

    my $x = Foo->new(); # class I am testing

    # Either...
    chdir "c01";
    $x->doSomething();
    $x->writeIt( "out/out.txt" );
    Tarp::Test::Files->asExpected( "out.txt" );
    chdir "../c02";
    ...
    
    # or...
    sub runTest {
        my $x = shift;
        $x->doSomething();
        $x->writeIt( "out/out.txt" );
    }

    my $t = Tarp::Test::Files->new();
    $t->generator( [ \&runTest, $x ] );
    $t->case( "simple" ); # c01

=head1 DESCRIPTION

These tests compare an output file against an expected output file by using a
"diff". 

=cut

use Carp;
use File::Spec;
use Test::More;
use Test::Differences;

=head1  METHODS

=head2 new

=cut

sub new {
    my $class = shift;
    my $self = bless {
        _cidx => 1,
        _generator => undef,
    }, $class;
    return $self;
}

=head2 generator

Callback method that generates test output.

=cut

sub generator {
    my $self = shift;
    confess "check usage: generator must be array ref" unless ref $_[0] eq "ARRAY";
    if ( @_ ) {
        return $self->{_generator} = shift;
    } else {
        return $self->{_generator};
    }
}

=head2 case

    $t->case();
    $t->case( "description" );

Runs the next test case.  Output is printed as "c01: description" (where 'c01'
is the next test case number) or "c01 output" if no description is given.

=cut

sub case {
    my $self = shift;
    
    my $c = "c" . sprintf "%02d", $self->{_cidx}++;
    my $desc = $_[0] ? $c . ": " . shift : "$c output";

    chdir $c or croak "Could not chdir to '$c': $!, stopped";
    croak "Test generator not specified, stopped" unless $self->{_generator};
    my ( $gen, @args ) = @{$self->{_generator}};
    &$gen( @args );

    my @files = <out-expected/*>;
    croak "No 'out-expected' files for $c, stopped" unless @files; 
    foreach ( @files ) {
        my ( undef, undef, $f ) = File::Spec->splitpath( $_ );
        Tarp::Test::Files->asExpected( $f, $desc );
    }

    chdir "..";
}

=head2 asExpected

    Tarp::Test::Files->asExpected( "dataout.txt" );
    Tarp::Test::Files->asExpected( "dataout.txt", "test description" );

Tests F<out/dataout.txt> and F<out-expected/dataout.txt> by performing a "diff".
If the line length is greater than about 40 characters, Text::Diff is used with
its normal output. Otherwise, Test::Differences is used because it has a nice
and compact column view.  If the description is omitted, "dataout.txt is as
expected" is used.

Line endings are converted to Unix (C<LF>) for compatiability before comparing.

=cut

sub asExpected {
    my $class = shift;
    my $filename = shift;
    my $message = defined $_[0] ? shift : "$filename is as expected";
    
    open( GOT, "<out/$filename" )
        or croak "Could not open out/$filename for reading: $!, stopped";
    open( EXP, "<out-expected/$filename" )
        or croak "Could not open out-expected/$filename for reading: $!, stopped";
    
    local $/;
    undef $/;
    
    my $got = <GOT>;
    my $exp = <EXP>;

    close EXP;
    close GOT;
    
    $got =~ s/\r\n/\n/g;
    $exp =~ s/\r\n/\n/g;
    
    # Count the number of characers between the newlines; if the lines are very
    # long then use Text::Diff, otherwise use Test::Differences.
    
    my $lngot = _maxLineLength( $got );
    my $lnexp = _maxLineLength( $exp );
    
    my $maxLength = $lngot > $lnexp ? $lngot : $lnexp;
    my $pass= 0;
    
    if ( $maxLength > 38 ) {
        eval 'use Text::Diff';
        
        my $differences = diff( \$got, \$exp );
        $pass = ok( ! length $differences, $message ) or diag $differences;
    } else {
        $pass = eq_or_diff( $got, $exp, $message );
    }
    if ( $pass ) {
        unlink "out/$filename" or warn "Could not remove out/$filename: $!";
    }
}

sub _maxLineLength {
    my $str = shift;
    my $len = -1;
    
    while ( $str =~ /(?:^|\n)(.*?)(?:$|\n)/g ) {
        $len = length $1 if ( length $1 > $len );
    }
    return $len;
}

1;
