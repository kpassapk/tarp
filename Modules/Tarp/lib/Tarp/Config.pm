package Tarp::Config;

=head1 NAME

Tarp::Config - configure TARP installation

=head1 SYNOPSIS

    use Tarp::Config;
    
    $resourceDir = Tarp::Config->ResourceDir();

    $inst = Tarp::Config->InstallDir();

=cut

=head1 FUNCTIONS

=head2 ResourceDir

    (class method)
    
    $res = Tarp::Config->ResourceDir();

Returns the resource directory, or directory where some template and
configuration files can be found. This is a directory called ".tarp" in your
Home directory, or whatever the C<TECHARTS_TOOLKIT_DIR> environment variable
contains, if defined. This method does not check whether this directory actually
exists.

=cut

use strict;
use File::Spec;
use File::HomeDir;

sub ResourceDir {
    my $configDir = $ENV{TECHARTS_TOOLKIT_DIR};
    
    if ( ! $configDir  ) {
        my $home = File::HomeDir->my_home;
        $configDir = File::Spec->catfile( $home , ".tarp" );
    }

    return $configDir;    
}

=head2 InstallDir

    (class method)
    
    $inst = Tarp::Config->InstallDir();

Returns the Installation directory.  This is platform-dependent:

=over

=item Win32

    C:\\Program Files\\Tarp

=item Unix, Linux

    /opt/Tarp

=back

=cut

sub InstallDir {
    my $class = shift;
    my $installDir;
    
    if ( $^O eq "MSWin32" ) {
        $installDir = "C:\\Program Files\\Tarp";
    } else {
        $installDir = "/opt/Tarp";
    }
    return $installDir;
}

1;
