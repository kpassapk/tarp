package Tarp::LaTeXtract::App;

=head1 NAME

Tarp::LaTeXtract::App - The code behind the command line program C<talatextract>.

=head1 SYNOPSIS

    use Tarp::LaTeXtract::App;
    
    Tarp::LaTeXtract::App->run();

=head1 DESCRIPTION

This module parses options in the @ARGV array as described in L<talatextract>.
All the work is performed by the run() class method.

=cut

use strict;
use warnings;
use Cwd;
use Getopt::Long;
use Pod::Usage;
use IO::File;

use Tarp::LaTeXtract;

=head2 run

    Tarp::LaTeXtract::App->run();

Runs LaTeXtract by loading @ARGV options and calling read().
If read() is successful, prints match info to currently selected filehandle.
Otherwise, an exception is raised.

=cut

sub run {
    my $TASfile = '';
    my $enforceOrder = '';
    my $doubleClickable = '';
    my $dumpMatches = '';
    my $context = '';
    my $extract_seq = -1;
    my $gen_tas = '';
    my $relax = '';
    
    GetOptions(
        'tas=s'            => \$TASfile,
        'gen-tas'          => \$gen_tas,
        'enforce-order'    => \$enforceOrder,
        'relax'            => \$relax,
        'extract-seq=i'    => \$extract_seq,
        'dump-matches'     => \$dumpMatches,
        'double-clickable' => \$doubleClickable,
        'context=i'        => \$context,
        help               => sub { pod2usage(1); },
        version            => sub { require Tarp::LaTeXtract;
                                    print "talatextract v$Tarp::LaTeXtract::VERSION\n";
                                    exit 1;
                        },
    ) or pod2usage( 2 );
    
    if ( $context && ! ( $context =~ /^\d+$/ ) ) {
        pod2usage({ -msg    => "'context' value should be a positive integer\n",
                  -exitval => 2 });
    }

    Tarp::LaTeXtract->verbose( 1 );
    
    my $xt = Tarp::LaTeXtract->new();
    
    if ( ! $gen_tas ) {
        pod2usage({ -msg => "Too few arguments\n", -exitval => 2 })
            if @ARGV != 1;
    
        my $TEXfile = shift( @ARGV );
        
        $xt->style()->load( $TASfile )
            or die $xt->style()->errStr() . "\n";
        $xt->doubleClickable( $doubleClickable );
        $xt->enforceOrder( $enforceOrder );
        $xt->context( $context ) if $context;
        $xt->extractSeq( $extract_seq );
        $xt->relax( $relax );
        
        # Now the important bit
        my $readOK;
        if ( $readOK = $xt->read( $TEXfile ) ) {
            $xt->dumpLines();
        }
        
        # Only dump matches if at least one tag is matched, otherwise ignore
        # silently.
        if ( $dumpMatches && keys %{$xt->matches()} ) {
            my $Mfile = $TEXfile;
            $Mfile =~ s/\..*?$//;
            $Mfile .= "-matches.txt";
            my $io = IO::File->new();
            $io->open( ">$Mfile" ) or die "Could not open $Mfile for writing: $!\n";
            $xt->dumpMatches( $io );
            print "Wrote match info to '$Mfile'\n";
        }
        
        die $xt->errStr() . "\n" unless $readOK;
    } else {
        pod2usage({ -msg => "Too many arguments", -exitval => 2 })
            if @ARGV;
        $xt->style()->save( "TASfile.tas" )
            or die "Could not save 'TASfile.tas': " . $xt->style()->errStr() . "\n";
        print "Created 'TASfile.tas'\n";
    }
}

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::LaTeXtract::App

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Kyle Passarelli, all rights reserved.

=cut

1;