package DBICx::Apply;

# ABSTRACT: a very cool module

use strict;
use warnings;
use DBICx::Apply::Core;


############################################
# Hook the current DBIC relationship helpers

*__apply_set_relationship_info = \&DBICx::Apply::Core::__apply_set_relationship_info;

sub has_one {
  my ($self, $name, @rest) = @_;

  $self->__apply_set_relationship_info(
    $name,
    { our_role => 'master',
      min_card => 1,
      max_card => 1,
    },
  );

  return $self->next::method($name, @rest);
}

sub belongs_to {
  my ($self, $name, @rest) = @_;

  $self->__apply_set_relationship_info(
    $name,
    { our_role => 'slave',
      min_card => 0,
      max_card => 1,
    },
  );

  return $self->next::method($name, @rest);
}

sub might_have {
  my ($self, $name, @rest) = @_;

  $self->__apply_set_relationship_info(
    $name,
    { our_role => 'master',
      min_card => 0,
      max_card => 1,
    },
  );

  return $self->next::method($name, @rest);
}

sub has_many {
  my ($self, $name, @rest) = @_;

  $self->__apply_set_relationship_info(
    $name,
    { our_role => 'master',
      min_card => 0,
      max_card => -1,
    },
  );

  return $self->next::method($name, @rest);
}

sub many_to_many {
  my ($self, $name, $l_rel, $f_rel, @rest) = @_;

  $self->__apply_set_relationship_info(
    $name,
    { our_role      => 'via',
      link_name     => $l_rel,
      link_frg_name => $f_rel,
      min_card      => 0,
      max_card      => -1,
    },
  );

  return $self->next::method($name, $l_rel, $f_rel, @rest);
}

1;
