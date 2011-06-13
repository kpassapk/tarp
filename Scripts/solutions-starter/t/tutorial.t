#!perl

BEGIN {
    use Cwd;
    our $directory = cwd;
    use File::Spec;
    our $libDir = File::Spec->catfile( $directory, "..", "Resources", "lib" );    
}

use lib $libDir;
use File::Copy;
use Test::More tests => 30;
use File::Copy::Recursive qw/dircopy pathrmdir/;

mkdir "t/tut";

diag "Testing solutions-starter.pl with tutorial files";
my $tut_dir = "../../Tutorials/Generating\ Solutions";

dircopy $tut_dir, "t/tut" or die "Could not copy $tut_dir to t: $!, stopped";
copy "solutions-starter.pl", "t/tut" or die "could not copy solutions-starter.pl to t: $!, stopped";
copy "solutions-starter.tas", "t/tut" or die "could not copy solutions-starter.tas to t: $!, stopped";

$| = 1;

diag "Copied tutorial files OK";

chdir "t/tut" or die "Could not chdir to t/tut: $!, stopped";

ok( ! -e "BOOK-CONFIG.yml", "no book.yml initially" );

ok( -e "solutions-starter.pl", "script exists" );

# ********************      Run 1        ***************************************

system( "perl solutions-starter.pl 2>&1 1>tmpfile" ) == 0
    or die "system solutions-starter.pl failed: $?";

# Should have created BOOK-CONFIG.yml

{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/Wrote BOOK-CONFIG.yml/, "stdout 1" );
}

ok( -e "BOOK-CONFIG.yml", "created BOOK-CONFIG.yml" );

use YAML::Tiny;

my $yaml = YAML::Tiny->read( "BOOK-CONFIG.yml" );

ok( $yaml, "script wrote a real YAML file" )
    or diag(  YAML::Tiny->errstr() );

is_deeply( $yaml, [{
      'Current chapter' => '1',
      'Pickup paths' => [
                          'C:\\path\\to\\pickup_files or \\server\\path\\to\\pickup_files'
                        ],
      'Manuscript path' => 'C:\\path\\to\\manuscript or \\server\\path\\to\\manuscript'
    }
], "BOOK-CONFIG data ok" );

$yaml->[0]->{"Current chapter"} = "01";
$yaml->[0]->{"Pickup paths"} = [ 'My Pickup Books' ];
$yaml->[0]->{"Manuscript path"} = '4foo Manuscript';

ok( $yaml->write( "BOOK-CONFIG.yml" ), "edited BOOK-CONFIG.yml" )
    or diag( YAML::Tiny->errstr() );

ok( ! -e "01/CHAPT-CONFIG.yml", "no CHAPT-CONFIG.yml" );
ok( ! -e "01/4foo0101.pklist",  "no 4foo0101.pklist" );
ok( ! -e "01/4foo0102.pklist",  "no 4foo0102.pklist" );

# ********************      Run 1        ***************************************

# Should have created CHAPT-CONFIG.yml
# and two pickup lists.

system( "perl solutions-starter.pl 2>&1 1>tmpfile" ) == 0
    or die "system solutions-starter.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/Wrote 4foo0101.pklist/, "stdout 2: wrote 3foo0101.pklist" );
    like( $out, qr/Wrote 4foo0102.pklist/, "stdout 2: wrote 3foo0102.pklist" );
    like( $out, qr/Wrote CHAPT-CONFIG.yml/, "stdout 2: wrote CHAPT-CONFIG.yml" );
}

#system( "perl", "solutions-starter.pl" ) == 0
#    or die "system solutions-starter.pl failed: $?";


ok( -e "01/CHAPT-CONFIG.yml", "created CHAPT-CONFIG.yml" );
ok( -e "01/4foo0101.pklist",  "created 4foo0101.pklist" );
ok( -e "01/4foo0102.pklist",  "created 4foo0102.pklist" );

my $foo0101 = <<END_OF_STR;
01a 3foo 01a 00001
01b 3bar 01b 00002
02a 3bar_2 02 00003
02b 3bar_2 03 00004
03 new .. 00005
END_OF_STR

my $foo0102 = <<END_OF_STR;
01a 3foo_2 01a 00006
01b 3foo_2 01b 00007
END_OF_STR

eval "use Test::Differences";

SKIP: {
    skip 2, "Test::Differences required for these tests"
        if $@;

    local $/;
    my @pklists = map { "01/4foo010$_.pklist" } qw/1 2/;
    my @pklines = ();
    foreach ( @pklists ) {
        open PK, $_ or die "could not open $_ for reading: $!";
        push @pklines, <PK>;
        close PK;
    }
    eq_or_diff( $foo0101, $pklines[0], "4foo0101 ok" );
    eq_or_diff( $foo0102, $pklines[1], "4foo0102 ok" );
}

$yaml = YAML::Tiny->read( "01/CHAPT-CONFIG.yml" );

ok( $yaml, "script wrote a real YAML file" )
    or diag(  YAML::Tiny->errstr() );

use Data::Dumper;
# print Dumper $yaml;

is_deeply( $yaml, [{
  'Manuscript master file' => '4foo0100.tex',
  'Pickup files' => {
                      '01' => {
                                '3bar' => '3bar0101.tex',
                                'new' => '(virtual)',
                                '3foo' => '3foo0101.tex',
                                '3bar_2' => '3bar0102.tex'
                              },
                      '02' => {
                                '3foo_2' => '3foo0102.tex'
                              }
                    }
}], "CHAPT-CONFIG data" );

# ********************      Run 3        ***************************************

# Should have copied pickup files and gotten titles

system( "perl solutions-starter.pl 2>&1 1>tmpfile" ) == 0
    or die "system solutions-starter.pl failed: $?";
{
    local $/;
    open( OUT, '<tmpfile' ) or die "Could not open tmpfile: $!";
    my $out = <OUT>;
    close OUT;
    like( $out, qr/Copied.*3foo0101.tex/, "stdout 3: copied 3foo0101.tex" );
    like( $out, qr/Copied.*3foo0102.tex/, "stdout 3: copied 3foo0102.tex" );
    like( $out, qr/Copied.*3bar0101.tex/, "stdout 3: copied 3foo0102.tex" );
    like( $out, qr/Copied.*3bar0102.tex/, "stdout 3: copied 3foo0102.tex" );
}

my @pks = ( map( { "01/3foo010$_.tex" } qw/1 2/ ), map( { "01/3bar010$_.tex" } qw/1 2/ ) );

foreach ( @pks ) {
    ok( -e $_, "$_ pickup copied" );
}

$yaml = YAML::Tiny->read( "01/CHAPT-CONFIG.yml" );

ok( $yaml, "script wrote a real YAML file" )
    or diag(  YAML::Tiny->errstr() );

# use Data::Dumper;
# print Dumper $yaml;

is_deeply( $yaml, [{
      'titles' => {
                    '01' => {
                              'SECT_TITLE' => 'Modeling with Differential Equations',
                              'CHAP_TITLE' => 'Differential Equations'
                            },
                    '02' => {
                              'SECT_TITLE' => 'Direction Fields and Euler\'s Method',
                              'CHAP_TITLE' => 'Differential Equations'
                            }
                  },
      'Manuscript master file' => '4foo0100.tex',
      'Pickup files' => {
                          '01' => {
                                    '3bar' => '3bar0101.tex',
                                    'new' => '(virtual)',
                                    '3foo' => '3foo0101.tex',
                                    '3bar_2' => '3bar0102.tex'
                                  },
                          '02' => {
                                    '3foo_2' => '3foo0102.tex'
                                  }
                        }
    }], "yaml file got titles" ) or diag Dumper( $yaml );

unlink "BOOK-CONFIG.yml" or warn "Could not remove BOOK-CONFIG.yml: $!";
unlink "01/CHAPT-CONFIG.yml" or warn "Could not remove CHAPT-CONFIG.yml: $!";

chdir "..";
pathrmdir( "tut" or die "could not remove 'tut': $!, stopped" );
