use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME	  => 'Tarp::LaTeXtract',
    AUTHOR        => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM  => 'lib/Tarp/LaTeXtract.pm', # finds $VERSION
    PREREQ_PM	  => {
        'Tarp'	  => 0.83
    },
    EXE_FILES     => [ 'bin/talatextract' ],
    ABSTRACT_FROM => 'lib/Tarp/LaTeXtract.pm', # retrieve abstract from module
    realclean	  => { FILES => '*.kpf' }
)
