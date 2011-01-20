#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply::Core;


my $db = TestDB->test_db();
my $rs = $db->resultset('Users');
my $u;

is(
  exception {
    $u = $rs->apply(
      { name   => 'my user',
        login  => 'my_user',
        emails => [{email => 'XXX@Hot.Stuff'}],
      }
    );
  },
  undef,
  'Created user without exception'
);
is(($u->emails)[0]->email,
  'xxx@hot.stuff', '... email address lowercased as expected');


done_testing();
