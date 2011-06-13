package Tarp::GenTex::App;

use strict;
use warnings;

=head1 NAME

Tarp::GenTex::App - Code behind the command-line program tagentex

=head1 SYNOPSIS

    Tarp::GenTex::App->run();

This module contains one class method, run(), which is equivalent to running
the command-line program.

=cut

use Getopt::Long;
use Pod::Usage;
use Tarp::GenTex;
use Tarp::Style;
use Tarp::Config;

use File::Spec; # for catfile();

=head2 run

Loads @ARGV as described in the C<tagentex> manual page.  See L<tagentex> for
more details.

=cut

sub run {

    my $SKELfile = '';
    my $CHUNKfile = '';
    my $TASfile = '';
    my $OUTfile = '';
    my $gen_tas = '';
    
    my $masterTemplates = undef;
    my $templateDir = undef;
    my @vars = ();
    my $debug = 0;
    
    GetOptions(
        'tas=s'              => \$TASfile,
        'gen-tas'            => \$gen_tas,
        'skel=s'             => \$SKELfile,
        'chunk=s'            => \$CHUNKfile,
        'out=s'              => \$OUTfile,
        'var=s'              => \@vars,
        'master-templates'   => \$masterTemplates,
        'template-dir=s'     => \$templateDir,
        help            => sub { pod2usage(1); },
        version         => sub { require Tarp::GenTex;
                                print "tagentex v$Tarp::GenTex::VERSION\n";
                                exit 1;
                            },
        debug => \$debug,
    ) or pod2usage( 2 );
    
    if ( ! $gen_tas ) {
        pod2usage({ -msg => "Incorrect number of arguments\n", -exitval => 2 })
            if @ARGV != 1;
    
        my $PKlist = shift @ARGV;
        
        if ( $templateDir && ! $masterTemplates ) {
            die "Invalid combination of options: --template-dir also requires the " ,
                "--master-templates option.  See tagentex --help for more details.\n";
        }
    
        my %vars;
        for ( @vars ) {
            my ( $v, $l ) = split /;/, $_;
            if ( $vars{$v}) {
                push @{$vars{$v}}, $l;
            } else {
                $vars{$v} = [ $l ];
            }
        }
    
        Tarp::Style->debug( $debug );
        
        my $gtx = Tarp::GenTex->new( $PKlist );
        if ( $masterTemplates ) {
            $gtx->genTemplateFiles( $templateDir );
        } else {
            my $sty = $gtx->style();
            $sty->load( $TASfile ) or die $sty->errStr() . "\n\nStopped";
            
            $gtx->SKELfile( $SKELfile );
            $gtx->CHUNKfile( $CHUNKfile );
            $gtx->OUTfile( $OUTfile );
            
            my %av = ();
            if ( $sty->exists( "filename" ) &&
                $sty->m( "filename", $PKlist ) ) {
                %av = %{$sty->xformVars( $sty->mVars(), "filename" => "texVars" )};
            }
            @av{ keys %vars } = values %vars;
            $gtx->gen( %av );
            
            my $out = $gtx->OUTfile();
            print "Successfully created '$out'\n";
        }
    } else {
        pod2usage({ -msg => "Too many arguments", -exitval => 2 })
            if @ARGV;
        Tarp::Style->import( "Tarp::GenTex::Style" );
        my $exm = Tarp::Itexam->new(); # Import the rest of the style plugins & create style
        my $sty = $exm->style(); # could also say Tarp::Style->new() and then import
        $sty->save( "TASfile.tas" )
            or die "Could not save 'TASfile.tas': " . $sty->errStr() . "\n";
        print "Created 'TASfile.tas'\n";
    }
}

1;