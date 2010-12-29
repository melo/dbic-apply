package DBICx::Apply;

# ABSTRACT: a very cool module

use strict;
use warnings;


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

1;
