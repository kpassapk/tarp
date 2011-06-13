use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::Itexam',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/Itexam.pm',
    ABSTRACT_FROM       => 'lib/Tarp/Itexam.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Tarp' => 0.82,
        'Tarp::LaTeXtract' => 0.82,
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-Itexam-*' },
);
