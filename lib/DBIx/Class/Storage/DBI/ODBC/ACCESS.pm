package DBIx::Class::Storage::DBI::ODBC::ACCESS;

use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::UniqueIdentifier';
use mro 'c3';
use List::Util 'first';
use namespace::clean;

__PACKAGE__->sql_limit_dialect ('Top');
__PACKAGE__->sql_quote_char ([qw/[ ]/]);

__PACKAGE__->new_guid(undef);

=head1 NAME

DBIx::Class::Storage::DBI::ODBC::ACCESS - Support specific to MS Access over ODBC

=head1 DESCRIPTION

This class implements support specific to Microsoft Access over ODBC.

It is loaded automatically by by DBIx::Class::Storage::DBI::ODBC when it
detects a MS Access back-end.

This driver supports L<last_insert_id|DBIx::Class::Storage::DBI/last_insert_id>,
empty inserts for tables with C<AUTOINCREMENT> columns, nested transactions via
L<auto_savepoint|DBIx::Class::Storage::DBI/auto_savepoint>, C<GUID> columns via
L<DBIx::Class::Storage::DBI::UniqueIdentifier> and
L<DBIx::Class::InflateColumn::DateTime> for C<DATETIME> columns.

=head1 EXAMPLE DSN

  dbi:ODBC:driver={Microsoft Access Driver (*.mdb, *.accdb)};dbq=C:\Users\rkitover\Documents\access_sample.accdb

=head1 SUPPORTED VERSIONS

This module has currently only been tested on MS Access 2010 using the Jet 4.0
engine.

Information about how well it works on different version of MS Access is welcome
(write the mailing list, or submit a ticket to RT if you find bugs.)

=head1 USING GUID COLUMNS

If you have C<GUID> PKs or other C<GUID> columns with
L<auto_nextval|DBIx::Class::ResultSource/auto_nextval> you will need to set a
L<new_guid|DBIx::Class::Storage::DBI::UniqueIdentifier/new_guid> callback, like
so:

  $schema->storage->new_guid(sub { Data::GUID->new->as_string });

Under L<Catalyst> you can use code similar to this in your
L<Catalyst::Model::DBIC::Schema> C<Model.pm>:

  after BUILD => sub {
    my $self = shift;
    $self->storage->new_guid(sub { Data::GUID->new->as_string });
  };

=cut

sub _dbh_last_insert_id { $_[1]->selectrow_array('select @@identity') }

sub sqlt_type { 'ACCESS' }

# support empty insert
sub insert {
    my $self = shift;
    my ($source, $to_insert) = @_;

    if (keys %$to_insert == 0) {
        my $columns_info = $source->columns_info;
        my $autoinc_col = first {
          $columns_info->{$_}{is_auto_increment}
        } keys %$columns_info;

        if (not $autoinc_col) {
          $self->throw_exception(
'empty insert only supported for tables with an autoincrement column'
          );
        }

        my $table = $source->from;
        $table = $$table if ref $table;

        $to_insert->{$autoinc_col} = \"dmax('${autoinc_col}', '${table}')+1";
    }

    $self->next::method(@_);
}

sub bind_attribute_by_data_type {
  my $self = shift;
  my ($data_type) = @_;

  my $attributes = $self->next::method(@_) || {};

  if ($self->_is_text_lob_type($data_type)) {
    $attributes->{TYPE} = DBI::SQL_LONGVARCHAR;
  }
  elsif ($self->_is_binary_lob_type($data_type)) {
    $attributes->{TYPE} = DBI::SQL_LONGVARBINARY;
  }

  return $attributes;
}

# savepoints are not supported, but nested transactions are.
# Unfortunately DBI does not support nested transactions.
# WARNING: this code uses the undocumented 'BegunWork' DBI attribute.

sub _svp_begin {
  my ($self, $name) = @_;
  local $self->_dbh->{AutoCommit} = 1;
  local $self->_dbh->{BegunWork}  = 0;
  $self->_dbh_begin_work;
}

# A new nested transaction on the same level releases the previous one.
sub _svp_release { 1 }

sub _svp_rollback {
  my ($self, $name) = @_;
  local $self->_dbh->{AutoCommit} = 0;
  local $self->_dbh->{BegunWork}  = 1;
  $self->_dbh_rollback;
}

sub datetime_parser_type {
  'DBIx::Class::Storage::DBI::ODBC::ACCESS::DateTime::Format'
}

package # hide from PAUSE
  DBIx::Class::Storage::DBI::ODBC::ACCESS::DateTime::Format;

my $datetime_format = '%Y-%m-%d %H:%M:%S'; # %F %T, no fractional part
my $datetime_parser;

sub parse_datetime {
  shift;
  require DateTime::Format::Strptime;
  $datetime_parser ||= DateTime::Format::Strptime->new(
    pattern  => $datetime_format,
    on_error => 'croak',
  );
  return $datetime_parser->parse_datetime(shift);
}

sub format_datetime {
  shift;
  require DateTime::Format::Strptime;
  $datetime_parser ||= DateTime::Format::Strptime->new(
    pattern  => $datetime_format,
    on_error => 'croak',
  );
  return $datetime_parser->format_datetime(shift);
}

1;

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sts=2 sw=2:
