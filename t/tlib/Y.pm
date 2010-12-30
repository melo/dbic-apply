package Y;

use strict;
use warnings;

sub new { return bless {}, shift }

sub relationship_info { return {b => 2} }
sub result_class {__PACKAGE__}

1;
