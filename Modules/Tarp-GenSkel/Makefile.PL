use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::GenSkel',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/GenSkel.pm',
    ABSTRACT_FROM       => 'lib/Tarp/GenSkel.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'            => 0,
        'Tarp::LaTeXtract'  => 0.37,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp::GenSkel-*' },
);
