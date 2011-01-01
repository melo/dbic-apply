package DBICx::Apply::Core;

# ABSTRACT: a very cool module

use strict;
use warnings;
use Scalar::Util 'blessed';
use Carp;

# DBIx::Class DBIx::Class::ResultSet DBIx::Class::ResultSource

=function apply
=cut

sub apply {
  my ($source, $data, $row) = @_;

  my $split = parse_data($source, $data);
  my $fields = $split->{fields};

  if (my $rels = $split->{slave}) {
    my $extra_fields = apply_slave_role_relations($source, $rels);
    $fields = {%$fields, %$extra_fields};
  }

  $row = find_one_row($source, $fields) unless $row;
  if ($row) {
    $row->update($fields);
  }
  else {
    $row = $source->resultset->create($fields);
  }

  if (my $rels = $split->{master}) {
    apply_master_role_relations($source, $rels, $row);
  }

  return $row;
}


=function apply_slave_role_relations
=cut

sub apply_slave_role_relations {
  my ($source, $rels) = @_;
  my %frg_keys;

  for (@$rels) {
    my ($name, $data, $info) = @$_;

    $data = apply($source->related_source($name), $data)
      unless blessed($data);

    ## We use the full object and let DBIC pull the required fields; not
    ## sure if this is a good idea, but is quicker for now
    ##
    ## FIXME: $data will be undef if the apply() above deleted this
    ## object. In that case, given that this is a slave relation, we
    ## will be deleted also. We should probably set
    ## $frg_keys{__delete__} to make that happen. Still needs more real
    ## world usage before deciding proper behaviour.
    ##
    ## It would probably work fine. But I don't know yet when to apply
    ## the __delete__. Should we keep doing all slave apply()'s and only
    ## then do the __delete__? And what about relations where we are the
    ## master? should we do the apply on all those relations and leave
    ## the __delete__ on self to the very last? Or even: collect all
    ## deletes and do them in a single batch at the very end? Not sure.
    $frg_keys{$name} = $data if $data;
  }

  return \%frg_keys;
}


=function apply_master_role_relations
=cut

sub apply_master_role_relations {
  my ($source, $rels, $row) = @_;

  ## Should we use ResultSource::reverse_relationship_info here? I don't
  ## see why.
  ## On one hand, it would be easier (less code) to use: just use the
  ## reverse rel name and $row, include them in the $data, and apply()
  ## it.
  ## On the other hand, I worry about schemas where there isn't a
  ## reverse_relationship_info though. Not sure if I should worry about
  ## that corner case, but I do.
  ## I assume that the cond in this side
  ## relation is the inverse of the other side, so why bother to
  ## discover the other side? (just checked: for reverse_relationship_info
  ## the conditions must be the exact reverse of each other, so if they are
  ## why bother?)
  ## I'm sure I'm missing something and some day someone smarter will
  ## explain it to me.

  for (@$rels) {
    my ($name, $rows, $info) = @$_;

    for my $data (@$rows) {
      _merge_cond_fields($data, $info, $row);
      apply($source->related_source($name), $data);
    }
  }
}


=private _merge_cond_fields
=cut

sub _merge_cond_fields {
  my ($dest, $info, $src) = @_;

  ## Please God, make ResultSource::_resolve_condition() public again...

  my $fields = _collect_cond_fields($info);
  for my $src_f (keys %$fields) {
    ## FIXME: think of a better error message
    ## (and no, the one from _resolve_condition is not it)
    confess("Something went horribly wrong, please send me a test case :), ")
      unless $src->has_column_loaded($src_f);
    ## TODO: what if $dest is a Row object already?
    $dest->{$fields->{$src_f}} = $src->get_column($src_f);
  }

  return $dest;
}


=private _collect_cond_fields

Extract a hashref with pairs (local field => remote field) based on a
relationship condition.

=cut

sub _collect_cond_fields {
  my ($info) = @_;

  return $info->{cond_fields} if $info->{cond_fields};

  ## FIXME: deal with conditions of ArrayRef or other types
  my $cond = $info->{cond};
  confess("Unsupported relation $cond->{from} $cond->{name} type $cond, ")
    unless ref($cond) eq 'HASH';

  my %fields;
  while (my ($foreign, $self) = each %$cond) {
    $foreign =~ s/^foreign[.]//;
    $self    =~ s/^self[.]//;
    $fields{$self} = $foreign;
  }

  return $info->{cond_fields} = \%fields;
}


=function parse_data

Given a ResultSource and a data hashref, splits the fields between
columns, and the three type of relations we need: master, slave and via
(a special case for many-to-many relationships).

=cut

sub parse_data {
  my ($source, $data) = @_;
  my %splited;

  for my $f (keys %$data) {
    my $v = $data->{$f};

    if ($source->has_column($f)) {
      $splited{fields}{$f} = $v;
      next;
    }

    my $info = relationship_info($source, $f);
    croak("Name '$f' not a field or relationship of '$source'")
      unless $info;

    my $role = $info->{our_role};
    $v = [$v] unless $role eq 'slave' or ref($v) eq 'ARRAY';

    ## Convert many_to_many into a has_many
    if ($role eq 'via') {
      my $r = $info->{link_frg_name};

      $_ = {$r => $_} for @$v;

      $role = 'master';
      $f    = $info->{link_name};
      $info = relationship_info($source, $f);
    }

    push @{$splited{$role}}, [$f, $v, $info];
  }

  return \%splited;
}


=function find_unique_cond

Given a ResultSource and a hashref with fields, searches all the unique
constraints for one that could be used to find a unique row.

If the primary key is one of them, prefer it.

In scalar context, returns a hashref with the fields/values that should
be used. In list context, returns the same hashref as the first
parameter, and the name of the unique constraint found as the second.

=cut

sub find_unique_cond {
  my ($source, $data) = @_;
  my %constraints = $source->unique_constraints;

  my %cond;
  my $found;
CONSTRAINT: for my $name ('primary', keys %constraints) {
    my $c_cols = delete $constraints{$name};
    next unless $c_cols;

    %cond = ();
    for my $c (@$c_cols) {
      ## TODO: what if $data is a Row object already?
      next CONSTRAINT unless exists $data->{$c};
      $cond{$c} = $data->{$c};
    }
    $found = $name;
    last;
  }

  return unless $found;
  return ($found, \%cond) if wantarray;
  return $found;
}


=function find_one_row

Given a ResultSource and a hashref with fields, returns a single Row if
a unique row could be found based on the fields present.

Returns undef if no row was found or if the fields provided are
insuficient to satisfy any of the unique constraints defined on
the source.

=cut

sub find_one_row {
  my ($source) = @_;

  my ($key, $cond) = find_unique_cond(@_);
  return unless $cond;

  ## TODO: with key => $key, does find guarantee a single result?
  return $source->resultset->find($cond, {key => $key});
}


##########################################
# Extended relationship meta-data registry

my %rel_registry;

sub relationships {
  my ($source) = @_;
  $source = $source->result_class if blessed($source);

  return keys %{$rel_registry{$source} || {}};
}

sub relationship_info {
  my ($source, $name) = @_;
  my $source_class = $source->result_class;

  return unless exists $rel_registry{$source_class}{$name};

  my $meta = $rel_registry{$source_class}{$name};
  _relationship_info_recalc($source, $name, $meta)
    if exists $meta->{__need_recalc};

  return $meta;
}

sub _relationship_info_recalc {
  my ($source, $name, $meta) = @_;
  delete $meta->{__need_recalc};

  my $dbic_meta = $source->relationship_info($name);
  return unless $dbic_meta;

  %$meta = (%$dbic_meta, %$meta);

  return;
}

sub set_relationship_info {
  my ($source, $name, $info) = @_;
  $source = $source->result_class if blessed($source);

  $info->{name} = $name;
  $info->{from} = $source;
  $info->{__need_recalc}++;

  $rel_registry{$source}{$name} = $info;
}


1;
