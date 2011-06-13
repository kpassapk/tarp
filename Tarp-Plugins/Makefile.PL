use strict;
use warnings;
use ExtUtils::MakeMaker;
use Tarp::Config;
use File::Spec qw/catfile/;
use Cwd;

my $R = Tarp::Config->ResourceDir();
die "Tarp resource directory '$R' not installed!\n" unless -e $R;

my $lib = File::Spec->catfile( $R, "plugins" );
$lib = '"' . $lib . '"';
print $lib . "\n";

WriteMakefile(
    NAME                => 'Tarp::Plugins',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/Plugins.pm',
    ABSTRACT_FROM       => 'lib/Tarp/Plugins.pm',
    LIB                 => $lib,
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    MAN3PODS            => {}, # supress creation of man pages
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-Plugins-*' },
);
