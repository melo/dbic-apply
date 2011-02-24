#!perl

use strict;
use warnings;
use DBICx::Apply::Tests;
use Test::Fatal;
use DBICx::Apply::Core;


my $db = TestDB->test_db();

cmp_deeply(
  DBICx::Apply::Core::parse_data($db->source('Users'), {__ID => 42}),
  {fields => {user_id => 42}, action => 'ADD'},
  '__ID special field (single PK), ok'
);

cmp_deeply(
  DBICx::Apply::Core::parse_data($db->source('UsersTags'), {__ID => [42, 9]}),
  {fields => {user_id => 42, tag_id => 9}, action => 'ADD'},
  '__ID special field (multiple PKs), ok'
);

like(
  exception {
    DBICx::Apply::Core::parse_data($db->source('UsersTags'), {__ID => 42});
  },
  qr/Field __ID has \d+ elements but PK for source UsersTags needs \d+, /,
  '__ID parsing catches bad number of value for PK'
);

cmp_deeply(
  DBICx::Apply::Core::parse_data(
    $db->source('Users'),
    { name          => 'my name',
      login         => 'my login',
      emails        => {email => 'me@world.domination.org'},
      tags_per_user => [{tag => {tag => 'love'}}],
      tags          => [{tag => 'nice'}, {tag => 'word', __ACTION => 'IGN'}],
      active_email => {email => 'his@world.domination.org'},
    }
  ),
  { action => 'ADD',
    fields => {
      name  => 'my name',
      login => 'my login',
    },
    master => bag(
      ['emails', [{email => 'me@world.domination.org'}], ignore(), undef],
      [ 'tags_per_user',
        [ {tag => {tag => 'nice'}},
          {__ACTION => 'IGN', tag => {tag => 'word'}}
        ],
        superhashof({source => 'TestDB::Result::UsersTags'}),
        undef,
      ],
      [ 'tags_per_user',
        [{tag => {tag => 'love'}}],
        superhashof({source => 'TestDB::Result::UsersTags'}), undef,
      ],
    ),
    fake_master => [
      [ 'active_email',
        {email => 'his@world.domination.org'},
        superhashof(
          { source => 'TestDB::Result::Emails',
            attrs  => superhashof({master_rel => 'emails'}),
          }
        ),
        superhashof({source => 'TestDB::Result::Emails',}),
      ],
    ],
  },
  'Parsed sample data for Users ok'
);

cmp_deeply(
  DBICx::Apply::Core::parse_data(
    $db->source('Emails'),
    { email    => 'mini_me@here',
      user     => {login => 'xpto'},
      __ACTION => 'DEL'
    }
  ),
  { fields => {email => 'mini_me@here'},
    slave  => [['user', {login => 'xpto'}, ignore(), undef]],
    action => 'DEL',
  },
  'Parsed sample data for Emails ok'
);

cmp_deeply(
  DBICx::Apply::Core::parse_data($db->source('Emails'), {}),
  {fields => {}, action => 'ADD'},
  'Parsed empty set of fields, ok'
);

like(
  exception {
    DBICx::Apply::Core::parse_data($db->source('Emails'), {no => 'field'});
  },
  qr/Name 'no' not a field or relationship of 'Emails'/,
  'Expected exception with unkown field/relationship'
);

done_testing();
