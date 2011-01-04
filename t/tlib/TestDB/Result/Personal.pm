package TestDB::Result::Personal;

use strict;
use warnings;
use parent 'TestDB::Base::Source';
use DateTime;

__PACKAGE__->table('personal');

__PACKAGE__->add_columns(
  'user_id' => {
    data_type   => 'integer',
    is_nullable => 0,
  },

  'phone' => {
    data_type => 'varchar',
    size      => 100,
  },
);

__PACKAGE__->set_primary_key('user_id');

__PACKAGE__->belongs_to(
  user => 'TestDB::Result::Users',
  {'foreign.user_id' => 'self.user_id'}
);

1;
