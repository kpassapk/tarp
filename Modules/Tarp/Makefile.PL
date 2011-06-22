require 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME		    => 'Tarp',
    AUTHOR		    => 'Kyle Passarelli <kyle.passarelli@gmail.com>',
    VERSION_FROM	    => 'lib/Tarp.pm',
    ABSTRACT_FROM	    => 'lib/Tarp.pm',
    PL_FILES		    => {},
    PREREQ_PM		    => {
        'Test::More'        => 0,
        'Test::Differences' => 0.4,
        'Text::CSV'         => 1.10,
        'YAML::Tiny'        => 0,
    },
    PREREQ_FATAL	    => 1,
   realclean		    => { FILES => '*.kpf' },
);
