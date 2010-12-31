package DBICx::Apply;

# ABSTRACT: a very cool module

use strict;
use warnings;
use DBICx::Apply::Core;


sub apply {
  my ($self, $data) = @_;

  return DBICx::Apply::Core::apply($self->result_source, $data, $self);
}


############################################
# Hook the current DBIC relationship helpers

sub has_one {
  my ($self, $name, @rest) = @_;

  DBICx::Apply::Core::set_relationship_info($self, $name,
    {our_role => 'master'},
  );

  return $self->next::method($name, @rest);
}

sub belongs_to {
  my ($self, $name, @rest) = @_;

  DBICx::Apply::Core::set_relationship_info($self, $name,
    {our_role => 'slave'},
  );

  return $self->next::method($name, @rest);
}

sub might_have {
  my ($self, $name, @rest) = @_;

  DBICx::Apply::Core::set_relationship_info($self, $name,
    {our_role => 'master'},
  );

  return $self->next::method($name, @rest);
}

sub has_many {
  my ($self, $name, @rest) = @_;

  DBICx::Apply::Core::set_relationship_info($self, $name,
    {our_role => 'master'},
  );

  return $self->next::method($name, @rest);
}

sub many_to_many {
  my ($self, $name, $l_rel, $f_rel, @rest) = @_;

  DBICx::Apply::Core::set_relationship_info(
    $self, $name,
    { our_role      => 'via',
      link_name     => $l_rel,
      link_frg_name => $f_rel,
    },
  );

  return $self->next::method($name, $l_rel, $f_rel, @rest);
}

1;
