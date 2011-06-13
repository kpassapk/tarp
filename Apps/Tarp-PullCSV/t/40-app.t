#!perl

use Test::More;
use IO::File;
use File::Copy;
use Cwd;

use Tarp::PullCSV::App;

use Tarp::Test::Files;

plan tests => 6;

chdir ( "t/t40" ) or die "Could not chdir to t40: $!";

my $icase = 1;

sub runTest {
    Tarp::PullCSV::App->run();
}


my $t = Tarp::Test::Files->new();
$t->generator( [ \&runTest ] );

$ENV{TECHARTS_TOOLKIT_DIR} = cwd;

## Start of tests

move( "toolPrefs.yml", "prefs.yml" );

my @COMMON = ( "--force", "--silent", "--out=out/dataout.csv" );

@ARGV = ( @COMMON, "in/datain.tex" );

# Columns sorted alphabetically
$t->case(); # c01

@ARGV = ( @COMMON,
          "--col=master",
          "--col=book;myBook",
          "--col=chapter;myChapter",
          "--col=section;foo,bar",
          "--col=exercise",
          "in/datain.tex" );

# Specify a column order and all options

$t->case(); # c02

@ARGV = (
    @COMMON,
    "--col=section;foo,bar",
    "--col=exercise",
    "--col=book;myBook",
    "--col=master",
    "--col=chapter;myChapter",
    "in/datain.tex" );

# Specify everything but change column order

$t->case(); # c03

@ARGV = ( @COMMON,
         "--col=master",
          "--col=book",
          "--col=chapter",
          "--col=section;bar,bat",
          "--col=exercise",
          "in/foo0201.tex" );

# Specify section but not book or chapter. These are loaded from the filename.

$t->case(); # c04

@ARGV = (
    @COMMON,
    "--col=master",
    "--col=book",
    "--col=chapter",
    "--col=section;bar,bat",
    "--col=exercise",
    "--append",
    "in/foo0201.tex",
);

copy( "c05/out/dataout.csv", "c05/out/dataout.old" );

$t->case(); # c05

copy( "c05/out/dataout.old", "c05/out/dataout.csv" );

move( "prefs.yml", "toolPrefs.yml" );

@ARGV = (
    @COMMON,
    "in/datain.tex" );

# Now the column order should be right (because we read it from toolPrefs.yml)

$t->case(); # c06

move( "toolPrefs.yml", "prefs.yml" );
