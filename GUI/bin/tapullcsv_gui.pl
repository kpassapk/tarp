#!/usr/bin/perl -w

use strict;
use Tarp::PullCSV::GUI_Style;
use Tarp::PullCSV::App;

die "check options" unless @ARGV;

Tarp::PullCSV::GUI_Style->curFile( $ARGV[-1] );

unshift @ARGV, "--style=Tarp::PullCSV::GUI_Style";

Tarp::PullCSV::App->run();
