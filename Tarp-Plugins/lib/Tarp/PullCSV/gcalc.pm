package Tarp::PullCSV::gcalc;

use strict;
use base qw/ Tarp::PullCSV::Column /;

sub heading { "gCalc" }

# This plugin labels an exercise as 'gcalc' if the words 'gcalc' appear in the
# exercise itself or if ther is a an instruction list in the .tex file that
# refers to that exercise as being gCalc.
# The instruction stuff is in preProcess() (it's done once for the entire file)
# while the matching for gCalc in the exercise itself is in value().
# The best way to see what is happening is to look at the code below!

sub new {
    my $class = shift;
    my $csv = shift;
    
    my $self = $class->SUPER::new( $csv );
    $self->{byInstruct} = undef;
    $self->{_attr}->inherit( 1 );
    
    bless $self, $class;
    return $self;
}

# Get instruction ranges for gCalc problems from spanExer command
# Save every exercise in this range for later (in a hash). 

sub preProcess {
    my $self = shift;
    my $args = shift;
    
    my ( $listData, $lineBuffer, $eXtractor )
        = @{$args}{qw/ listData lineBuffer eXtractor /};
    
    my %gCalcs;
    
    my $inInstructions = '';
    my @instructionRange = (0,0); # (from, to)
    my $isGcalc = '';
    
    my $line = 0;
    foreach ( @$lineBuffer ) {
        $line++;
        $inInstructions = 1 if /\\begin{instructions}/;
        if ( /\\end{instructions}/ ) {
            if ( $isGcalc ) {
                my ( undef, $seq ) = $eXtractor->itemOnLine( $line );
                my @is = map { $seq } @instructionRange;
                @gCalcs{@instructionRange} = @is;
            }
            $inInstructions = '';
        }
        
        if ( $inInstructions ) {
            if ( /{SpanExer}{(\d+)--(\d+)}/ ) {
                @instructionRange = ( $1 .. $2 );
            }
            $isGcalc = 1 if ( /gcalc/i );
        }
    }
    $self->{byInstruct} = \%gCalcs;
}

# gCalc by instruction or because an exercise contains gCalc. Either one.

sub value {
    my $self = shift;
    my $listData = shift;
    my $byInstruct = $self->{byInstruct};
    my ( $itemString, $exSeq, $exBuffer )
        = @{$listData}{ qw/ itemString exSeq exBuffer / };
    
    # If we already determined in some instruction that this
    # exercise is gCalc, then it's gCalc!!
    return 1 if exists $byInstruct->{$itemString} &&
        $byInstruct->{$itemString} eq $exSeq;
    
    my $gCalc = 0;
    
    # Also True if any line in the exercise buffer contains "GCALC".
    # Ignore case.
    
    foreach my $bfLine ( @$exBuffer ) {
        $gCalc = 1 if $bfLine =~ /gcalc/i;
    }

    return $gCalc;
}

1;