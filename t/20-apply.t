#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply::Core;


subtest 'Simple cases' => sub {
  my $db = TestDB->test_db();
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


subtest 'Cases with a slave relationship' => sub {
  my $db = TestDB->test_db();
  my $rs = $db->resultset('Emails');
  my ($e, $u);

  ## create - create
  is(
    exception {
      $e = $rs->apply(
        { email => 'create_create@slaves',
          user  => {login => 'l', name => 'L'}
        }
      );
    },
    undef,
    'Create email with user, no exceptions'
  );
  is($e->email, 'create_create@slaves', '... email as expected');
  $u = $e->user;
  is($u->login, 'l', '... login as expected');
  is($u->name,  'L', '... name as expected');

  ## create - find
  is(
    exception {
      $e =
        $rs->apply({email => 'create_find@slaves', user => {login => 'l'}});
    },
    undef,
    'Create email with existing user, no exceptions'
  );
  is($e->email, 'create_find@slaves', '... email as expected');
  $u = $e->user;
  is($u->login, 'l', '... login as expected');
  is($u->name,  'L', '... name as expected');

  ## create - update
  is(
    exception {
      $e = $rs->apply(
        { email => 'create_update@slaves',
          user  => {login => 'l', name => 'D'}
        }
      );
    },
    undef,
    'Create email with existing user, update it, no exceptions'
  );
  is($e->email, 'create_update@slaves', '... email as expected');
  $u = $e->user;
  is($u->login, 'l', '... login as expected');
  is($u->name,  'D', '... name as expected');

  ## update - update
  is(
    exception {
      $e->apply(
        { email => 'update_update@slaves',
          user  => {login => 'l', name => 'Y'}
        }
      );
    },
    undef,
    'Update email and update user, no exceptions'
  );
  is($e->email, 'update_update@slaves', '... email as expected');
  $u = $e->user;
  is($u->login, 'l', '... login as expected');
  is($u->name,  'Y', '... name as expected');

  ## update - update with incomplete pk
TODO: {
    local $TODO = 'user data lacks unique keys; should find from email first';
    is(
      exception {
        $e->apply(
          { email => 'update_update_incomplete@slaves',
            user  => {name => 'Z'}
          }
        );
      },
      undef,
      'Update email and update user, no exceptions'
    );
    is($e->email, 'update_update_incomplete@slaves', '... email as expected');
    $u = $e->user;
    is($u->login, 'l', '... login as expected');
    is($u->name,  'Z', '... name as expected');
  }
};


done_testing();
