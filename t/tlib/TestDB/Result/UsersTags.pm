package TestDB::Result::UsersTags;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->load_components('+DBICx::Apply');

__PACKAGE__->table('users_tags');

__PACKAGE__->add_columns(
  'user_id' => {
    data_type   => 'integer',
    is_nullable => 0,
  },
  'tag_id' => {
    data_type   => 'integer',
    is_nullable => 0,
  },
);

__PACKAGE__->set_primary_key('user_id', 'tag_id');

__PACKAGE__->belongs_to('user', 'TestDB::Result::Users',
  {'foreign.user_id' => 'self.user_id'});
__PACKAGE__->belongs_to('tag', 'TestDB::Result::Tags',
  {'foreign.tag_id' => 'self.tag_id'});

1;
