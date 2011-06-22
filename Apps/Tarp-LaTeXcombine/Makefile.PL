use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::LaTeXcombine',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/LaTeXcombine.pm',
    ABSTRACT_FROM       => 'lib/Tarp/LaTeXcombine.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Tarp'            => 0.86,
        'Tarp::MasterAlloc' => 0.8,
        'Tarp::GenSkel'   => 0.42,
        'Tarp::Itexam'    => 0.8,
        'Test::More'      => 0,
    },
    EXE_FILES           => [ 'bin/talatexcombine' ],
    realclean           => { FILES => '*.kpf' }
);
