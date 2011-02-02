package TestDB::Result::Status;

use strict;
use warnings;
use parent 'TestDB::Base::Source';
use DateTime;

__PACKAGE__->table('status');

__PACKAGE__->add_columns(
  'status_id' => {
    data_type         => 'integer',
    is_nullable       => 0,
    is_auto_increment => 1,
  },

  'spam' => {
    data_type => 'varchar',
    size      => 30,
  },
);

__PACKAGE__->set_primary_key('status_id');

__PACKAGE__->has_many(
  email => 'TestDB::Result::Emails',
  {'foreign.status_id' => 'self.status_id'},
);


1;
