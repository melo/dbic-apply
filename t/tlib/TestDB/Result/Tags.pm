package TestDB::Result::Tags;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('tags');

__PACKAGE__->add_columns(
  'tag_id' => {
    data_type         => 'integer',
    is_nullable       => 0,
    is_auto_increment => 1,
  },

  'tag' => {
    data_type => 'varchar',
    size      => 100,
  },
);

__PACKAGE__->set_primary_key('tag_id');
__PACKAGE__->add_unique_constraint(tag_un => ['tag']);

__PACKAGE__->has_many(users_per_tag => 'TestDB::Result::UsersTags','tag_id');
__PACKAGE__->many_to_many(users => 'users_per_tag' => 'user');


1;
