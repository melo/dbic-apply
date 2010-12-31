#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply::Core;


my $db = TestDB->test_db();

cmp_deeply(
  DBICx::Apply::Core::parse_data(
    $db->source('Users'),
    { name   => 'my name',
      login  => 'my login',
      emails => {email => 'me@world.domination.org'},
      tags   => [{tag => 'nice'}, {tag => 'word'}],
    }
  ),
  { fields => {
      name  => 'my name',
      login => 'my login',
    },
    master => [
      ['emails', [{email => 'me@world.domination.org'}], ignore()],
      [ 'tags_per_user', [{tag => {tag => 'nice'}}, {tag => {tag => 'word'}}],
        ignore()
      ]
    ],
  },
  'Parsed sample data for Users ok'
);

cmp_deeply(
  DBICx::Apply::Core::parse_data(
    $db->source('Emails'),
    { email => 'mini_me@here',
      user  => {login => 'xpto'},
    }
  ),
  { fields => {email => 'mini_me@here'},
    slave => [['user', {login => 'xpto'}, ignore()]],
  },
  'Parsed sample data for Emails ok'
);

done_testing();
