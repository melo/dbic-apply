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
  { attrs => superhashof(
      { accessor       => "multi",
        cascade_copy   => 1,
        cascade_delete => 1,
        join_type      => "LEFT",
      }
    ),
    class    => "TestDB::Result::Emails",
    cond     => {"foreign.user_id" => "self.user_id"},
    name     => "emails",
    our_role => "master",
    source   => "TestDB::Result::Emails",
    from     => "TestDB::Result::Users",
  },
  'Meta for has_many Users => Emails ok'
);
cmp_deeply(
  $info->($user, 'tags_per_user'),
  { attrs => superhashof(
      { accessor       => "multi",
        cascade_copy   => 1,
        cascade_delete => 1,
        join_type      => "LEFT",
      }
    ),
    class    => "TestDB::Result::UsersTags",
    cond     => {"foreign.user_id" => "self.user_id"},
    name     => "tags_per_user",
    our_role => "master",
    source   => "TestDB::Result::UsersTags",
    from     => "TestDB::Result::Users",
  },
  'Meta for has_many Users => UsersTags ok'
);
cmp_deeply(
  $info->($user, 'tags'),
  { link_frg_name => "tag",
    link_name     => "tags_per_user",
    name          => "tags",
    our_role      => "via",
    from          => "TestDB::Result::Users",
  },
  'Meta for many_to_many Users => Tags ok'
);


my $email = $db->source('Emails');
cmp_deeply(
  $info->($email, 'user'),
  { attrs => superhashof(
      { accessor                  => "single",
        is_foreign_key_constraint => 1,
      }
    ),
    class    => "TestDB::Result::Users",
    cond     => {"foreign.user_id" => "self.user_id"},
    name     => "user",
    our_role => "slave",
    source   => "TestDB::Result::Users",
    from     => "TestDB::Result::Emails",
  },
  'Meta for belongs_to Emails => Users ok'
);


my $tag = $db->source('Tags');
cmp_deeply(
  $info->($tag, 'users_per_tag'),
  { attrs => superhashof(
      { accessor       => "multi",
        cascade_copy   => 1,
        cascade_delete => 1,
        join_type      => "LEFT",
      }
    ),
    class    => "TestDB::Result::UsersTags",
    cond     => {"foreign.tag_id" => "self.tag_id"},
    name     => "users_per_tag",
    our_role => "master",
    source   => "TestDB::Result::UsersTags",
    from     => "TestDB::Result::Tags",
  },
  'Meta for has_many Tags => UsersTags ok'
);
cmp_deeply(
  $info->($tag, 'users'),
  { link_frg_name => "user",
    link_name     => "users_per_tag",
    name          => "users",
    our_role      => "via",
    from          => "TestDB::Result::Tags",
  },
  'Meta for many_to_many Tags => Users ok'
);

done_testing();
