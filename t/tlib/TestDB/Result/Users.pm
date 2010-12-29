package TestDB::Result::Users;

use strict;
use warnings;
use base 'DBIx::Class::Core';
use DateTime;

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
);

__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->add_unique_constraint(login_un => ['login']);

__PACKAGE__->has_many(
  emails => 'TestDB::Result::Emails',
  {'foreign.user_id' => 'self.user_id'}
);

1;
