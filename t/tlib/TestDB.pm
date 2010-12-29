package TestDB;

use strict;
use warnings;
use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces();

sub test_db {
  my $file = $ENV{DBIC_TESTS_DB_PATH} || ':memory:';
  my $need_deploy = ! -e $file;

  my $db = shift->connect("dbi:SQLite:$file");
  $db->deploy({}) if $need_deploy;

  return $db;
}

1;
