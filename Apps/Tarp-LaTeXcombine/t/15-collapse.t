#!perl

use Test::More tests => 10;
use Data::Dumper;

use Tarp::LaTeXcombine;
use Tarp::LaTeXcombine::PickupFile;
use Tarp::LaTeXcombine::VirtualPickup;

my $case = 1;

sub doTest {
    my $f = shift;
    my $pickups = shift;
    my $testDir = "c" . sprintf "%02d", $case++;
    my $testName = $testDir . ': ' . shift || "$testDir output";
    
    chdir $testDir or die "Could not cd to $testDir: $!, stopped";
    
    my @collapsed = $f->collapsedInstructions( %$pickups );

    local $/;
    undef $/;
    open EXP, "expected.txt"
        or die "Could not open 'expected.txt' for reading: $!, stopped";
    my $exp = <EXP>;
    close EXP;
    my ( $expData ) = eval "$exp";
    die "Could not eval 'expected.txt': $@" if $@;
    
    is_deeply( [ @collapsed ], $expData, $testName )
        or diag "Got the following:\n" . Dumper [ @collapsed ];
    $f->clear();
    chdir "..";
}

chdir "t/t15" or die "Could not chdir to t/t15: $!, stopped";

my $f = Tarp::LaTeXcombine->new();
ok( $f->style()->load( "in.tas" ), "style load" )
    or diag $f->style()->errStr();

my $new = Tarp::LaTeXcombine::VirtualPickup->new();
my $foo = Tarp::LaTeXcombine::PickupFile->new( "in/foo.tex" );
$foo->style( $f->style() );
ok( $foo->load(), "foo load" );

my $bar = Tarp::LaTeXcombine::PickupFile->new( "in/bar.tex" );
$bar->style( $f->style() );
ok( $bar->load(), "bar load" );

my %pickups = (
    foo => $foo,
    bar => $bar,
    new => $new,
);

my @is = (
    [ qw/01a foo 01a/ ],
    [ qw/01b foo 01b/ ],
    [ qw/01c foo 01c/ ],
    [ qw/02a foo 02a/ ],
    [ qw/02b foo 02b/ ],
    [ qw/02c foo 02c/ ],
);

for ( @is ) {
    $f->instruction( @$_ );
}

doTest( $f, \%pickups, "complete, one-to-one 1pk" );

# Using two pickup files, problems 1 and 2 should collapse.
@is = (
    [qw/01a foo 01a/],
    [qw/01b foo 01b/],
    [qw/01c foo 01c/],
    [qw/02a bar 02a/],
    [qw/02b bar 02b/],
    [qw/02c bar 02c/]
);

for ( @is ) {
    $f->instruction( @$_ );
}

doTest( $f, \%pickups, "complete, one-to-one 2pk");

@is = (
    [ qw/01a foo 01a/ ],
    [ qw/01b foo 01b/ ],
    [ qw/01c new/     ]
);

for ( @is ) {
    $f->instruction( @$_ );
}

# c03
doTest( $f, \%pickups, "(1) refs to virtual pickup");

@is = (
    [ qw/01a foo 01a/ ],
    [ qw/01b foo 01b/ ],
    [ qw/01c bar 01c/ ]
);

for ( @is ) {
    $f->instruction( @$_ );
}

#c04
doTest( $f, \%pickups, "(2) not one-to-one, complete");

@is = (
    [ qw/01a foo 01a/ ],
    [ qw/01b foo 01c/ ],
    [ qw/01c foo 01b/ ]
);

for ( @is ) {
    $f->instruction( @$_ );
}

# c05
doTest( $f, \%pickups, "(3) not one-to-one, complete");

@is = (
    [ qw/01a foo 01a/ ],
    [ qw/01b foo 01b/ ],
    [ qw/02a foo 01c/ ]
);

for ( @is ) {
    $f->instruction( @$_ );
}

doTest( $f, \%pickups, "(4) not one-to-one, complete");

@is = (
    [ qw/01a foo 01a/ ],
    [ qw/01b foo 01b/ ],
);

for ( @is ) {
    $f->instruction( @$_ );
}

doTest( $f, \%pickups, "(5) one-to-one, incomplete");
