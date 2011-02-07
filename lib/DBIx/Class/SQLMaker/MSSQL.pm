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
     year         => 'year',
     quarter      => 'quarter',
     month        => 'month',
     day_of_year  => 'dayofyear',
     day_of_month => 'day',
     week         => 'week',
     day_of_week  => 'weekday',
     hour         => 'hour',
     minute       => 'minute',
     second       => 'second',
     millisecond  => 'millisecond',
  );

  my %diff_part_map = %part_map;
  $diff_part_map{day} = delete $diff_part_map{day_of_year};
  delete $diff_part_map{day_of_month};
  delete $diff_part_map{day_of_week};

  sub _datetime_sql {
    die $_[0]->_unsupported_date_extraction($_[1], 'Microsoft SQL Server')
       unless exists $part_map{$_[1]};
    "DATEPART('$part_map{$_[1]}', $_[2])"
  }
  sub _datetime_diff_sql {
    die $_[0]->_unsupported_date_diff($_[1], 'Microsoft SQL Server')
       unless exists $diff_part_map{$_[1]};
    "DATEDIFF('$diff_part_map{$_[1]}', $_[2], $_[3])"
  }
}

=head1 DATE FUNCTION IMPLEMENTATION

The function used to extract date information is C<DATEPART>, which supports

 year
 quarter
 month
 day_of_year
 day_of_month
 week
 day_of_week
 hour
 minute
 second
 millisecond

The function used to diff dates is C<DATEDIFF>, which supports

 year
 quarter
 month
 day
 week
 hour
 minute
 second
 millisecond

=cut

1;
