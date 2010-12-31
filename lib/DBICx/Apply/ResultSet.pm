package DBICx::Apply::ResultSet;

use strict;
use warnings;
use parent 'DBIx::Class::ResultSet';
use DBICx::Apply::Core;

sub apply {
  my ($self, $data) = @_;

  return DBICx::Apply::Core::apply($self->result_source, $data);
}

1;
