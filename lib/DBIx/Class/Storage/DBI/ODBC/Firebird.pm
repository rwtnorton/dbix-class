package DBIx::Class::Storage::DBI::ODBC::Firebird;

use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::InterBase';
use mro 'c3';
use DBD::ODBC 1.29;
use Try::Tiny;
use namespace::clean;

=head1 NAME

DBIx::Class::Storage::DBI::ODBC::Firebird - Driver for using the Firebird RDBMS
through ODBC

=head1 DESCRIPTION

Most functionality is provided by L<DBIx::Class::Storage::DBI::Interbase>, see
that module for details.

To build the ODBC driver for Firebird on Linux for unixODBC, see:

L<http://www.firebirdnews.org/?p=1324>

This driver does not suffer from the nested statement handles across commits
issue that the L<DBD::InterBase|DBIx::Class::Storage::DBI::InterBase> based
driver does. This makes it more suitable for long running processes such as
under L<Catalyst>.

=cut

__PACKAGE__->datetime_parser_type ('DBIx::Class::Storage::DBI::ODBC::Firebird::DateTime::Format');

# XXX seemingly no equivalent to ib_time_all from DBD::InterBase via ODBC
sub connect_call_datetime_setup { 1 }

# we don't need DBD::InterBase-specific initialization
sub _init { 1 }

# ODBC uses dialect 3 by default, good
sub _set_sql_dialect { 1 }

# releasing savepoints doesn't work for some reason, but that shouldn't matter
sub _svp_release { 1 }

sub _svp_rollback {
  my ($self, $name) = @_;

  try {
    $self->_dbh->do("ROLLBACK TO SAVEPOINT $name")
  }
  catch {
    # Firebird ODBC driver bug, ignore
    if (not /Unable to fetch information about the error/) {
      die $_;
    }
  };
}

# AutoCommit status does not get reset properly, possibly because of the
# SQLRowCount bug in the Firebird ODBC driver.

sub _dbh_commit {
  my $self = shift;
  $self->next::method(@_);
  $self->_dbh->{AutoCommit} = $self->_dbh_autocommit;
}

sub _dbh_rollback {
  my $self = shift;
  $self->next::method(@_);
  $self->_dbh->{AutoCommit} = $self->_dbh_autocommit;
}

package # hide from PAUSE
  DBIx::Class::Storage::DBI::ODBC::Firebird::DateTime::Format;

# inherit parse/format date
our @ISA = 'DBIx::Class::Storage::DBI::InterBase::DateTime::Format';

my $timestamp_format = '%Y-%m-%d %H:%M:%S'; # %F %T, no fractional part
my $timestamp_parser;

sub parse_datetime {
  shift;
  require DateTime::Format::Strptime;
  $timestamp_parser ||= DateTime::Format::Strptime->new(
    pattern  => $timestamp_format,
    on_error => 'croak',
  );
  return $timestamp_parser->parse_datetime(shift);
}

sub format_datetime {
  shift;
  require DateTime::Format::Strptime;
  $timestamp_parser ||= DateTime::Format::Strptime->new(
    pattern  => $timestamp_format,
    on_error => 'croak',
  );
  return $timestamp_parser->format_datetime(shift);
}

1;

=head1 CAVEATS

=over 4

=item *

This driver (unlike L<DBD::InterBase>) does not currently support reading or
writing C<TIMESTAMP> values with sub-second precision.

=back

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sts=2 sw=2:
