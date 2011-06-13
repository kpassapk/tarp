package Tarp::PullCSV::App;

=head1 NAME

Tarp::PullCSV::App - The code behind the command line program.

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Carp qw/croak/;
use File::Copy qw/move/;
use File::Spec; # catfile, splitpath
use IO::File;

use YAML::Tiny;

use Tarp::Style;
use Tarp::PullCSV;
use Tarp::Config;

=head1 FUNCTIONS

=cut

sub _loadPrefs {
    my %defaults = @_;
    
    my $resDir = Tarp::Config->ResourceDir();
    die "Tarp resource directory '$resDir' not found!\n" unless -e $resDir;
    my $prefFile = File::Spec->catfile( $resDir, "toolPrefs.yml" );

    return %defaults unless -e $prefFile;
#    print "Loading '$prefFile'\n";
    my $yaml = YAML::Tiny->read( $prefFile );
    die "Error loading $prefFile: " , YAML::Tiny->errstr() , ", stopped"
        unless $yaml;
    
    if ( my $p = $yaml->[0]->{pullCSV} ) {
        @defaults{ keys %$p } = values %$p;
    }
    return %defaults;
}


# Puts the user's plugin directory into @INC.
# Attempts to load plugins by matching 'filename' TAS entry.
# Reads 'col' from the supplied prefs hash, containing the 
# arguments for each plugin column.  Splits these into column
# name and options, uses the corresponding module, and creates a
# new column for each.
#
# Returns:
# - fileVars
#
sub _loadPlugins {
    my $csv = shift;
    my $TEXfile = shift;
    my $prefs = shift;

    my $col = $prefs->{col}; # contents of --col
    $prefs->{fileVars} = {}; # filename variables to be returned
    
    my @colArgs = (); # column arguments given by user
    my @plugs   = (); # Plugins in plugins/ directory.

    for ( my $i = 0; $i < @$col; $i++ ) {
        $_ = $col->[$i];
        if ( /^(.*?);(.*)$/ ) {
            $col->[$i]     = $1;
            $colArgs[$i]   = $2;
        }
    }
    
    # Put user's plugin directory into @INC
    my $resDir = Tarp::Config::ResourceDir();
    die "Tarp resource directory '$resDir' not found!\n" unless -e $resDir;
    my $plugBase  = File::Spec->catfile( $resDir, "plugins" );
    my $pluginDir = File::Spec->catfile( $plugBase, "Tarp", "PullCSV" );

    # Find plugins in plugin/ directory.
    if ( -e $pluginDir ) {
        if ( opendir( PLUGDIR, $pluginDir ) ) {
            push( @INC, $plugBase );
            @plugs = grep { /\.pm$/ } readdir PLUGDIR;
            closedir PLUGDIR;
        } else {
            croak "Could not opendir '$pluginDir: $!, stopped'";
        }
    } else {
        croak "Plugin directory does not exist:\n$pluginDir\nStopped";
    }
    
    for ( my $i = 0; $i < @plugs; $i++ ) {
        $_ = $plugs[$i];
        ( undef, undef, $_ ) = File::Spec->splitpath( $_ );
        s/\.pm$//;
        $plugs[$i] = $_;
    }
    
    # All columns to load: specified using --col first (to ensure the right
    # order), then the rest in plugins/.  There may be duplicates in this list.
    
    my @ac = ( @$col, sort @plugs );

    return unless @ac;
    
    my $hlp = Tarp::Style->new();
    $hlp->load( $prefs->{TASfile} );

    # For any column in @ac without arguments in @colArgs,
    # Try and get them from a 'filename' variable with the same
    # name as the plugin.
    
    if ( $hlp->exists( "filename" ) ) {
        if ( $hlp->m( "filename", $TEXfile ) ) {
            my $v = $hlp->mVars();
            for ( my $i = 0; $i < @ac; $i++ ) {
                next if defined $colArgs[ $i ];
                # column vars (if any)
                my $cv = $v->{ $ac[$i] };
                $colArgs[ $i ] = $cv->[0] if $cv;
            }
            $prefs->{fileVars} = $v;
        }
    }

    print "Loading plugins: " unless $prefs->{silent};
    
    my %loaded = map { $_ => 0 } @plugs;     # not loaded yet
    
    for ( my $i = 0; $i < @ac; $i++ ) {
        my $p = $ac[ $i ];
        next if $loaded{ $p };
        print $p . " " unless $prefs->{silent};

        my $fp = "Tarp::PullCSV::$p";
        eval "use $fp";
        if ( $@ ) {
            my $err = $@;
            $err =~ s/\@INC.*$/plugin directory ($plugBase)/s;
            warn "Could not load \"$p\" plugin:\n$err\n";
        } else {
            my $c;
            if ( defined( my $arg = $colArgs[ $i ] ) ) {
                eval '$c = $fp->new( $csv, $arg )';
            } else {
                eval '$c = $fp->new( $csv )';
            }
            if ( $c ) {
                if ( $c->isa( "Tarp::PullCSV::Column" ) ) {
                    $c->_attrName( $p );
                    $loaded{ $p } = 1;
                } else {
                    warn "Invalid plugin: \"$p\" is not a " ,
                    "Tarp::PullCSV::Column\n";
                }
            } else {
                warn "Error loading \"$p\" plugin: $@\n";
            }
        }
    }
    print "\n" unless $prefs->{silent}; # to finish plugin list
    1;
}

sub _writeCSV {
    my $csv = shift;
    my $TEXfile = shift;
    my %opts = @_;

    my ( $OUTfile, $append ) = @opts{qw/ OUTfile append /};
    
    if ( $OUTfile ) {
        ( $OUTfile ) = $csv->style()->interpolateVars( $OUTfile, $opts{fileVars} );
        if ( $csv->style()->varsIn( $OUTfile ) ) {
            warn "Warning: ignoring 'OUTfile' - cannot sub out all variables in '$OUTfile'\n";
            undef $OUTfile;
        }
    }

    if ( ! $OUTfile ) {
        $OUTfile = $TEXfile;
        ( undef, undef, $OUTfile ) = File::Spec->splitpath( $OUTfile );
        $OUTfile =~ s/\.tex$//;
        $OUTfile .= ".csv";
    }
    
    # Only append if file is there and can be written to.
    if ( $append ) {
        my $TMP = IO::File->new();
        $TMP->open( ">$OUTfile.tmp" )
            or die "Could not open '$OUTfile.tmp' for writing: $!, stopped";
        my $OLD = IO::File->new();
        if ( ! $OLD->open( "<$OUTfile" ) ) {
            undef $TMP;  # closes the .tmp file
            unlink "$OUTfile.tmp";
            die "Could not open '$OUTfile' for reading: $!, stopped"; 
        }
        
        # Both filehandles are open.
        # To append, read the entire file and print it out to a temporary
        # file, then print the exercise data to that temporary file, and
        # finally move the temporary file to replace the original file.
        while ( <$OLD> ) {
            print $TMP $_;
        }
        $csv->write( $TMP );
        undef $OLD; # close the file
        undef $TMP; # close the file
        move( "$OUTfile.tmp", "$OUTfile" );
        print "Output appended to $OUTfile\n" unless $opts{silent};
    } else {
        if ( ! $opts{force} ) {
            my $fidx = 1;
            my $OUTfile_o = $OUTfile;
            my $OUT_ = $OUTfile;
            $OUT_ =~ s/\.csv$/_/;
            while ( -e $OUTfile ) {
                $OUTfile = $OUT_ . ++$fidx . ".csv";
            }
            warn "Warning: wanted to write to '$OUTfile_o', but it already exists;" ,
                " to avoid wiping it out, using '$OUTfile' instead.\n"
                    if $OUTfile_o ne $OUTfile;
        }        
        my $OUT = IO::File->new();
        my $existed = -e $OUTfile;
        $OUT->open( ">$OUTfile" )
            or croak "Could not open $OUTfile for writing: $!, stopped";
        
        $csv->write( $OUT, Tarp::PullCSV::PRINT_HEADINGS );
        undef $OUT;
        if ( ! $existed ) {
            print "Created $OUTfile\n" unless $opts{silent};
        } else {
            print "Output written to $OUTfile\n" unless $opts{silent};
        }
    }
}

=head2 run

    package Tarp::PullCSV::App->run();

Runs the application, parsing command line options from @ARGV.

=cut

sub run {
    my %prefs = _loadPrefs( col => [], style => [] );
    my $gen_tas = '';
    my @styles = ();
    
    GetOptions(
        'tas=s'      => \$prefs{TASfile},
        'gen-tas'    => \$gen_tas,
        'out=s'      => \$prefs{OUTfile},
        'append'     => \$prefs{append},
        'col=s'      => sub { push @{$prefs{col}}, $_[1] },
        'style=s'    => sub { push @{$prefs{style}}, $_[1] },
        force        => \$prefs{force},
        silent       => \$prefs{silent},
        help         => sub { pod2usage(1); },
        version      => sub { require Tarp::PullCSV;
                             print "tapullcsv v$Tarp::PullCSV::VERSION\n";
                             exit 1;
                         },
    ) or pod2usage( 2 );
    
    $prefs{TASfile} ||= '';
    $prefs{OUTfile} ||= '';
    $prefs{append}  ||= '';
    $prefs{silent}  ||= '';
    
    if ( $gen_tas ) {
        pod2usage({ -msg => "Too many arguments for --gen-tas", -exitval => 2 })
            if @ARGV;
        my $csv = Tarp::PullCSV->new();
        my $sty = $csv->style();

        $sty->save( "TASfile.tas" )
            or die "Could not save 'TASfile.tas': " . $sty->errStr() . "\n";
        print "Created 'TASfile.tas'\n";
        return;
    }

    pod2usage( -msg => "Incorrect number of arguments", -exitval => 2 )
        if @ARGV != 1;
    
    my $TEXfile = shift @ARGV;
    
    if ( ! ( $TEXfile =~ /\.tex$/ ) ) {
        warn "This program only takes .tex files as input!\n\n";
        pod2usage( 2 );
    }

    if ( $prefs{OUTfile} && ! ( $prefs{OUTfile} =~ /\.csv/ ) ) {
        warn "This program only writes .csv files!\n\n";
        pod2usage( 2 );
    }
    
    foreach ( @{$prefs{style}} ) {
        Tarp::Style->import( split /;/ );
    }
    my $csv = Tarp::PullCSV->new();
    my $sty = $csv->style();
    $csv->style()->load( $prefs{TASfile} )
        or die $csv->style()->errStr() . "\n";
    &_loadPlugins( $csv, $TEXfile, \%prefs );
    
    die "No columns for CSV file!\n" unless @{$csv->columns()};
    $csv->getColumnData( $TEXfile );

    &_writeCSV( $csv, $TEXfile, %prefs );
}

1;
