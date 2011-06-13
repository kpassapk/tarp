use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::Burn',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/Burn.pm',
    ABSTRACT_FROM       => 'lib/Tarp/Burn.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Tarp'          => 0.82,
        'Test::More'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-Burn-*' },
);
