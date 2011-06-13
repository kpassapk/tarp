package Tarp::MasterAlloc::App;

=head1 NAME

Tarp::MasterAlloc::App - The code behind the command line program

=cut

use strict;
use Getopt::Long;
use Pod::Usage;
use IO::File;

use Tarp::MasterAlloc;

=head1 FUNCTIONS

=head2 run

    Tarp::MasterAlloc::App->run();

=cut

sub run {
    my $TASfile = '';
    my $nextMaster = '';
    my $OUTfile = '';
    my $fix = '';
    my $gen_tas = '';
    
    GetOptions(
        'tas=s'         => \$TASfile,
        'gen-tas'       => \$gen_tas,
        'out=s'         => \$OUTfile,
        'next-master=i' => \$nextMaster,
        'fix'           => \$fix,
        help            => sub { pod2usage(1); },
        version         => sub { require Tarp::MasterAlloc;
            print "tamasteralloc v$Tarp::MasterAlloc::VERSION\n";
            exit 1;
        },

    ) or pod2usage( 2 );

    if ( $gen_tas ) {
        pod2usage({ -msg => "Too many arguments for --gen-tas", -exitval => 2 })
            if @ARGV;
        my $ma = Tarp::MasterAlloc->new();
        my $sty = $ma->style();

        $sty->save( "TASfile.tas" )
            or die "Could not save 'TASfile.tas': " . $sty->errStr() . "\n";
        print "Created 'TASfile.tas'\n";
        return;
    }
    
    pod2usage( -msg => "Incorrect number of arguments", -exitval => 2 )
        if @ARGV != 1;
    my $TEXfile = shift( @ARGV );
    
    my $sx = Tarp::MasterAlloc->new();
    $sx->style()->load( $TASfile )
        or die $sx->style()->errStr() . "\n";
    
    if ( $nextMaster && $fix ) {
        die "Options --next-master and --fix are mutually exclusive - use one or the other.\n";
    }
    
    my $mainOpt = $fix ? "--fix" : "--next-master";

    my $out = IO::File->new();
    
    if ( $fix || $nextMaster ) {
        if ( ! $OUTfile ) {
            die "The $mainOpt option requires an output file to be specified " .
                "with the --out option.\n";
        }
        
        $out->open( ">$OUTfile" )
            or die "Could not open $OUTfile for writing: $!\n";
        
        if ( $nextMaster ) {
            $sx->nextMaster( $nextMaster );
        }
    }

    $sx->getExData( $TEXfile );
    
    if ( $nextMaster || $fix ) {
        my $changes = $sx->fixCount + $sx->newCount;
        if ( ! $changes ) {
            undef $out;
            unlink $OUTfile or die "Could not delete output file: $!";
            die "No output written: No changes to $TEXfile required.\n";
        }
        
        $sx->printLineBuffer( $out );

        undef $out;
        
        print "Wrote file $OUTfile\n";
        
        print "Applied:\n";
        print "\tfixes:       " . $sx->fixCount . "\n";
        if ( $nextMaster ) {
            my $lastMaster = $sx->nextMaster - 1;
            print "\tnew masters: " . $sx->newCount . " ($nextMaster to $lastMaster)\n";
        }
    } else {
        $sx->printExData( [ { exercise => "Problem"}, { masterNumber => "Master" }]);
    }
}

1;