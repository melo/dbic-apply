#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply::Core;


my $db = TestDB->test_db();


subtest 'Simple cases' => sub {
  my $rs = $db->resultset('Users');
  my $u;

  is(exception { $u = $rs->apply({login => 'l', name => 'L'}) },
    undef, 'Create user, no exceptions');
  is($u->login, 'l', '... login as expected');
  is($u->name,  'L', '... name as expected');

  is(exception { $u->apply({login => 'd', name => 'D'}) },
    undef, 'Updated user, no exceptions');
  is($u->login, 'd', '... login as expected');
  is($u->name,  'D', '... name as expected');

TODO: {
    local $TODO = "__delete__ support not implemented yet";

    my $id = $u->id;
    is(exception { $u->apply({__delete__ => 1}) },
      undef, 'Deleted user, no exceptions');
    is($rs->find($id), undef, '... could not find on our DB');
  }
};


done_testing();
