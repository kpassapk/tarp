package Tarp::Installer2;

use strict;
use warnings;

use File::Copy;
use File::Spec; # for catfile()
use File::HomeDir; # for my_desktop()

my %fields = (
    buildTool   => "make",
    force       => 1,
    install     => 1,
    clean       => 0,
);

sub MAKEMAKE     { 0 };     # perl Makefile.PL
sub MAKE         { 1 };     # make
sub MAKETEST     { 2 };     # make test
sub MAKEINSTALL  { 3 };     # make install
sub MAKECLEAN    { 4 };     # make clean

sub new {
    my $class = shift;
    my $opts = shift;
    
    my $self = {
        %fields,
        _sudo_         => "sudo ",
        _tasksInOrder => [],
        _permitted    => \%fields,
    };
    
    for my $opt ( keys %$opts ) {
        return unless exists $fields{ $opt };
        $self->{$opt} = $opts->{$opt};
    }
    bless $self, $class;
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;
    my $buildTool = "make";
    my $_sudo_ = "sudo ";
    
#    use Data::Dumper;
#    print Dumper $^O;
    
    if ( $^O eq "MSWin32" ) {
        $_sudo_      = '';
        $buildTool = "nmake";
    }
    
    my @tasksInOrder = (
        "perl Makefile.PL",
        $buildTool,
        "$buildTool test",
        "$_sudo_$buildTool install",
        "$buildTool clean"
    );
    
    $self->{_sudo_} = $_sudo_;
    $self->{buildTool} = $buildTool;
    $self->{_tasksInOrder} = \@tasksInOrder;
}

=head2 installUserData

Copies user data from the Resources directory to the user's ResourceDir.

=cut

sub installUserData {
    my $self    = shift;
    my $srcDir  = "Resources/User";
    
    eval 'use Tarp::Config';
    die "Could not load Tarp::Config: $!, stopped" if $@;

    eval 'use File::Copy::Recursive qw/dircopy dirmove/';
    die $@ if $@;
    
    print "\n***** Installing User Files\n\n";
    
    my $destDir = Tarp::Config->ResourceDir( 0 );

    print "\tSource: Resources/User\n";
    print "\tTarget: $destDir\n\n";
    
    if ( -e $destDir ) {
        my $backupDir = $destDir;
        my $ic = 0;
        
        while ( -e $backupDir ) {
            $backupDir = $destDir . "_backup" . ( $ic++ ? $ic : '' );
        }
        
        dirmove( $destDir, $backupDir );
        print "\nA backup of your user data has been created in $backupDir\n";
        print "Press <RETURN> to continue\n";
        <>;
    }
    
    my $nCopied = dircopy( $srcDir, $destDir );
    
    print "$nCopied file(s) copied\n";
    return $nCopied;
}

# Runs the commands on each of the arguments,
# cd's to a directory with the name of he module, with the :: replaced
# with -.
# Returns true if all tasks returned a zero exit status.
# If force is not set, an unsuccessful task stops installation.

sub install {
    my $self = shift;
    my @stuff = @_;
    
    my %tasks;
    
    my @tasksInOrder = @{$self->{_tasksInOrder}};
 
    my $aok = 1;
    
MOD: foreach my $mod ( @stuff ) {
        print <<MSG;

***** Installing $mod

MSG
        my $modDir = $mod; $modDir =~ s/::/-/;
        chdir $modDir or die "Could not cd to '$modDir': $!";
        $tasks{$mod} = [];
        my $taskRec = \$tasks{$mod};
        
        my $mod_ok = 1;
        
        my $i = -1;
        TASK: for ( @tasksInOrder ) {
            $i++;
            # Only make and clean are called if the "clean" flag is set
            if (  $self->clean && $i != MAKEMAKE && $i != MAKECLEAN ) {
                push @$$taskRec, "skipped";
                next TASK;
            }
            my $task = $tasksInOrder[ $i ];
            print $task . "\n";
            my $rc = system( $task );
            $mod_ok &&= ( $rc == 0 );
            print "\n";
            push @$$taskRec, ( $rc == 0 ? "ok " : "not ok " ) . $task;
            
            last TASK if              $rc && $i == MAKEMAKE; # perl Makefile.pl must succeed 
            last TASK if ! $self->install && $i == MAKETEST;
            next TASK if     $self->force && $i == MAKETEST; # continue if tests failed
            last TASK if $rc; # skip all remaining tasks given non-zero return code

        } # task
        $aok &&= $mod_ok;
        if ( ! $mod_ok ) {
            last if ( $i eq MAKEMAKE || ! $self->force );
        }
        chdir "..";
    } # mod
    
    @{$self->{_tasks}}{ keys %tasks } = values %tasks;
    return $aok;
}

sub installGUI {
    my $self = shift;

    print <<MSG;

***** Installing GUI & Komodo Integration

MSG

    if ( $self->clean || ! $self->install ) {
        print "Skipped\n";
        return;
    }
    
    eval 'use Tarp::Config';
    die $@ if $@;
    my $target = Tarp::Config->InstallDir();
    print "\tSource: GUI\n";
    print "\tTarget: $target\n\n";
    
    # Here we are hoping root has File::Copy::Recursive installed.
    my @cmd = ( $self->{_sudo_} . "perl", "-IResources/lib -e \"use File::Copy::Recursive qw/dircopy/; dircopy( 'GUI', '$target' )\"" );

    system( "@cmd" ) == 0 or die "system @cmd failed: $?";
    
    # if this is Windows, put links on the desktop.    
    if ( $^O eq "MSWin32" ) {
        eval 'use Win32::Shortcut';
        if ( ! $@ ) {
            print "\n***** Creating Desktop shortcuts\n\n";
            my $desktop = File::HomeDir->my_desktop;
            my $link = Win32::Shortcut->new();
            $link->{'Description'} = "Techarts Perl Toolkit";
            $link->{Path} = File::Spec->catfile(
                Tarp::Config->InstallDir(),
                "Komodo_integration",
                "Tarp Toolkit.kpf"
            );
            $link->Save( File::Spec->catfile( $desktop, "Tarp.lnk" ) );
            $link->Close();
            
            $link = Win32::Shortcut->new();
            $link->{'Path'} = Tarp::Config->ResourceDir();
            $link->{'Description'} = "Tarp Resource Directory";
            $link->Save( File::Spec->catfile( $desktop, "Tarp Resources.lnk" ) );
            $link->Close();
        }
    }
    1;
}

sub installScripts {
    my $self = shift;
    print <<MSG;

***** Installing Scripts

MSG

    if ( $self->clean || ! $self->install ) {
        print "Skipped\n";
        return;
    }

    my $tests_ok = 1;
    my %tasks;
    
    chdir "Scripts" or die "Could not chdir to Scripts: $!";
    foreach  my $script ( <*> ) {
        my $tr = $tasks{ $script } = [];
        next unless -d $script;
        chdir $script or die "Could not chdir to $script: $!";
        if ( -e "t" ) {
            use Test::Harness;
            print "Testing $script\n";
            eval { runtests( <t/*.t> ) };
            if ( $@ ) {
                warn "Tests did not succeed: $@" if $@;
                push @$tr, "not ok runtests";
                $tests_ok = '';
            } else {
                push @$tr, "ok runtests";
                print "\n";
            }
        } else {
            push @$tr, "no tests";
        }
        chdir "..";
    }
    chdir "..";
    
    if ( $tests_ok || $self->force ) {
        eval 'use Tarp::Config';
        die "Could not load Tarp::Config: $!, stopped" if $@;
    
        my $destDir = File::Spec->catfile(
            Tarp::Config->ResourceDir(),
            "Scripts"
        );
        use File::Copy::Recursive qw/dircopy/;
        dircopy( "Scripts", $destDir )
            or warn "Did not copy any scripts from 'Scripts' to '$destDir'\n";
    }

    @{$self->{_tasks}}{ keys %tasks } = values %tasks;
    return $tests_ok;
}

sub printResults {
    my $self = shift;
    
    print <<END_OF_SUMMARY;
--------------------------------------------------------------------------------
                            INSTALLATION RESULTS
--------------------------------------------------------------------------------

END_OF_SUMMARY

    my $tasks = $self->{_tasks};
    
    my @beasties = keys %$tasks;
    
    foreach my $beasty ( @beasties ) {
        print $beasty . "\n";
        for ( @{$tasks->{$beasty}} ) {
            print "\t" . $_ . "\n";
        }
    }
}

sub printHeading {
    my $self = shift;
    print <<END_OF_HEADING;
======================== TARP INSTALLATION SCRIPT ==============================

               Copyright (C) 2008-2009 by Kyle Passarelli

Installing applications, modules, scripts and plugins...
This process may take a few minutes.

================================================================================

END_OF_HEADING

}

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
                or die "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless (exists $self->{$name} ) {
        die "Can't access `$name' field in class $type";
    }

    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {}

1;
