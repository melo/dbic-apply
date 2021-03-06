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

  my $split  = parse_data($source, $data);
  my $fields = $split->{fields};
  my $action = $split->{action};

  if (my $rels = $split->{slave}) {
    my $extra_fields =
      apply_slave_role_relations($source, $rels, $row, $fields);
    $fields = {%$fields, %$extra_fields};
  }

  my $target = $source->result_class;
  $fields = $target->_dbicx_apply_filter($source, $fields, $row)
    if $target->can('_dbicx_apply_filter');

  $row = find_one_row($source, $fields) unless $row;
  if ($target->can('_dbicx_apply_impl')) {
    $row = $target->_dbicx_apply_impl($source, $fields, $row, $action,
      \&_do_apply_on_row);
  }
  else {
    $row = _do_apply_on_row($source, $fields, $row, $action);
  }

  if ($row) {
    my $rels;
    if ($rels = $split->{master}) {
      apply_master_role_relations($source, $rels, $row);
    }
    if ($rels = $split->{fake_master}) {
      my $frgn_keys = apply_fake_master_role_relations($source, $rels, $row);
      $row->update($frgn_keys) if $frgn_keys && %$frgn_keys;
    }
  }

  return $row;
}


sub _do_apply_on_row {
  my ($source, $fields, $row, $action) = @_;

  if ($action eq 'ADD') {
    if ($row) {
      $row->update($fields) if %$fields;
    }
    else {
      $row = $source->resultset->create($fields);
    }
  }
  elsif ($action eq 'CREATE') {
    $row = $source->resultset->create($fields);
  }
  elsif ($action eq 'DEL') {
    $row->delete if $row;
    $row = undef;
  }
  elsif ($action eq 'IGN') { }
  else {
    confess("apply() does not recognize __ACTION '$action',");
  }

  return $row;
}


=function apply_slave_role_relations
=cut

sub apply_slave_role_relations {
  my ($source, $rels, $row, $fields) = @_;
  my %frg_keys;

  for (@$rels) {
    my ($name, $data, $info) = @$_;
    my $rel_source = $source->related_source($name);

    if (!blessed($data)) {
      my $action = $data->{__ACTION} ||= 'ADD';

      my %rel_fields = %$data;
      if ($action ne 'CREATE') {
        ## Complete keys from slave side in case $data is not enough to
        ## identify master row
        for my $src ($fields, $row) {
          my ($key) = find_unique_cond($rel_source, \%rel_fields);
          last if $key;

          _merge_cond_fields(\%rel_fields, $info, $src);
        }
      }

      $data = apply($rel_source, \%rel_fields);
    }
    else {
      ## FIXME: is this case possible?
    }

    ## FIXME: $data will be undef if the apply() above deleted this
    ## object. In that case, given that this is a slave relation, we
    ## will be deleted also. We should probably set $frg_keys{__ACTION}
    ## to 'DEL' to make that happen. Still needs more real world usage
    ## before deciding proper behaviour.
    ##
    ## It would probably work fine. But I don't know yet when to apply
    ## the 'DEL'. Should we keep doing all slave apply()'s and only
    ## then return the 'DEL'? And what about relations where we are the
    ## master? should we do the apply on all those relations and leave
    ## the 'DEL' on self to the very last? Or even: collect all
    ## deletes and do them in a single batch at the very end? Not sure.

    _merge_rev_cond_fields(\%frg_keys, $info, $data) if $data;

    ### DIRTY HACK: no public API to clear this caches
    delete $row->{_relationship_data}{$name} if $row;
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

      ### DIRTY HACK: no public API to clear this caches
      ## TODO: Alternative: if $info->{attr}{accessor} == single, fetch
      ## row using the acessor and pass it to apply as third argument -
      ## probably better anyway
      delete $row->{_relationship_data}{$name};
    }
  }
}


=function apply_fake_master_role_relations
=cut

sub apply_fake_master_role_relations {
  my ($source, $rels, $row) = @_;
  my %frg_keys;

  for (@$rels) {
    my ($name, $data, $info, $rev_info) = @$_;
    my $rel_source = $source->related_source($name);

    if (!blessed($data)) {
      my $action = $data->{__ACTION} ||= 'ADD';

      my %rel_fields = %$data;
      _merge_cond_fields(\%rel_fields, $rev_info, $row);

      $data = apply($rel_source, \%rel_fields);
    }
    else {
      ## FIXME: is this case possible?
    }

    _merge_rev_cond_fields(\%frg_keys, $info, $data) if $data;

    ### DIRTY HACK: no public API to clear this caches
    delete $row->{_relationship_data}{$name} if $row;
  }

  return \%frg_keys;
}


=private _merge_cond_fields
=cut

sub _merge_cond_fields {
  my ($dest, $info, $src) = @_;

  my $fields = _collect_cond_fields($info);
  return _copy_cond_fields($dest, $fields, $src);
}


=private _merge_rev_cond_fields
=cut

sub _merge_rev_cond_fields {
  my ($dest, $info, $src) = @_;

  my $fields = _collect_cond_fields($info);
  return _copy_cond_fields($dest, {reverse %$fields}, $src);
}


=private _copy_cond_fields
=cut

sub _copy_cond_fields {
  my ($dest, $fields, $src) = @_;
  my $src_is_row = blessed($src);

  for my $src_f (keys %$fields) {
    my $v;
    if ($src_is_row) {
      my $sn = $src->result_source->source_name;
      ## FIXME: think of a better error message
      ## (and no, the one from _resolve_condition is not it)
      $src->discard_changes unless $src->has_column_loaded($src_f);

# confess(
#   "Something went horribly wrong, please send me a test case :): field '$src_f' for source '$sn', "
# ) unless $src->has_column_loaded($src_f);

      $v = $src->get_column($src_f);
    }
    else {
      next unless exists $src->{$src_f};
      $v = $src->{$src_f};
    }

    ## TODO: what if $dest is a Row object already?
    $dest->{$fields->{$src_f}} = $v if defined $v;
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
  my %splited = (fields => {}, action => 'ADD');

  for my $f (keys %$data) {
    my $v = $data->{$f};

    if ($f eq '__ID') {
      $v = [$v] unless ref($v);
      my @pks = $source->primary_columns;
      if (scalar(@pks) != scalar(@$v)) {
        confess('Field __ID has '
            . scalar(@$v)
            . ' elements but PK for source '
            . $source->source_name
            . ' needs '
            . scalar(@pks)
            . ', ');
      }
      my $flds = $splited{fields} ||= {};
      @$flds{@pks} = @$v;
      next;
    }

    if ($f eq '__ACTION') {
      $splited{action} = $v || 'ADD';
      next;
    }

    if ($source->has_column($f)) {
      $splited{fields}{$f} = $v;
      next;
    }

    my $info = relationship_info($source, $f);
    croak("Name '$f' not a field or relationship of '"
        . $source->source_name . "'")
      unless $info;

    my $role = $info->{our_role};
    $v = [$v] unless $role eq 'slave' or ref($v) eq 'ARRAY';

    ## Convert many_to_many into a has_many
    my $rev_info;
    if ($role eq 'via') {
      my $r = $info->{link_frg_name};

      for my $i (@$v) {
        my $action = delete $i->{__ACTION};
        $i = {$r => $i};
        $i->{__ACTION} = $action if $action;
      }

      $role = 'master';
      $f    = $info->{link_name};
      $info = relationship_info($source, $f);
    }
    elsif (exists $info->{attrs}{master_rel}) {
      $role = 'fake_master';
      $rev_info = relationship_info($source, $info->{attrs}{master_rel});
    }

    push @{$splited{$role}}, [$f, $v, $info, $rev_info];
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
