use strict;
use warnings;  

use Test::More;
use Test::Exception;
use Scope::Guard ();
use lib qw(t/lib);
use DBICTest;

my ($dsn, $user, $pass)    = @ENV{map { "DBICTEST_SQLANYWHERE_${_}" }      qw/DSN USER PASS/};
my ($dsn2, $user2, $pass2) = @ENV{map { "DBICTEST_SQLANYWHERE_ODBC_${_}" } qw/DSN USER PASS/};

if (not ($dsn || $dsn2)) {
  plan skip_all => <<'EOF';
Set $ENV{DBICTEST_SQLANYWHERE_DSN} and/or $ENV{DBICTEST_SQLANYWHERE_ODBC_DSN}
_USER and _PASS to run this test'.
Warning: This test drops and creates a table called 'track'";
EOF
}

plan skip_all => 'Test needs ' . DBIx::Class::Optional::Dependencies->req_missing_for ('test_dt')
  unless DBIx::Class::Optional::Dependencies->req_ok_for ('test_dt');

my @info = (
  [ $dsn,  $user,  $pass  ],
  [ $dsn2, $user2, $pass2 ],
);

my $schema;

foreach my $info (@info) {
  my ($dsn, $user, $pass) = @$info;

  next unless $dsn;

  $schema = DBICTest::Schema->clone;

  $schema->connection($dsn, $user, $pass, {
    on_connect_call => [ 'datetime_setup' ],
  });

  my $sg = Scope::Guard->new(\&cleanup); 

# coltype, col, date
  my @dt_types = (
    ['TIMESTAMP', 'last_updated_at', '2004-08-21 14:36:48.080445'],
# date only (but minute precision according to ASA docs)
    ['DATE', 'small_dt', '2004-08-21 00:00:00.000000'],
  );

  for my $dt_type (@dt_types) {
    my ($type, $col, $sample_dt) = @$dt_type;

    eval { $schema->storage->dbh->do("DROP TABLE track") };
    $schema->storage->dbh->do(<<"SQL");
    CREATE TABLE track (
      trackid INT IDENTITY PRIMARY KEY,
      cd INT,
      position INT,
      $col $type,
    )
SQL
    ok(my $dt = $schema->storage->datetime_parser->parse_datetime($sample_dt));

    my $row;
    ok( $row = $schema->resultset('Track')->create({
          $col => $dt,
          cd => 1,
        }));
    ok( $row = $schema->resultset('Track')
      ->search({ trackid => $row->trackid }, { select => [$col] })
      ->first
    );
    is( $row->$col, $dt, "$type roundtrip" );

    is $row->$col->nanosecond, $dt->nanosecond,
        'nanoseconds survived' if 0+$dt->nanosecond;
  }
}

done_testing;

# clean up our mess
sub cleanup {
  if (my $dbh = $schema->storage->dbh) {
    eval { $dbh->do("DROP TABLE $_") } for qw/track/;
  }
}
