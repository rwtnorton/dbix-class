use strict;
use warnings;

use Test::More;
use lib qw(t/lib);
use DBICTest;

my $schema = DBICTest->init_schema(cursor_class => 'DBIx::Class::Cursor::Cached');

my @art = $schema->resultset("Artist")->search();
is(@art, 3, "Three artists returned");

done_testing;
