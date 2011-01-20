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


my @test_cases = (
  'empty'     => {},
  'undef'     => {alias => undef},
  'empty_str' => {alias => ''},
);

while (@test_cases) {
  my ($name, $alias) = splice(@test_cases, 0, 2);

  is(exception { $u->apply({alias => {alias => 'xpto'}}) },
    undef, "Prepare '$name' test for aliases");
  is($u->count_related('alias'), 1, '... one alias as expected');
  is($u->alias->alias, 'xpto', '...... and the expected alias was found');

  is(
    exception {
      $u->apply({alias => $alias});
    },
    undef,
    '... alias removal applied without exception'
  );
  is($u->count_related('alias'), 0, '...... alias was removed');
}


done_testing();
