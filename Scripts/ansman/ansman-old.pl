#!/usr/bin/perl -w

use strict;

use Tarp::Itexam;

# Use ansman.tas by default, or set a different .tas file
# for file names mathing these patterns...
my %tas_select = (
    qr/pp\.tex/i    => "ansman-pp.tas",
);

sub pre_lines {
    <<PREAMBLE_CONTENTS;

%TCIMACRO{\\TeXButton{setRM}{\\renewcommand{\\RM}{1}}}%
%BeginExpansion
\\renewcommand{\\RM}{1}%
%EndExpansion
%TCIMACRO{\\TeXButton{set page2}{\\setcounter{page}{2}}}%
%BeginExpansion
\\setcounter{page}{2}%
%EndExpansion
%TCIMACRO{%
%\\TeXButton{s2col}{\\setlength{\\columnsep}{24pt}
%\\advance \\leftskip by -165pt
%\\advance\\hsize by 165pt
%\\advance\\linewidth by 165pt
%\\begin{multicols}{2}}}%
%BeginExpansion
\\setlength{\\columnsep}{24pt}
\\advance \\leftskip by -165pt
\\advance\\hsize by 165pt
\\advance\\linewidth by 165pt
\\begin{multicols}{2}%
%EndExpansion

PREAMBLE_CONTENTS

}

sub post_lines {
    <<END_OF_POST;

%TCIMACRO{%
%\\TeXButton{e2col}{\\end{multicols}
%\\advance \\leftskip by 165pt
%\\advance\\hsize by -165pt
%\\advance\\linewidth by -165pt}}%
%BeginExpansion
\\end{multicols}
\\advance \\leftskip by 165pt
\\advance\\hsize by -165pt
\\advance\\linewidth by -165pt%
%EndExpansion

\\end{document}

END_OF_POST

}

sub create_ansman {
    my $file = shift;
    my %opts = @_;
    
    
    my $style = $opts{style};
    my $fbase = $file;
    $fbase =~ s/\..*$//;
    my $outfile = $fbase . "-answers.tex";
    
    if ( -e $outfile ) {
        print "$file: skpped ($outfile exists)\n";
        return;
    }
    
    # First we identify which problems have answers. Then the start line of the
    # macro is used as a hash key in two hashes, one which stores the end line
    # and another which stores the exercise.  Loading exercises in order (depth
    # first), we end up with the exercises at the greatest depth that have
    # answers.  Doing it this way guarangees that all macros show up, regardless
    # of the depth of the exercise they show up in, i.e. suppose an answer exists
    # in a problem but not in its parts or subparts (which may however contain
    # other answers)

    my %mkl; # macros start line => ex.
    my %mks; # macros start line => end line
    my @exs = ();  #exercises, in order
    
    { # Load the three vars below using Itexam.  Destroy when done.
    
        my $exm = Tarp::Itexam->new();
        $exm->relax( 1 );
        
        while ( my ( $fp, $fn ) = each %tas_select ) {
            if ( $file =~ $fp ) {
                $style = Tarp::Style->new();
                $style->load( $fn ) or die $style->errStr();
            }
        }
        $exm->style( $style );
        
        # hasAnswer is defined above
        my $isans = hasAnswer->new( "answer", $exm );
        
        $exm->extractAttributes( $file )
            or die "Could not extract attributes: " . $exm->errStr();
        
        # Look up the values returned by hasAnswer and store in hashes.
        my $exd = $exm->data();
        
A:      while ( ref $exd eq "ARRAY" ) {
            # Set to the first non empty sequence that hasn't been done already

            for ( 0 .. @$exd - 1 ) {
                if ( keys %{ $exd->[$_] } ) {
                    $outfile = "$fbase-answers$_.tex";
                    if ( ! -e $outfile  ) {
                        $exd = $exd->[$_];
                        last A;
                    }
                }
            }
            print "$file: skipped (all sequences done)\n";
            return;
        }
        
        foreach ( $exm->style()->sort( keys %$exd ) ) {
            if ( my $a = $exd->{$_}->{answer} ) {
                $a =~ /(\d+)\s(\d+)/;
                $mkl{ $1 } = $_;
                $mks{ $1 } = $2;
                push @exs, $_;
            }
        }
        
    }
    
    unless ( @exs ) {
        print "$file: skipped (no exercises with answers)\n";
        return;
    } 
    
    
    # Now get the list of problems with answers and create a skeleton file,
    # using GenSkel.
    use Tarp::GenSkel;
    
    my @mLines; # [ start, end ] lines for each macro, in order and non overlapping.
      
    {
        my $gs = Tarp::GenSkel->new();
        $gs->style( $style );
        
        foreach my $ml ( sort { $a <=> $b } keys %mkl ) {
            my $ex = $mkl{$ml};
            push @mLines, [ $ml, $mks{ $ml } ];
            $gs->addChunk( $ex );
        }
        
        use IO::File;
        {
            my $osk = IO::File->new();
            $osk->open( ">skel.out" ) or die "Could not open skel.out: $!, stopped";
            print $osk "INSERT FILE PREAMBLE HERE\n";
            $gs->printSkel( $osk );
            print $osk "INSERT POSTAMBLE HERE\n";
        }
    }
    
    open TEX, "<$file" or die "Could not open tex: $!, stopped";
    
    # Re-read the .tex file and collect all of the answer macro lines, putting
    # in a canned preamble and "file preamble" - a few lines we got from the orignial
    # .tex file itself. See 'preUntil' entry in .tas file for what goes into the
    # file preamble.  The file preamble goes before the canned preamble.
    
    # We also put in some lines at the end of the file.
    
    my $filePre = '';     # File Preamble, to copy in from input file
    my $gotPreUntil = ''; # Have we matched the 'preUntil' entry?
    
    my @chunkBuffer = ();
    my $am = 0;
    
    while ( <TEX> ) {
        if ( $. < $mLines[0][0] ) {
            if ( $style->m( "preUntil" ) ) {
                $gotPreUntil = 1;
            }
        }
        if (  $. > $mLines[$am][1] ) {
            ++$am;
            last if $am == @mLines; # Skip the rest of the file
            push @chunkBuffer, '';
        }
        $filePre .= $_ if ! $gotPreUntil;
        next if $. < $mLines[$am][0];
        $chunkBuffer[ $am ] .=  $_;
    }
    
    close TEX;
    die "Did not match preUntil entry in TAS file anywhere before first macro, stopped"
        unless $gotPreUntil;
    unshift @chunkBuffer, &pre_lines();
    unshift @chunkBuffer, $filePre;
    push    @chunkBuffer, &post_lines();
    
    # Finally, read in the skeleton file and insert the contents of the chunks into
    # the INSERT.*HERE slots, replacing the $ITM$ in the skeleton file with an
    # unwound exercise list as we go.
    
    use Tarp::GenTex::Unwind;
    
    my $unw = Tarp::GenTex::Unwind->new();
    my @ex_unw = $unw->unwind( @exs );
    
    open SKEL, "<skel.out" or die "Could not open skel.out: $!";
    
    open TEX, ">", $outfile
        or die "Could not open $outfile for writing: $!, stopped";
    
    my $i_ch = 0;     # chunk index
    while ( <SKEL> ) {
        if ( /INSERT.*HERE/ ) {
            if ( $i_ch < @chunkBuffer ) {
                my $lines = $chunkBuffer[$i_ch];
                print TEX $lines . "\n";
            } else {
                warn "Too many INSERT HEREs";
                print TEX $_ . "\n";
            }
            $i_ch++;
        } else {
            if ( /\$ITM\$/ ) {
                my $itm = shift @ex_unw;
                die "Too many \$ITM\$s, stopped" unless $itm;
                s/\$ITM\$/$itm/;
            }
            print TEX $_ . "\n";
        }
        
    }
    
    close SKEL and unlink "skel.out";
    close TEX;
    
    # And voila!
    print "$file -> $outfile\n";
    
}

package hasAnswer;

use base qw/Tarp::Itexam::Attribute/;
# use Tarp::MultiLineMatch;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    
    bless $self, $class;
    return $self;
}

# return true if exercise has at least one macro
# containing "ANSWER"

sub value {
    my $self = shift;
    my $args = shift;

    my $exBuffer = $args->{exBuffer};
    
    my @r;
    my $in = 0;
    my $l = 1;
    foreach ( @$exBuffer ) {
        if ( /TCIMACRO/ ) {
            push @r, [ $l ];
            $in  = 1;
        }
        if ( /EndExpansion/ ) {
            die "EndExpansion before TCIMACRO, stopped at $args->{file} line "
                . $args->{exLine} + $l unless $in;
            push @{$r[-1]}, $l;
        }
        $l++;
    }
    
    if ( @r ) {
        foreach ( @r ) {
            for ( my $l = $_->[0] + 1; $l <= $_->[1]; $l++ ) {
                my $i = $l - 1;
                if ( $exBuffer->[$i] =~ /ANSWER/ ) {
                    my @fl = map { $args->{exLine} + $_ - 1 } @$_;
                    return "@fl";
                }
            }
        }
    }
    return '';
}

package main;

# Tarp::Style->debug( 1 );

Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
Tarp::Style->import( "Tarp::LaTeXtract::Style" );
Tarp::Style->import( "Tarp::GenSkel::Style" );

# Load the .tas file and check syntax.  Docs for the styles above specify
# which tags are required and what they can contain.

my $style = Tarp::Style->new();
$style->load( "ansman.tas" ) or die $style->errStr();

my @tex = <*.tex>;

die "No .tex files in current directory!\n" unless @tex;

foreach ( @tex ) {
    next if /-answers/;
    create_ansman( $_, style => $style );
}
