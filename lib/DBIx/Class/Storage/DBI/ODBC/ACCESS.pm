package DBIx::Class::Storage::DBI::ODBC::ACCESS;

use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::UniqueIdentifier';
use mro 'c3';
use List::Util 'first';
use namespace::clean;

__PACKAGE__->mk_group_accessors(inherited =>
  'disable_sth_caching_for_image_insert_or_update'
);

__PACKAGE__->sql_limit_dialect ('Top');
__PACKAGE__->sql_quote_char ([qw/[ ]/]);

__PACKAGE__->new_guid(undef);

__PACKAGE__->disable_sth_caching_for_image_insert_or_update(1);

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

=head1 TEXT/IMAGE/MEMO COLUMNS

Avoid using C<TEXT> columns as they will be truncated to 255 bytes. Some other
drivers (like L<ADO|DBIx::Class::Storage::DBI::ADO::MS_Jet>) will automatically
convert C<TEXT> columns to C<MEMO>, but the ODBC driver does not.

C<IMAGE> columns work correctly, but the statements for inserting or updating an
C<IMAGE> column will not be L<cached|DBI/prepare_cached>, due to a bug in the
Access ODBC driver.

C<MEMO> columns work correctly as well, but you must take care to set
L<LongReadLen|DBI/LongReadLen> to C<$max_memo_size * 2 + 1>. This is done for
you automatically if you pass L<LongReadLen|DBI/LongReadLen> in your
L<connect_info|DBIx::Class::Storage::DBI/connect_info>; but if you set this
attribute directly on the C<$dbh>, keep this limitation in mind.

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

# set LongReadLen = LongReadLen * 2 + 1 (see docs on MEMO)
sub _run_connection_actions {
  my $self = shift;

  my $long_read_len = $self->_dbh->{LongReadLen};

# The last one is the ADO default.
  if ($long_read_len != 0 && $long_read_len != 80 && $long_read_len != 2147483647) {
    $self->_dbh->{LongReadLen} = $long_read_len * 2 + 1;
  }

  return $self->next::method(@_);
}

# support empty insert
sub insert {
  my $self = shift;
  my ($source, $to_insert) = @_;

  my $columns_info = $source->columns_info;

  if (keys %$to_insert == 0) {
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

  my $is_image_insert = 0;

  for my $col (keys %$to_insert) {
    $is_image_insert = 1
      if $self->_is_binary_lob_type($columns_info->{$col}{data_type});
  }

  local $self->{disable_sth_caching} = 1 if $is_image_insert
    && $self->disable_sth_caching_for_image_insert_or_update;

  return $self->next::method(@_);
}

sub update {
  my $self = shift;
  my ($source, $fields) = @_;

  my $columns_info = $source->columns_info;

  my $is_image_insert = 0;

  for my $col (keys %$fields) {
    $is_image_insert = 1
      if $self->_is_binary_lob_type($columns_info->{$col}{data_type});
  }

  local $self->{disable_sth_caching} = 1 if $is_image_insert
    && $self->disable_sth_caching_for_image_insert_or_update;

  return $self->next::method(@_);
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
