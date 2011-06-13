use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::Launcher',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/Launcher.pm',
    ABSTRACT_FROM       => 'lib/Tarp/Launcher.pm',
    EXE_FILES           => [ 'bin/talauncher' ],
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'ActiveState::Browser' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-Launcher-*' },
);
