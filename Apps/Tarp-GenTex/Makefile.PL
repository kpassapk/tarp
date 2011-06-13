require 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::GenTex',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/GenTex.pm',
    ABSTRACT_FROM       => 'lib/Tarp/GenTex.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Tarp'              => 0.82,
        'Tarp::Itexam'      => 0.21,
        'Test::More'        => 0,
    },
    EXE_FILES           => [ 'bin/tagentex' ],
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-GenTex-*' },
);
