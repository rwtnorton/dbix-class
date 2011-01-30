use strict;
use warnings;

use Test::More;

use lib qw(t/lib);
use DBIC::SqlMakerTest;
use DateTime;

use_ok('DBICTest');

my $schema = DBICTest->init_schema();

my $sql_maker = $schema->storage->sql_maker;

my $date = DateTime->new(
   year => 2010,
   month => 12,
   day   => 14,
   hour  => 12,
   minute => 12,
   second => 12,
);

my $date2 = $date->clone->set_day(16);

is_same_sql_bind (
  \[ $sql_maker->select ('artist', '*', { 'artist.when_began' => { -dt => $date } } ) ],
  "SELECT *
    FROM artist
    WHERE artist.when_began = ?
  ",
  [['artist.when_began', '2010-12-14 12:12:12']],
);

is_same_sql_bind (
  \[ $sql_maker->update ('artist',
    { 'artist.when_began' => { -dt => $date } },
    { 'artist.when_ended' => { '<' => { -dt => $date2 } } },
  ) ],
  "UPDATE artist
    SET artist.when_began = ?
    WHERE artist.when_ended < ?
  ",
  [
   ['artist.when_began', '2010-12-14 12:12:12'],
   ['artist.when_ended', '2010-12-16 12:12:12'],
  ],
);

done_testing;
