package TestDB::Result::Emails;

use strict;
use warnings;
use parent 'TestDB::Base::Source';
use DateTime;

__PACKAGE__->table('emails');

__PACKAGE__->add_columns(
  'email_id' => {
    data_type         => 'integer',
    is_nullable       => 0,
    is_auto_increment => 1,
  },

  'user_id' => {
    data_type   => 'integer',
    is_nullable => 0,
  },

  'email' => {
    data_type => 'varchar',
    size      => 100,
  },
);

__PACKAGE__->set_primary_key('email_id');
__PACKAGE__->add_unique_constraint(email_per_user_un => ['email', 'user_id']);

__PACKAGE__->might_have(
  active_for => 'TestDB::Result::Users',
  { 'foreign.active_email_id' => 'self.email_id',
    'foreign.user_id'         => 'self.user_id'
  },
  {cascade_delete => 0},
);

__PACKAGE__->belongs_to(
  user => 'TestDB::Result::Users',
  {'foreign.user_id' => 'self.user_id'}
);


sub _dbicx_apply_filter {
  my ($class, $source, $f, $row) = @_;

  $f->{email} = lc($f->{email})
    if exists($f->{email}) && defined($f->{email});

  return $f;
}


1;
