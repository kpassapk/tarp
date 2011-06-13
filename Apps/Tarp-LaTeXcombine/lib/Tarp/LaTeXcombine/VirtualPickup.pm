package Tarp::LaTeXcombine::VirtualPickup;

=head1 NAME

Tarp::LaTeXcombine::VirtualPickup - A pickup with preset content

=head1 SYNOPSIS

    use Tarp::LaTeXcombine::VirtualPickup;

=head1 DESCRIPTION

Contains canned preamble buffer and an exercise buffer consisting to a reference
to a master number.  The preamble buffer looks like this:

    %TCIDATA{Version=5.50.0.2953}
    %TCIDATA{LaTeXparent=0,0,stewstyle.tex}
    
while macro reference looks like this:

    (ITEM TAG GOES HERE)
    %TCIMACRO{%
    %\hyperref{\fbox{\textbf{ms$MASTER$.tex}}}{\QSubDoc{Include ms$MASTER$}{\input{ms$MASTER$.tex}}}{}{ms$MASTER$.tex}}%
    %BeginExpansion
    \msihyperref{\fbox{\textbf{ms$MASTER$.tex}}}{%
    \input{ms$MASTER$.tex}}{}{ms$MASTER$.tex}%
    %EndExpansion

However, if there are files called canned_macro.txt and canned_preamble.txt in the directory $HOME/.techarts-toolkit
(the "resource" directory), then the content of these files is used instead.

=cut

use base qw/Tarp::LaTeXcombine::Pickup/;

use Carp;
use strict;

use Tarp::Config;
use File::Spec; # for catfile()

# Additional autoloaded fields
my %fields = (
    exerciseTemplate  => "templates/canned_macro.txt",
    preambleTemplate  => "templates/preambles/standard.txt",
);

# Subroutines for each template type that return a multiline string.
my %defaultContent = (
    exerciseTemplate => sub {
        my $tried = shift;
        my $str = '';
        open( MEM, '>', \$str );
        print MEM <<END_OF_CANNED_CONTENT;
(ITEM TAG GOES HERE)
%-------------------------------------------------------------------------------
% No canned EXERCISE TEMPLATE was found. Please check your installation.
%
% Tried to load template '$tried'
%
%-------------------------------------------------------------------------------
END_OF_CANNED_CONTENT

        close MEM;
        return $str;
    },
    preambleTemplate => sub {
        my $tried = shift;
        my $str;
        open( MEM, '>', \$str );
        print MEM <<END_OF_CANNED_CONTENT;
%-------------------------------------------------------------------------------
% No canned PREAMBLE TEMPLATE was found in the following directory.  Please
% check your installation.
%
% Tried to load template '$tried'
%
%-------------------------------------------------------------------------------
END_OF_CANNED_CONTENT

    close MEM;
    return $str;
    },
);

=head1 METHODS

=head2 new

    $vpk = Tarp::LaTeXcombine::VirtualPickup->new();

Creates a new virtual pickup.

=cut

sub new {
    my $class = shift;
    
    my $self = $class->SUPER::new( @_ );
    foreach my $element ( keys %fields ) {
        $self->{_permitted}->{$element} = $fields{$element};
    }

    @{$self}{keys %fields} = values %fields;

    bless $self, $class;
    return $self;
}

=head2 check

Reimplements check() to return an error if the pickup exercise contains an
exercise (a string that matches the itemString style entry in Tarp::Style::ITM)

=cut

sub check {
    my $self = shift;
    my $pkEx = shift;
    return $self->_error( "virtual pickup cannot have pickup exercise" )
        if $self->style()->m( "itemString" => $pkEx );
    1;
}

=head2 isVirtual

    $vpk->isVirtual();

Returns C<1>.

=cut

sub isVirtual {1}

=head2 exists

    $vpk->exists();

Returns C<1>.

=cut

sub exists { 1 }

=head2 isLeaf

    $vpk->isLeaf();

Returns C<1>.

=cut

sub isLeaf { 1 }

=head2 preambleTemplate

    $vpk->preambleTemplate();
    $vpk->preambleTemplate( "template.txt" );

Get/set preamble template file, relative to the Tarp resource directory.

=cut

# AUTOLOADED

=head2 preambleBuffer

Returns a line buffer arrayref containing preamble lines.  The preamble is defined as
the lines (if any) before the first C<beginTag> is encountered.

=cut

sub preambleBuffer {
    my $self = shift;
    
    return $self->_loadLines( "preambleTemplate" );
}

=head2 exerciseTemplate

    $file = $vpk->exerciseTemplate();
    $vpk->exerciseTemplate( $file );

Get/set exercise template file.

=cut

# AUTOLOADED

=head2 exerciseBuffer

    $buf = $vpk->exerciseBuffer();

Returns an arrayref containing a "canned" exercise buffer.

=cut

sub exerciseBuffer {
    my $self = shift;
    
    return $self->_loadLines( "exerciseTemplate" );
}

=head2 exRangeBuffer

    $buf = $vpk->exRangeBuffer();

=cut

sub exRangeBuffer {
    my $self = shift;

    return $self->exerciseBuffer();
}

sub _loadLines {
    my $self = shift;
    my $templateName = shift;
    
    my $templateFile = $self->{ $templateName };
    
    $templateFile .= "\.txt" unless $templateFile =~ /\.txt$/;
    
    my $resDir = Tarp::Config->ResourceDir();
    my $fqfile = File::Spec->catfile( $resDir, $templateFile );
    
    my @A;
    
    if ( -e $fqfile ) {
        open ( TEMPLATE, '<', $fqfile )
            or croak "Could not open $fqfile for reading: $!, stopped";
        @A = <TEMPLATE>;
    } else {
        carp "Warning: Could not find template '$fqfile'";

        my $str = &{$defaultContent{ $templateName }}( $fqfile );

        @A = split qr/\n/, $str;
        @A = map { $_ . "\n" } @A; # Reintroduce the newlines
        push @A, "\n"; # Add one extra newline at the end
    }
    return \@A;
}

1;
