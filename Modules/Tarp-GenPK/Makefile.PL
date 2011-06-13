require 5.10.0;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::GenPK',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/GenPK.pm',
    ABSTRACT_FROM       => 'lib/Tarp/GenPK.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Tarp' => 0.82,
        'Test::More'            => 0,
        'Text::CSV'             => 1.0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-GenPK-*' },
);
