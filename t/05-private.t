#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply;

my $db = TestDB->test_db();

subtest '__apply_find_unique_cond' => sub {
  my $f = \&DBICx::Apply::__apply_find_unique_cond;

  my $user_s = $db->source('Users');
  cmp_deeply([$f->($user_s, {})], [], 'No data, no condition found');
  is(scalar($f->($user_s, {})), undef, '... in scalar context, undef');

  cmp_deeply(
    [$f->($user_s, {login => 'x', password => 'y'})],
    [{login => 'x'}, 'login_un'],
    'Found login key'
  );

  cmp_deeply(
    [$f->($user_s, {user_id => 1, login => 'x', password => 'y'})],
    [{user_id => 1}, 'primary'],
    'Primary key takes precedence over other unique keys'
  );

  my $email_s = $db->source('Emails');
  cmp_deeply(
    [$f->($email_s, {user_id => 1, email => 'x@y'})],
    [{user_id => 1, email => 'x@y'}, 'email_per_user_un'],
    'Multiple column unique key ok'
  );
};

done_testing();
