package # Hide from PAUSE
  DBIx::Class::SQLMaker::SQLite;

use base qw( DBIx::Class::SQLMaker );
use Carp::Clan qw/^DBIx::Class|^SQL::Abstract/;

#
# SQLite does not understand SELECT ... FOR UPDATE
# Disable it here
sub _lock_select () { '' };


{
  my %part_map = (
     month        => 'm',
     day_of_month => 'd',
     year         => 'Y',
  );

  sub _datetime_sql { "STRFTIME('$part_map{$_[1]}', $_[2])" }
}

sub _datetime_diff_sql {
   my ($self, $part, $left, $right) = @_;
   '(' .
      $self->_datetime_sql($part, $left)
       . ' - ' .
      $self->_datetime_sql($part, $right)
   . ')'
}

1;
