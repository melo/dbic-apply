#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply::Core;

my $db = TestDB->test_db();

subtest 'find_unique_cond' => sub {
  my $f = \&DBICx::Apply::Core::find_unique_cond;

  my $user_s = $db->source('Users');
  cmp_deeply([$f->($user_s, {})], [], 'No data, no condition found');
  is(scalar($f->($user_s, {})), undef, '... in scalar context, undef');

  cmp_deeply(
    [$f->($user_s, {login => 'x', password => 'y'})],
    ['login_un', {login => 'x'}],
    'Found login key'
  );

  cmp_deeply(
    [$f->($user_s, {user_id => 1, login => 'x', password => 'y'})],
    ['primary', {user_id => 1}],
    'Primary key takes precedence over other unique keys'
  );

  is(
    scalar($f->($user_s, {user_id => 1, login => 'x', password => 'y'})),
    'primary',
    'Primary key takes precedence over other unique keys (scalar ctx)'
  );

  my $email_s = $db->source('Emails');
  cmp_deeply(
    [$f->($email_s, {user_id => 1, email => 'x@y'})],
    ['email_per_user_un', {user_id => 1, email => 'x@y'}],
    'Multiple column unique key ok'
  );
};


subtest 'find_one_row' => sub {
  my $f     = \&DBICx::Apply::Core::find_one_row;
  my $u_src = $db->source('Users');
  my $u_rs  = $u_src->resultset;

  $u_rs->delete;
  my $u = $u_rs->create({login => 'mini_me', name => 'Mini Me'});

  my $nu = $f->($u_src, {login => 'mini_me'});
  ok($nu, 'Found user for login mini_me');
  is($nu->id, $u->id, '... with the expected ID');

  $nu = $f->($u_src, {login => 'mini_me2'});
  is($nu, undef, 'No user found for login mini_me2');
};


subtest 'Relationship Registry' => sub {
  require X;
  my $src = 'X';

  cmp_deeply([DBICx::Apply::Core::relationships($src)],
    [], 'No relationships registered by default for source');
  is(DBICx::Apply::Core::relationship_info($src, 'rel1'),
    undef, '... so no relationship_info is undef');

  is(
    exception {
      DBICx::Apply::Core::set_relationship_info($src, rel1 => {a => 1});
    },
    undef,
    'Set rel1 for new source with empty relationship_info()'
  );

  cmp_deeply([DBICx::Apply::Core::relationships($src)],
    ['rel1'], 'We have a relationship now');
  cmp_deeply(
    DBICx::Apply::Core::relationship_info($src, 'rel1'),
    {a => 1, name => 'rel1'},
    '... and relationship_info returns expected info'
  );

  require Y;
  $src = Y->new;

  is(
    exception {
      DBICx::Apply::Core::set_relationship_info($src, rel2 => {a => 1});
    },
    undef,
    'Set rel2 for source with proper relationship_info()'
  );

  cmp_deeply([DBICx::Apply::Core::relationships($src)],
    ['rel2'], 'Proper rel2 relation found');
  cmp_deeply(
    DBICx::Apply::Core::relationship_info($src, 'rel2'),
    {a => 1, b => 2, name => 'rel2'},
    '... and relationship_info returns expected merged info'
  );


  is(
    exception {
      DBICx::Apply::Core::set_relationship_info($src,
        rel3 => {a => 1, link_name => 'rel2'});
    },
    undef,
    'Set m2m rel3 for source with proper relationship_info()'
  );

  cmp_deeply(
    [DBICx::Apply::Core::relationships($src)],
    bag('rel2', 'rel3'),
    'Proper rel2+rel3 relations found'
  );
  cmp_deeply(
    DBICx::Apply::Core::relationship_info($src, 'rel3'),
    { a         => 1,
      b         => 2,
      name      => 'rel3',
      link_name => 'rel2',
    },
    '... and relationship_info returns expected merged info'
  );
};


done_testing();
