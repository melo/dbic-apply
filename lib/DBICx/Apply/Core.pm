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

  $row = find_one_row($source, $fields) unless $row;
  if ($row) {
    $row->update($fields);
  }
  else {
    $row = $source->resultset->create($fields);
  }

  return $row;
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
  $info->{__need_recalc}++;

  $rel_registry{$source}{$name} = $info;
}


1;
