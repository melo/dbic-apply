package TestDB::Result::Users;

use strict;
use warnings;
use parent 'TestDB::Base::Source';

__PACKAGE__->table('users');

__PACKAGE__->add_columns(
  'user_id' => {
    data_type         => 'integer',
    is_nullable       => 0,
    is_auto_increment => 1,
  },

  'name' => {
    data_type => 'varchar',
    size      => 100,
  },

  'login' => {
    data_type   => 'varchar',
    size        => 100,
    is_nullable => 0,
  },

  'password' => {
    data_type   => 'varchar',
    size        => 40,
    is_nullable => 1,
  },

  'active_email_id' => {
    data_type   => 'integer',
    is_nullable => 1,
  }
);

__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->add_unique_constraint(login_un => ['login']);

__PACKAGE__->might_have(
  personal => 'TestDB::Result::Personal',
  {'foreign.user_id' => 'self.user_id'}
);


__PACKAGE__->might_have(alias => 'TestDB::Result::Aliases', 'user_id');


__PACKAGE__->has_many(emails => 'TestDB::Result::Emails', 'user_id');
__PACKAGE__->belongs_to(
  active_email => 'TestDB::Result::Emails',
  { 'foreign.email_id' => 'self.active_email_id',
    'foreign.user_id'  => 'self.user_id'
  },
  { on_delete  => 'set null',
    join_type  => 'left',
    master_rel => 'emails',
  },
);


__PACKAGE__->has_many(
  tags_per_user => 'TestDB::Result::UsersTags',
  'user_id'
);
__PACKAGE__->many_to_many(tags => 'tags_per_user' => 'tag');

1;
