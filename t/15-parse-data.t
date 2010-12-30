#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use DBICx::Apply::Core;


my $db = TestDB->test_db();

cmp_deeply(
  [ DBICx::Apply::Core::parse_data(
      $db->source('Users'),
      { name   => 'my name',
        login  => 'my login',
        emails => {email => 'me@world.domination.org'},
        tags   => [{tag => 'nice'}, {tag => 'word'}],
      }
    )
  ],
  [ { name  => 'my name',
      login => 'my login',
    },
    [],
    [['emails', [{email => 'me@world.domination.org'}], ignore()]],
    [['tags', [{tag => 'nice'}, {tag => 'word'}], ignore()]],
  ],
  'Parsed sample data for Users ok'
);

cmp_deeply(
  [ DBICx::Apply::Core::parse_data(
      $db->source('Emails'),
      { email => 'mini_me@here',
        user  => {login => 'xpto'},
      }
    )
  ],
  [ {email => 'mini_me@here'},
    [['user', {login => 'xpto'}, ignore()]],
    [],
    [],
  ],
  'Parsed sample data for Emails ok'
);

done_testing();
