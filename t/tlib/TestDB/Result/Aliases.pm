package TestDB::Result::Aliases;

use strict;
use warnings;
use parent 'TestDB::Base::Source';

__PACKAGE__->table('aliases');

__PACKAGE__->add_columns(
  'user_id' => {
    data_type   => 'integer',
    is_nullable => 0,
  },

  'alias' => {
    data_type   => 'varchar',
    size        => 100,
    is_nullable => 0,
  },
);

__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->add_unique_constraint(alias_un => ['alias']);

__PACKAGE__->belongs_to(user => 'TestDB::Result::Users', 'user_id');


sub _dbicx_apply_impl {
  my ($class, $source, $f, $row, $def) = @_;

  return $def->($source, $f, $row)
    if exists($f->{alias}) && defined($f->{alias}) && length($f->{alias});

  $row->delete if $row;

  return;
}


1;
