#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use Test::Compile;

my @pm = (all_pm_files('t/tlib'), all_pm_files());
all_pm_files_ok(@pm);

done_testing();
