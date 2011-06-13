#!/usr/bin/perl -w
use strict;

use Test::More;
use Tarp::GenTex;
use File::Spec qw/catfile/;
use File::Copy;
use Cwd;

my @ms = ( 81825, 81826, 81827, 81828 );

plan tests => 31;

chdir "t/t21" or die "Could not cd to t/t21: $!, stopped";

$ENV{TECHARTS_TOOLKIT_DIR} = File::Spec->catfile( cwd(), "config" );

my $gtx = Tarp::GenTex->new( "4c0201.pklist" );

ok ( defined $gtx, "Constructor was successful");

foreach my $m ( @ms ) {
    ok( ! -e "ms$m.tex", "ms$m.tex does not exist" );
}

eval '$gtx->genTemplateFiles()';

ok( $@, "error produced" );
like( $@, qr/Could not open.*template/, "error looks right" );

move( "ms.tex", "ms_template.tex" )
    or die "Could not move ms.tex to ms_template.tex: $!, stopped";

eval '$gtx->genTemplateFiles()';

ok( ! $@, "no error produced" ) or diag $@;

foreach my $m ( @ms ) {
    ok( -e "ms$m.tex", "ms$m.tex exists" );
    unlink "ms$m.tex";
}

ok( ! -e "config/ms_template.tex", "template does not exist in config" );

move( "ms_template.tex", "config/templates" )
    or die "Could not move ms_template.tex to config/templates: $!, stopped";

ok( -e "config/templates/ms_template.tex", "template exists in config" );
ok( ! -e "ms_template.tex", "template not in cwd" );

eval '$gtx->genTemplateFiles()';

ok( ! $@, "got template from resource dir" );

foreach my $m ( @ms ) {
    ok( -e "ms$m.tex", "ms$m.tex exists" );
    unlink "ms$m.tex";
}

foreach my $m ( @ms ) {
    ok( ! -e "out/ms$m.tex", "out/ms$m.tex does not exist" );
}

eval '$gtx->genTemplateFiles( "out" )';

ok( ! $@, "specified outdir" );

foreach my $m ( @ms ) {
    ok( -e "out/ms$m.tex", "out/ms$m.tex exists" );
    unlink "out/ms$m.tex";
}

ok( ! -e "ms_template.tex", "template does not exist in current dir" );

move( "config/templates/ms_template.tex", "." )
    or die "Could not move ms_template.tex from config: $!, stopped";

ok( -e "ms_template.tex", "template exists in current dir" );

move( "ms_template.tex", "ms.tex" )
    or die "Could not move ms_template.tex to ms.tex: $!, stopped";
