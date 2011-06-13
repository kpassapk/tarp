use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Tarp::PullCSV',
    AUTHOR              => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM        => 'lib/Tarp/PullCSV.pm',
    ABSTRACT_FROM       => 'lib/Tarp/PullCSV.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Tarp::Itexam' => 0.8,
    },
    EXE_FILES           =>  [ 'bin/tapullcsv' ],
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Tarp-PullCSV-*' },
);
