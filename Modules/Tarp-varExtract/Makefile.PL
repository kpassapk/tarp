use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::varExtract',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/varExtract.pm',
    ABSTRACT_FROM       => 'lib/Tarp/varExtract.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Tarp' => 0.82,
        'Test::More'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-varExtract-*' },
);
