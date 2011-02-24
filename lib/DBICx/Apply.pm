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
  my $self = shift;

  return $self->_simple_rel($self->next::can, 'master', @_);
}

sub belongs_to {
  my $self = shift;

  return $self->_simple_rel($self->next::can, 'slave', @_);
}

sub might_have {
  my $self = shift;

  return $self->_simple_rel($self->next::can, 'master', @_);
}

sub has_many {
  my $self = shift;

  return $self->_simple_rel($self->next::can, 'master', @_);
}

sub many_to_many {
  my ($self, $n, $l_rel, $f_rel, @rest) = @_;

  DBICx::Apply::Core::set_relationship_info(
    $self, $n,
    { our_role      => 'via',
      link_name     => $l_rel,
      link_frg_name => $f_rel,
    },
  );

  return $self->next::method($n, $l_rel, $f_rel, @rest);
}

sub _simple_rel {
  my ($self, $nm, $role, $n, @rest) = @_;

  DBICx::Apply::Core::set_relationship_info($self, $n, {our_role => $role});

  return $nm->($self, $n, @rest);
}


1;
