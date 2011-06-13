#!/usr/bin/perl -w
use strict;

=head1 NAME

    expandex.pl - expand examples by inserting macros

=head1 SYNOPSIS

perl expandex.pl [options]

Options:

    --file=[file.tex]
    --leave-tmp

Examples:

The default is to expand files matching the 'filename' entry in expandex.tas

    perl expandex.pl

This requires the following files 

    epandex.pl
    expandex.tas
    Examples_6et01.csv
    *.tex

=head1 QUICK START

For 6et01 (for example), put in current directory:

    epandex.pl
    expandex.tas
    6et01*.tex
    Examples_6et01.csv

Then run expandex.pl

Instructions:

Put this script along with expandex.tas in the same directory as the chapter
.tex files.  The 'filename' entry in the .tas file has a $bookch$ variable which
will catch the book and chapter, and a $section$ variable that catches the
section.

After splitting up the filename as described above, the script looks for a .csv
file called Examples_$bookch$.csv in the current directory. It extracts the
contents of every .tex file in the current directory and looks it up in the
.csv file. Then it produces a new file with macros for every example that have
the number specified in the .csv file.

=cut
 
use Tarp::Style;
use Tarp::LaTeXtract;

# We import some Tarp::Styles to require some tags in the input and
# provide some important functions to deal with tags and such

# For itemTag::ITM
Tarp::Style->import( "Tarp::Style::ITM", "Tarp::Style::ITM::NLR" );
# for "beginTag", "endTag", "itemTag", "sequenceRestart"
Tarp::Style->import( "Tarp::LaTeXtract::Style" );
# for "filename"
Tarp::Style->import( "Tarp::GenTex::Style" ); 

sub expandex {
    my $file = shift;
    my %opts = @_;
    
    my $style = $opts{style};
    if ( ! $style->m( "filename", $file ) ) {
        print "$file: skipped\n";
        return;
    }
    my $fbase;
    {
        my @p = @{ $style->mParens() };
        shift @p;
        $fbase = join '', @p;
    }

    # Don't re-do output we've already produced!
    if ( -e "$fbase-new.tex" ) {
        print "$file: skipped ($fbase-new.tex exists)\n";
        return;
    }
        
    # Get bookch and section from filename, to look up in .csv file later.
    
    my $fbookch = $style->mVars()->{bookch}->[0];
    my $fsect = $style->mVars()->{section}->[0];
    
    my $xtr = Tarp::LaTeXtract->new();
    $xtr->extractSeq( 0 ); # Ignore tags in other sequences
    $xtr->style( $style );
    
    $xtr->read( $file ) or die $xtr->errStr() ."\n";
    
    # Check we have all exercises in .csv
    # ...we check here b/c the user may need to change original .tex file
    
    use Text::CSV;
    my $csv = Text::CSV->new();
    open CSV, "<Examples_$fbookch.csv"
        or die "Could not open 'Examples_$fbookch.csv' for reading: $!, stopped";
    
    my @exs = (); # examples
    my @ids = (); # IDs, one per example
    my @vid = (); # videos, 0 or 1 for each example
    
    while ( <CSV> ) {
        next if $. == 1; # skip header
        $csv->parse( $_ ) or die "Could not parse line $.: " . $csv->err_str();
        my ( $id, undef, undef, $section, $ex, $vid ) = $csv->fields();
        next unless $section eq $fsect;
        if ( $xtr->lines( 0 )->{$ex} ) {
            push @exs, $ex;
            push @ids, $id;
            push @vid, $vid;
        } else {
            my $l0;
            my $p = $ex;
            while ( $p = $xtr->style()->parentEx( $p ) ) {
                $l0 = $p;
            }
            my $ls = '';
            open L, '>', \$ls and select L;
            $xtr->dumpLines();
            close L;

            my @pls = grep { /^$l0/ } split "\n", $ls;
            my $msg = ( "Example '$ex' specified in csv file does not exist in seq0 of '$fbase\_tmp.tex'.\n" );
            $msg .= "Closest matches:\n\t" . join( "\n\t", @pls ) . "\n" if ( @pls );
            die $msg . "Look for $ex near these lines in $fbase.tex, change and re-run.\n";
        }
    }
    close CSV;
    
#    use Data::Dumper;
#    warn Dumper [ @exs ];
#    warn Dumper [ grep { $_ } @vid ];
    
    printf "$file: %de %dvid\n", 0 + @exs , 0 + grep { $_ } @vid;
#    printf "$file: %de %dvid\n", 1,2;
    return '' unless @exs;

    # [from, to] lines where examples exist. we find this out by looking at the
    # line numbers where the beginTag::what and endTag::what variables are found
    
    my @examps;     
    $examps[0] = $xtr->variables()->{"beginTag_0_::what"}->[0]->{line};
    $examps[1] = $xtr->variables()->{"endTag_1_::what"}->[-1]->{line};
    
    open TMP, '<'. $file
        or die "Could not open $file for reading: $!, stopped";
    
    # In this file we will put just the example lines
    open TMP2, ">$fbase\_examples.txt"
        or die "Could not open $fbase\_examples.txt for writing: $!, stopped";
    
    while ( <TMP> ) {
        print TMP2 $_ if $. >= $examps[0] && $. <= $examps[1];
    }
    
    close TMP2;
    close TMP;
    
    # Re-read to get new line numbers... it shouldn't fail here
    # or something is really wrong.
    $xtr->read( "$fbase\_examples.txt" )
        or die "screaming!\n" . $xtr->errStr();
    
    print "$fbase\_examples.txt lines:\n";
    $xtr->dumpLines();
    
    open EXS, "<$fbase\_examples.txt"
        or die "Could not open '$fbase\_examples.txt' for reading: $!, stopped";
    open EXS2, ">$fbase\_examples_new.txt"
        or die "Could not open '$fbase\_examples_new.txt' for writing: $!, stopped";
    
    my @exln;
    foreach ( @exs ) {
        my $xr = $xtr->lines( 0 )->{$_};
        push @exln, $xr->[0];
    }
    
    push @exln, 0;
    
    # Get a list of lines where the example macros should be
    # Then if the item tag is inline or video we do something different
    
    my $inlines = $xtr->variables()->{"itemTag_2_::inline"};

    my $ii = 0; # inline index
    my $ie = 0; # example index
    my $vdelay = 0; # delay putting in macro until after the video macro.
    
    sub macro {
        my $id = shift;
        return <<END_OF_MACRO;
%TCIMACRO{%
%\\hyperref{\\fbox{{\\tiny ITM $id}}\\quad }{}{\\fbox{{\\tiny ITM $id}}\\quad }{}}%
%BeginExpansion
\\msihyperref{\\fbox{{\\tiny ITM $id}}\\quad }{}{\\fbox{{\\tiny ITM $id}}\\quad }{}%
%EndExpansion
END_OF_MACRO

    }
    
    while ( <EXS> ) {
        if ( $. == $exln[ $ie ]  ) {
            if ( $inlines->[$ii] && $. == $inlines->[$ii]->{line} ) {
                # Split up inline ex.
                my $p = $inlines->[$ii]->{pos};
                print EXS2 substr ( $_, 0, $p ) . "\n";
                print EXS2 macro( $ids[ $ie ] );
                print EXS2 substr $_, $p;
                $ii++;
            } else {
                # Just put it in after
                print EXS2 $_ unless /TARP_ITEM/; # Skip TARP_ITEM lines
                if ( $vid[ $ie ] ) {
                    # If this problem is "video", set a flag and continue
                    # unless there is no space between this problem and the
                    # next
                    if ( $ie < @exln - 1 && $exln[ $ie + 1 ] - $exln[ $ie ] == 1 ) {
                        print EXS2 macro( $ids[ $ie ] );
                    } else {
                        $vdelay = 1;                    
                    }
                } else {
                    print EXS2 macro( $ids[ $ie ] );
                }
            }
            $ie++;
        } else {
            # vdelay is the amount of lines we are delaying the insert of a macro.
            # It is overridden if the first line after the delay does not contain
            # TCIMACRO.  A macro is finally inserted the line after the first
            # EndExpansion.
            
            if ( $vdelay ) {
                # If we were waiting to put in a macro,
                # but the first xline after vdelay was set does not contain
                # TCIMACRO, abandon it and put the macro in now.
                if ( ( $vdelay == 1 && ! /TCIMACRO/ ) ||
                     ( $vdelay == -1 ) ) {
                    print EXS2 macro( $ids[ $ie - 1 ] );
                    $vdelay = 0;                
                } elsif ( /EndExpansion/ ) {
                    # Macro goes on the next line
                    $vdelay = -1;
                } else {
                    $vdelay++;
                }
            }
            print EXS2 $_ unless /TARP_ITEM/;
        }
    } # while <EXS>
    
    close EXS2;
    close EXS;
    
    # Replace example block into original file by reading the entire block into a
    # string and plopping it in in place of the original lines
    
    my $exsBlock;
    {
        local $/;
        open TMP2, "<$fbase\_examples_new.txt" or die "Could not open input";
        $exsBlock = <TMP2>;
        close TMP2;
    }
    
    open TMP, '<', $file or die "Could not open 'file' for reading: $!, stopped";
    open OUT, ">$fbase-new.tex" or die "Could not open '$fbase-new.tex' for writing: $!, stopped";
    
    my $doneEx = '';
    while ( <TMP> ) {
        if ( $. >= $examps[0] && $. <= $examps[1] ) {
            if ( ! $doneEx ) {
                print OUT $exsBlock and $doneEx = 1;
            }
        } else {        
            print OUT $_ ;
        }
    }

    close OUT;
    if ( ! $opts{leave_tmp} ) {
        unlink "$fbase\_examples.txt", "$fbase\_examples_new.txt"
    }
} # sub expandex


use Getopt::Long;
use Pod::Usage;

my $in_file = '';

my %o = (
    leave_tmp => 0,
);

GetOptions(
    "file=s"    => \$in_file,
    "leave-tmp" => \$o{leave_tmp},
) or pod2usage( 2 );

my $style = Tarp::Style->new();
$style->load( "expandex.tas" ) or die $style->errStr() . "\n";

if ( $in_file ) {
    expandex( $in_file, %o, style => $style );
} else {
    foreach ( <*> ) {
        next unless -f $_;
        expandex( $_, %o, style => $style );
    }
}
