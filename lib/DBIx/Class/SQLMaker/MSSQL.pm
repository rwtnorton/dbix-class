package # Hide from PAUSE
  DBIx::Class::SQLMaker::MSSQL;

use base qw( DBIx::Class::SQLMaker );
use Carp::Clan qw/^DBIx::Class|^SQL::Abstract/;

#
# MSSQL does not support ... OVER() ... RNO limits
#
sub _rno_default_order {
  return \ '(SELECT(1))';
}

{
  my %part_map = (
     month        => 'mm',
     day_of_month => 'dd',
     year         => 'yyyy',
  );

  sub _datetime_sql { "DATEPART('$part_map{$_[1]}', $_[2])" }
}


1;
