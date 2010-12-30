package DBICx::Apply::Core;

# ABSTRACT: a very cool module

use strict;
use warnings;
use Scalar::Util 'blessed';


=private __apply_find_unique_cond

Given a ResultSource and a hashref with fields, searches all the unique
constraints for one that could be used to find a unique row.

If the primary key is one of them, prefer it.

In scalar context, returns a hashref with the fields/values that should
be used. In list context, returns the same hashref as the first
parameter, and the name of the unique constraint found as the second.

=cut

sub __apply_find_unique_cond {
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
  return (\%cond, $found) if wantarray;
  return \%cond;
}


=private __apply_find_one_row

Given a ResultSource and a hashref with fields, returns a single Row if
a unique row could be found based on the fields present.

Returns undef if no row was found or if the fields provided are
insuficient to satisfy any of the unique constraints defined on
the source.

=cut

sub __apply_find_one_row {
  my ($source) = @_;

  my ($cond, $key) = __apply_find_unique_cond(@_);
  return unless $cond;

  return $source->resultset->find($cond, {key => $key});
}


##########################################
# Extended relationship meta-data registry

my %__apply_rel_registry;

sub __apply_relationships {
  my ($source) = @_;
  $source = $source->result_class if blessed($source);

  return keys %{$__apply_rel_registry{$source} || {}};
}

sub __apply_relationship_info {
  my ($source, $name) = @_;
  $source = $source->result_class if blessed($source);

  return unless exists $__apply_rel_registry{$source}{$name};

  my $meta = $__apply_rel_registry{$source}{$name};
  __apply_relationship_info_recalc($source, $name, $meta)
    if exists $meta->{__need_recalc};

  return $meta;
}

sub __apply_relationship_info_recalc {
  my ($source, $name, $meta) = @_;

  my $dbic_meta = $source->relationship_info($name);
  $dbic_meta = {} unless $dbic_meta;    ## many-to-many are not rels

  ## Add some info to m2m rels
  $meta->{link_info} = __apply_relationship_info($source, $meta->{link_name})
    if exists $meta->{link_name};

  %$meta = (%$meta, %$dbic_meta);
  delete $meta->{__need_recalc};

  return;
}

sub __apply_set_relationship_info {
  my ($source, $name, $info) = @_;
  $source = $source->result_class if blessed($source);

  $info->{name} = $name;
  $info->{__need_recalc}++;

  $__apply_rel_registry{$source}{$name} = $info;
}



1;
