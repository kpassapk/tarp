--------------------------------------------------------------------------------
                      TECHARTS PERL TOOLKIT (TARP)

        Copyright (C) 2007-2009 Kyle Passarelli <kyle.passarelli@gmail.com>

--------------------------------------------------------------------------------

    Welcome to the Tarp Toolkit. The Toolkit is a set of Perl scripts,
    applications and modules designed to manipulate and extract data from
    LaTeX files.

INSTALLATION
    To install, unzip the arcihve to a temporary directory (e.g.
    c:\temp\tarp in Windows or ~/tmp/tarp in Linux. Open a command prompt
    and go to that directory. Type

        perl install.pl

    That's it.

    Installation could fail if you don't have the required modules (see "
    REQUIREMENTS " below). Otherwise everything should be hunky dory.

WHAT'S INCLUDED
    These are the three kinds of tools in the Toolkit. Here's how they work:

    Applications

        *   Stand alone command line program

        *   Tested and documented

        *   Not user editable (use plugins for flexibility)

        *   Flexible via command line options

        *   GUI applications: see "perldoc talauncher" for more.

        An application has a name begining with "ta". There is one
        application for every directory in "Apps", for example
        "talatextract" and "talatexcombine".

        You use applications by running them from the command line or
        through Komodo.

    .pl Scripts

        *   More automated, less flexible than applications

        Scripts more automated than a regular application and therefore less
        flexible. Scripts are in the "Scripts" directory of your Resource
        directory (see " GETTING STARTED " below)

        To run a script, copy it over to your current working directory,
        open it to read the instructions and then execute it.

    Modules

        *   Shared common code btw apps & scirpts

        *   Flexible, tested and documented

        *   Use to write your own script

        A module provides helpful functionality bundled into a package that
        you can use in your own scripts. They are documented and tested with
        re-use in mind. There is one or more modules in every directory in
        "Modules", for example "Tarp::Itexam".

        To learn how to use a module, load its documentation (see " GETTING
        HELP " below).

GETTING STARTED
    The best way to get started is by:

    1.  Loading a tutorial in the Tutorials/ directory.

    2.  Opening the Komodo integration and looking at the "README" pages of
        the installed applications.


--------------------------------------------------------------------------------

REQUIREMENTS
    *   A working Perl 5.010+ installation. Older Perl versions do not work
        b/c "named capture buffers" are not implemented.

    *   Third Party Perl Modules:

        "File::HomeDir"
            Available from CPAN and included in ActivePerl.

        "Text::CSV"
            Available from CPAN or through ActiveState's Perl Package
            Manager (ppm). See your Perl distribution's manual pages for
            help on installing Perl modules.

        "YAML::Tiny"
            Available from CPAN and ppm.

        "Tkx"
            GUI toolkit (wrapper for Tcl actually). This is available from
            CPAN and included in ActivePerl 5.010.

    *   GNU make, Microsoft nmake (nmake for Win32 included in the Resources
        directory)

    *   Optional Third Party Perl Modules (for development):

        "Test::Differences"
            Available from CPAN and now included in ActivePerl 5.10. Check
            to make sure you have it though.

        "Test::POD"
        
        "Test::POD::Coverage"

GETTING HELP
    Scripts contain documentation in the script file itself.

    For applications and modules, you can access on-line documentation by
    using the perldoc command:

        perldoc Tarp::[module or application]

    For example,

        perldoc Tarp::Style

    or

        perldoc talatextract      (applications only)
        perldoc Tarp::LaTeXtract

    Depending on your installation, HTML documentation may also be
    available. In ActivePerl under Windows, go to "Documentation" under the
    ActivePerl program group.

    Applications also have a brief "README" accessible through the Komodo
    integration. Open "Techarts Toolkit.kpr" in your installation directory
    (or in Windows, double click the desktop icon) and look for the "README"
    item with a yellow star.

    Finally, there are tutorials for each main task under the Tutorials
    directory of the Tarp Toolkit distribution, and sample TAS files in the
    Resource directory.

