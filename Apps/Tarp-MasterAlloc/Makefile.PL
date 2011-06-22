use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::MasterAlloc',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/MasterAlloc.pm',
    ABSTRACT_FROM       => 'lib/Tarp/MasterAlloc.pm',
    PL_FILES            => {},
    EXE_FILES           => [ 'bin/tamasteralloc' ],
    PREREQ_PM => {
        'Tarp'          => 0.82,
        'Tarp::Itexam'  => 0.8,
        'Test::More'    => 0,
    },
    realclean	  => { FILES => '*.kpf' },
);
