################################################################################
# TARP INSTALL SCRIPT
#
# This script installs the Tarp Toolkit.
#
# INSTRUCTIONS
#
# In order to install the Toolkit, first unpack the distribution to
# a temporary directory.  Then run the install.pl script in the command line
# (from the temporary directory):
#
#    perl install.pl
#
# ---------------------- INSTALL OPTIONS (modify below) ------------------------
#
my %installOptions = (

#   Option    #  Value                  Description
#''''''''''''''''''''''''''#''''''''''''''''''''''''''''''''''''''''''''''''''''
    force     => 1,        # Install even if tests are unsuccessful
              #            # Default is true (1).
              #            
    install   => 1,        # Install apps & modules (if zero, then the
              #            # apps & modules will only be tested, but not
              #            # actually installed). Default is true (1).
              #            
    clean     => 0,        # Do not install, only clean. Default is 0.
              #            # If this is set to 1, "install" and "force" will
              #            # be ignored.
);            #
################################################################################

# No changes below this point!

sub installAppsAndModules {
    my $installer = shift;
    
    chdir "Modules" or die "Could not cd to Modules: $!";
    
    $installer->install( "Tarp" ) or die "Sorry, installation failed. \n";
    
    my $aaok = 1;
    my $iok = $installer->install( "Tarp::GenPK" );
    $aaok &&= $iok;
    
    chdir "../Apps" or die "Could not cd to Apps: $!";

    $iok = $installer->install( qw/ Tarp::LaTeXtract / );
    $aaok &&= $iok;

    chdir "../Modules" or die "Could not cd to Modules: $!";

    $iok = $installer->install( map { "Tarp::$_" } qw/Itexam GenSkel Burn varExtract/ );
    $aaok &&= $iok;

    chdir "../Apps" or die "Could not cd to Apps: $!";

    $iok = $installer->install( map { "Tarp::$_" } qw/PullCSV MasterAlloc LaTeXcombine GenTex/ );
    $aaok &&= $iok;

    eval 'use Tkx';
    if ( ! $@ ) {
        $iok = $installer->install( "Tarp::Launcher" );
        $aaok &&= $iok;
    } else {
        warn "Tarp::Launcher skipped because Tkx is not installed\n";
    }
    chdir ( ".." );
    return $aaok;
}

sub installGUI {
    my $installer = shift;
    eval 'use Tkx';
    if ( ! $@ ) {
        return $installer->installGUI();
    } else {
        warn <<EOW;

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

         GUI not installed because it requires the 'Tkx' module

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOW
        return 1;
    }
}

sub installUserData {
    my $installer = shift;
    return $installer->installUserData();
    1;
}

sub installPlugins {
    my $installer = shift;
    return $installer->install( "Tarp::Plugins" );
}

sub installScripts {
    my $installer = shift;
    return $installer->installScripts();
}

sub printResults {
    my $installer = shift;
    $installer->printResults();
    eval "use Tarp::Config";
    die $@ if $@;
    my $logFile = File::Spec->catfile( Tarp::Config->InstallDir(), "install.log" );
    if ( open( LOG, '>', $logFile ) ) {
        #  0    1    2     3     4    5     6     7     8
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                    localtime(time);
        print LOG "Last installation $mon\/$mday\/$year at $hour:$min:$sec\n\n";
        select LOG;
        $installer->printResults();
        select STDOUT;
        close LOG;
        print "Summary also written to $logFile\n";
    }
    1;
}

sub showReleaseNotes {
    eval 'use ActiveState::Browser';
    if ( ! $@ ) {
        my $f = File::Spec->catfile( cwd(), "Resources", "Installer", "README.html" );
        if ( ActiveState::Browser::can_open( $f ) ) {
            ActiveState::Browser::open( $f );
        }
    }
    1;
}

BEGIN {
    use Cwd;
    our $directory = cwd;
    use File::Spec;
    our $libDir = File::Spec->catfile( $directory, "Resources", "Installer", "lib" );    
}

use lib $libDir;
use Tarp::Installer2;

my @ACTIONS = (
    \&installAppsAndModules,    # 0
    \&installUserData,          # 1
    \&installPlugins,           # 2
    \&installScripts,           # 3
    \&installGUI,               # 4
    \&printResults,             # 5
    \&showReleaseNotes          # 6
);

my $steps = "0..6";
if ( @ARGV ) {
    
    if ( $ARGV[0] eq "--help" ) {
        print <<INSTS;
usage: install.pl [steps]

Steps:
    installAppsAndModules,    # 0
    installUserData,          # 1
    installPlugins,           # 2
    installScripts,           # 3
    installGUI,               # 4
    printResults,             # 5
    showReleaseNotes          # 6

INSTS
        exit 2;
    } else {
        $steps = shift;
        my @s;
        eval "\@s = ( $steps )";
        die "Invalid range: '$steps', stopped" if $@;
        print "@s\n";
        while ( @s > 1 ) {
            die "Out of order instruction: $steps, stopped"
                if ( $s[1] < shift @s );
        }
    }
}

my @DO;

if ( $installOptions{ "clean" } ) {
    @DO = @ACTIONS[ 0, 2 ]; # Only install (clean) apps & modules
} else {
    eval "\@DO = \@ACTIONS[ $steps ]";
    die "Invalid range: '$steps', stopped" if $@;
}

$| = 1; # Flush output buffers with print()

my $installer = Tarp::Installer2->new( \%installOptions );

$installer->printHeading();

my $aaaok = 1;

for my $act ( @DO ) {
    my $ok = &$act( $installer );
    $aaaok &&= $ok;
}

unless ( $aaaok ) {
    print <<MSG
    
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

At least one install step failed.  Please email Kyle and ask him to get his
act together. Have a nice day.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MSG
} else {
    print <<MSG

Install completed successfully.

MSG
}
