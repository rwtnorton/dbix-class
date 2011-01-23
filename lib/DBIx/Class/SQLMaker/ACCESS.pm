package # Hide from PAUSE
  DBIx::Class::SQLMaker::ACCESS;

use strict;
use warnings;
use base 'DBIx::Class::SQLMaker';
use Carp::Clan qw/^DBIx::Class|^SQL::Abstract/;
use namespace::clean;

sub _parenthesize_joins { 1 }

1;
