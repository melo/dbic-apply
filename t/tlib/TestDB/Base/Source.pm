package TestDB::Base::Source;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->load_components('+DBICx::Apply');

1;