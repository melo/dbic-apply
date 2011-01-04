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
  is($u->login,         'l', '... login as expected');
  is($u->name,          'L', '... name as expected');
  is($u->emails->count, 1,   '... user has 1 emails now');

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
  is($u->login,         'l', '... login as expected');
  is($u->name,          'L', '... name as expected');
  is($u->emails->count, 2,   '... user has 2 emails now');

  ## create - object
  is(
    exception {
      $e = $rs->apply({email => 'create_obj@slaves', user => $u});
    },
    undef,
    'Create email with existing user object, no exceptions'
  );
  is($e->email, 'create_obj@slaves', '... email as expected');
  $u = $e->user;
  is($u->login,         'l', '... login as expected');
  is($u->name,          'L', '... name as expected');
  is($u->emails->count, 3,   '... user has 3 emails now');

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


subtest 'might_have cases' => sub {
  my $db = TestDB->test_db();
  my $rs = $db->resultset('Users');
  my $u;

  is(
    exception {
      $u = $rs->apply(
        { login    => 'l',
          name     => 'L',
          personal => {phone => '1 800 BITE ME'}
        }
      );
    },
    undef,
    'Create user + personal, no exceptions'
  );
  is($u->login,           'l',             '... login as expected');
  is($u->name,            'L',             '... name as expected');
  is($u->personal->phone, '1 800 BITE ME', '... phone as expected');

  is(
    exception {
      $u->apply({personal => {phone => '+1 800 BITE ME (ext HARD)'}});
    },
    undef,
    'Updated user personal data, no exceptions'
  );
  $u->discard_changes;
  is($u->personal->phone, '+1 800 BITE ME (ext HARD)', '... phone updated');
};


subtest 'has_many cases' => sub {
  my $db = TestDB->test_db();
  my $rs = $db->resultset('Users');
  my $u;

  is(
    exception {
      $u = $rs->apply(
        { login  => 'l',
          name   => 'L',
          emails => [{email => 'l@me'}, {email => 'l@you'}]
        }
      );
    },
    undef,
    'Create user + emails, no exceptions'
  );
  is($u->login,         'l', '... login as expected');
  is($u->name,          'L', '... name as expected');
  is($u->emails->count, 2,   '... two emails as expected');

  is(exception { $u->apply({emails => [{email => 'l@them'}]}) },
    undef, 'Updated user emails, no exceptions');
  is($u->emails->count, 3, '... three emails as expected');

TODO: {
    local $TODO = "__delete__ support not implemented yet";

    my $id = $u->id;
    is(exception { $u->apply({__delete__ => 1}) },
      undef, 'Deleted user, no exceptions');
    is($rs->find($id), undef, '... could not find on our DB');
    is($db->resultset('Emails')->search({user_id => $id})->count,
      0, '... all emails also deleted (cascading delete)');
  }
};


subtest 'All together now' => sub {
  my $db = TestDB->test_db();
  my $e;

  is(
    exception {
      $e = $db->resultset('Emails')->apply(
        { email => 'me@first',
          user  => {
            login => 'me',
            name  => 'Mini Me',
            tags => [{tag => 'pretty'}, {tag => 'awesome'}, {tag => 'stuff'}],
            emails => [
              {email => 'me@second'},
              {email => 'me@third', active_for => {}}
            ],
            personal => {phone => '+1 800 GAME ON'},
          }
        }
      );
    },
    undef,
    'Mega email create, no exceptions'
  );

  $e->discard_changes;
  is($e->email, 'me@first', '... expected email at root object');

  my $u = $e->user;
  ok($u, '... got a user to go with the email');
  is($u->login,         'me',      '...... login as expected');
  is($u->name,          'Mini Me', '...... name as expected');
  is($u->emails->count, 3,         '...... three emails for this user');
  is($u->tags->count,   3,         '...... and three tags');
  is($u->personal->phone, '+1 800 GAME ON', '...... phone as expected');
  is($u->active_email->email, 'me@third', '...... active_email as expected');
};


done_testing();
