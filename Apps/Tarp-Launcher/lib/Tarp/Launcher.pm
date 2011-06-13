package Tarp::Launcher;

use warnings;

=head1 NAME

Tarp::Launcher - launch installed TarpToolkit scripts

=head1 VERSION

Version 0.992

=cut

our $VERSION = '0.992';

my $Debugging = '';

=head1 SYNOPSIS

    use Tarp::Launcher;

    my $l = Launcher->new();
    
    $l->prog( 'talatexcombine_gui' );
    
    # Launch the program with some command line options
    # The script will continue when the application terminates.
    $l->launch( @ARGV );
    
    $l->runTest( 3 );
    $l->showDocs();

=cut


BEGIN {
    use Tarp::Config;
    our $directory = Tarp::Config->InstallDir();
}

use File::Spec;
use Carp;
use Cwd;
use ActiveState::Browser;

my $LIB = File::Spec->catfile( $directory, "lib" );

my $BIN = File::Spec->catfile( $directory, "bin", );

use strict; # Down here otherwise the previous two lines are errors

my %fields = (
    app => '',
);

our $AUTOLOAD;

=head1 METHODS

=head2 new

=cut

sub new {
    my $class = shift;
    my $self  = {
        _permitted => \%fields,
        %fields,
        _ext       => "pklist",
        _appCmd    => undef,
    };
    
    bless $self, $class;
    return $self;
}

=head2 launch

    $l->launch( @args );

Launches the program with the specified command line options.

=cut

sub launch {
    my $self = shift;
    my @args = @_;

    my @cmd = $self->_buildCommand( @args );

    $self->_goCommand( @cmd );
}

=head2 app

    $l->app( "taprogram" );

Starts a program called "taprogram.pl" which is installed in the "bin"
subdirectory of the Toolkit installation directory.

=cut

sub app {
    my $self = shift;
    if ( @_ ) {
        my $app = shift;
        $self->{app}     = $app;
        $self->{_appCmd} = $app . "\.pl";
        return $app;
    } else {
        return $self->{app};
    }
}

=head2 runTest

    $l->runTest( 1 );
    $l->runTest( "all" );

Runs the specified test for the current app, or all available tests if "all" is
given.

Tests are in the "t" subdirectory of the installation directory.  Each
application then has a test directory with the name of the application, which
contains directories called "c01", "c02" etc. corresponding to individual test
cases. When a test is run, the application is started in the test case
directory, and a browser window is opened showing a file called "expected.html"
in this same directory (if this file exists).

=cut

sub runTest {
    my $self = shift;
    my $test = shift;
    my @args = @_;
    
    my $t = File::Spec->catfile( Tarp::Config->ResourceDir(), "t" );

    # Run one test or all tests
    my $testBase = File::Spec->catfile( $t, $self->{app} );
    chdir $testBase or die "Could not chdir to $testBase: $!, stopped";

    my $runTest = sub {
        my $tc = shift;
        $tc = "c" . sprintf "%02d", $tc;
        
        print "\nTEST CASE $tc\n\n";
        chdir $tc
            or die "Could not chdir to $tc: $!, stopped";
    
        my $ext = $self->{_ext};
        my ( $inFile ) = <*.$ext>;
        die "Input *.$ext file not found, stopped"
            unless $inFile;

        if ( -e "expected.html" &&
            ActiveState::Browser->can_open( "www.something.com" ) ) {
            ActiveState::Browser::open( cwd() . "/expected.html" );
        }
        
        my @cmd = $self->_buildCommand( @args, $inFile );
        my $ret = $self->_goCommand( @cmd );
        
        chdir "..";
        return $ret;
    };
        
    if ( $test eq "all" ) {
        my @cases = <c*>;
        
        foreach my $tc ( 1 .. @cases ) {
            &$runTest( $tc ) or last;
        }
    } else {
        &$runTest( $test );
    }
}

=head2 showDocs

    $l->showDocs();

Shows documentation for this program in HTML (if avialable), using
ActiveState::Browser.  Documentations are expected to be in the "docs"
subdirectory of the install directory, under a folder with the name of the
application, in a file called index.html.

If no documentation is found, an error message is printed and the method
returns zero.

=cut

sub showDocs {
    my $self = shift;

    my $docs = File::Spec->catfile( Tarp::Config->InstallDir(), "docs" );
    
    my $docFile = File::Spec->catfile( $docs, $self->{app}, "index.html" );

    if ( ! -e $docFile ) {
        warn "No documentation found for $self->{app}.\n";
        return 0;
    }
    
    if ( ActiveState::Browser->can_open( "www.something.com" ) ) {
        ActiveState::Browser::open( $docFile );
        return 1;
    } else { return 0; }
}

sub _buildCommand {
    my $self = shift;
    my @opts = @_;

    my @cmd = (
        "perl",
        "-I$LIB",
        File::Spec->catfile( $BIN, $self->{_appCmd} ),
        @opts
    );
    return @cmd;
    
}
# Returns 1 if the program ran ok, 0 if cancelled, or raises an exception
# for anything more serious.

sub _goCommand {
    my $class = ref $_[0] ? ref shift : shift;
    my @cmd = @_;
    
    print "Executing system\( @cmd\)\n" if $class->debug;
    
    my $ret = system @cmd;
    if ($? == -1) {
        print "failed to execute: $!\n";
    }
    elsif ($? & 127) {
        printf "child died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    else {
        printf "child exited with value %d\n", $? >> 8 if $class->debug;
    }

#    if ( $ret != 0 ) {
#        if ( $? >> 8 == 255 ) {
#            print "\nCancelled\n";
#            return 0;
#        }
#        else {
#            die "system @cmd failed: " . ( $? >> 8 ) . ", stopped";
#        }
#    }
    return 1;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

=head2 debug

    $launcher->debug( 1 );

Sets the debugging level.

=cut

sub debug {
    my $class = ref $_[0] ? ref shift : shift;
    if ( @_ ) {
        return $Debugging = shift;
    } else {
        return $Debugging;
    }
}

sub DESTROY {}

=head1 AUTHOR

Kyle Passarelli, C<< <kyle.passarelli at gmail.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tarp::Launcher


=head1 COPYRIGHT & LICENSE

Copyright 2008 Kyle Passarelli, all rights reserved.


=cut

1; # End of Tarp::Launcher
