#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply::Core;

## FIXME: need tests for has_one and might_have

my $db   = TestDB->test_db();
my $info = \&DBICx::Apply::Core::relationship_info;

my $user = $db->source('Users');
cmp_deeply(
  $info->($user, 'emails'),
  { attrs => {
      accessor       => "multi",
      cascade_copy   => 1,
      cascade_delete => 1,
      join_type      => "LEFT",
    },
    class    => "TestDB::Result::Emails",
    cond     => {"foreign.user_id" => "self.user_id"},
    name     => "emails",
    our_role => "master",
    source   => "TestDB::Result::Emails",
  },
  'Meta for has_many Users => Emails ok'
);
cmp_deeply(
  $info->($user, 'tags_per_user'),
  { attrs => {
      accessor       => "multi",
      cascade_copy   => 1,
      cascade_delete => 1,
      join_type      => "LEFT",
    },
    class    => "TestDB::Result::UsersTags",
    cond     => {"foreign.user_id" => "self.user_id"},
    name     => "tags_per_user",
    our_role => "master",
    source   => "TestDB::Result::UsersTags",
  },
  'Meta for has_many Users => UsersTags ok'
);
cmp_deeply(
  $info->($user, 'tags'),
  { link_frg_name => "tag",
    link_info     => {
      attrs => {
        accessor       => "multi",
        cascade_copy   => 1,
        cascade_delete => 1,
        join_type      => "LEFT",
      },
      class    => "TestDB::Result::UsersTags",
      cond     => {"foreign.user_id" => "self.user_id"},
      name     => "tags_per_user",
      our_role => "master",
      source   => "TestDB::Result::UsersTags",
    },
    link_name => "tags_per_user",
    our_role  => "via",
  },
  'Meta for many_to_many Users => Tags ok'
);


my $email = $db->source('Emails');
cmp_deeply(
  $info->($email, 'user'),
  { attrs => {
      accessor       => "single",
        is_foreign_key_constraint => 1,
        undef_on_null_fk => 1,
    },
    class    => "TestDB::Result::Users",
    cond     => {"foreign.user_id" => "self.user_id"},
    name     => "user",
    our_role => "slave",
    source   => "TestDB::Result::Users",
  },
  'Meta for belongs_to Emails => Users ok'
);


my $tag = $db->source('Tags');
cmp_deeply(
  $info->($tag, 'users_per_tag'),
  { attrs => {
      accessor       => "multi",
      cascade_copy   => 1,
      cascade_delete => 1,
      join_type      => "LEFT",
    },
    class    => "TestDB::Result::UsersTags",
    cond     => {"foreign.tag_id" => "self.tag_id"},
    name     => "users_per_tag",
    our_role => "master",
    source   => "TestDB::Result::UsersTags",
  },
  'Meta for has_many Tags => UsersTags ok'
);
cmp_deeply(
  $info->($tag, 'users'),
  { link_frg_name => "user",
    link_info     => {
      attrs => {
        accessor       => "multi",
        cascade_copy   => 1,
        cascade_delete => 1,
        join_type      => "LEFT",
      },
      class    => "TestDB::Result::UsersTags",
      cond     => {"foreign.tag_id" => "self.tag_id"},
      max_card => -1,
      min_card => 0,
      name     => "users_per_tag",
      our_role => "master",
      source   => "TestDB::Result::UsersTags",
    },
    link_name => "users_per_tag",
    our_role  => "via",
  },
  'Meta for many_to_many Tags => Users ok'
);

done_testing();
